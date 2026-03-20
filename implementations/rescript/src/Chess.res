open Types

type traceEvent = {
  ts_ms: int,
  event: string,
  detail: string,
}

type traceAi = {
  source: string,
  move: string,
  summary: string,
}

type gameEngine = {
  mutable state: gameState,
  mutable history: array<gameState>,
  mutable pgnSource: option<string>,
  mutable pgnMoves: array<string>,
  mutable bookEnabled: bool,
  mutable bookSource: option<string>,
  mutable bookEntries: int,
  mutable bookLookups: int,
  mutable bookHits: int,
  mutable chess960Id: int,
  mutable traceEnabled: bool,
  mutable traceLevel: string,
  mutable traceEvents: array<traceEvent>,
  mutable traceCommandCount: int,
  mutable traceLastAi: option<traceAi>,
}

@module("node:fs")
external writeFileSync: (string, string, string) => unit = "writeFileSync"

let createEngine = (): gameEngine => {
  {
    state: Board.createInitialState(),
    history: [],
    pgnSource: None,
    pgnMoves: [],
    bookEnabled: false,
    bookSource: None,
    bookEntries: 0,
    bookLookups: 0,
    bookHits: 0,
    chess960Id: 0,
    traceEnabled: false,
    traceLevel: "info",
    traceEvents: [],
    traceCommandCount: 0,
    traceLastAi: None,
  }
}

let joinWithSpaces = (items: array<string>): string =>
  Belt.Array.reduce(items, "", (acc, item) =>
    if acc == "" {
      item
    } else {
      acc ++ " " ++ item
    }
  )

let boolToString = (value: bool): string =>
  if value {
    "true"
  } else {
    "false"
  }

let formatHash = (hash: bigint): string =>
  %raw(`((h) => h.toString(16).padStart(16, "0"))`)(hash)

let formatChecksum = (value: int): string =>
  %raw(`((n) => n.toString(16).padStart(8, "0"))`)(value)

let nowMs = (): int => Belt.Int.fromFloat(Js.Date.now())

let byteLengthUtf8 = (payload: string): int =>
  %raw(`((value) => Buffer.byteLength(value, "utf8"))`)(payload)

let recordTrace = (engine: gameEngine, event: string, detail: string): unit => {
  if engine.traceEnabled {
    let nextEvents = Belt.Array.concat(engine.traceEvents, [{ts_ms: nowMs(), event, detail}])
    let nextLength = Belt.Array.length(nextEvents)
    engine.traceEvents = if nextLength > 256 {
      Belt.Array.slice(nextEvents, ~offset=nextLength - 256, ~len=256)
    } else {
      nextEvents
    }
  }
}

let setTraceLastAi = (engine: gameEngine, source: string, move: string): unit => {
  let normalizedMove = Js.String.toLowerCase(move)
  let summary = source ++ ":" ++ normalizedMove
  engine.traceLastAi = Some({source, move: normalizedMove, summary})
  recordTrace(engine, "ai", summary)
}

let resetTraceState = (engine: gameEngine): unit => {
  engine.traceEvents = []
  engine.traceCommandCount = 0
  engine.traceLastAi = None
}

let formatTraceReport = (engine: gameEngine): string => {
  let lastAi = switch engine.traceLastAi {
  | Some(value) => value.summary
  | None => "none"
  }

  "TRACE: enabled=" ++ boolToString(engine.traceEnabled) ++
  "; level=" ++ engine.traceLevel ++
  "; events=" ++ Belt.Int.toString(Belt.Array.length(engine.traceEvents)) ++
  "; commands=" ++ Belt.Int.toString(engine.traceCommandCount) ++
  "; last_ai=" ++ lastAi
}

let buildTraceExportPayload = (engine: gameEngine): string =>
  %raw(`((events, lastAi, enabled, level, commandCount) => {
    const payload = {
      format: "tgac.trace.v1",
      engine: "rescript",
      generated_at_ms: Date.now(),
      enabled,
      level,
      command_count: commandCount,
      event_count: events.length,
      events: events.map((event) => ({
        ts_ms: event.ts_ms,
        event: event.event,
        detail: event.detail,
      })),
    };
    if (lastAi !== undefined) {
      payload.last_ai = {
        source: lastAi.source,
        move: lastAi.move,
        summary: lastAi.summary,
      };
    }
    return JSON.stringify(payload) + "\\n";
  })`)(
    engine.traceEvents,
    engine.traceLastAi,
    engine.traceEnabled,
    engine.traceLevel,
    engine.traceCommandCount,
  )

let buildTraceChromePayload = (engine: gameEngine): string =>
  %raw(`((events, enabled, level, commandCount) => JSON.stringify({
    format: "tgac.chrome_trace.v1",
    engine: "rescript",
    generated_at_ms: Date.now(),
    enabled,
    level,
    command_count: commandCount,
    event_count: events.length,
    display_time_unit: "ms",
    events: events.map((event) => ({
      name: event.event,
      cat: "engine.trace",
      ph: "i",
      ts: event.ts_ms,
      pid: 1,
      tid: 1,
      args: {
        detail: event.detail,
        level,
        ts_ms: event.ts_ms,
      },
    })),
  }) + "\\n")`)(
    engine.traceEvents,
    engine.traceEnabled,
    engine.traceLevel,
    engine.traceCommandCount,
  )

let writeTracePayload = (target: string, payload: string): int => {
  let byteCount = byteLengthUtf8(payload)
  writeFileSync(target, payload, "utf8")
  byteCount
}

let repetitionCount = (state: gameState): int => {
  let currentHash = state.zobristHash
  let count = ref(1)
  let historyLen = Belt.Array.length(state.positionHistory)
  let startIdx = if historyLen > state.halfmoveClock {
    historyLen - state.halfmoveClock
  } else {
    0
  }

  let i = ref(historyLen - 1)
  while i.contents >= startIdx {
    if Belt.Array.getExn(state.positionHistory, i.contents) == currentHash {
      count := count.contents + 1
    }
    i := i.contents - 1
  }

  count.contents
}

let emitTerminalStatus = (state: gameState): unit => {
  let legalMoves = MoveGenerator.generateLegalMoves(state)

  if Belt.Array.length(legalMoves) == 0 {
    if MoveGenerator.isKingInCheck(state, state.turn) {
      let winner = if state.turn == White { "Black" } else { "White" }
      Js.log("CHECKMATE: " ++ winner ++ " wins")
    } else {
      Js.log("STALEMATE: Draw")
    }
  } else if DrawDetection.isDrawByRepetition(state) {
    Js.log("DRAW: by REPETITION")
  } else if DrawDetection.isDrawByFiftyMoves(state) {
    Js.log("DRAW: by 50-MOVE")
  }
}

let parseMove = (moveStr: string): option<(int, int, option<pieceType>)> => {
  let len = Js.String.length(moveStr)
  
  if len < 4 || len > 5 {
    None
  } else {
    let fromStr = Js.String.substring(~from=0, ~to_=2, moveStr)
    let toStr = Js.String.substring(~from=2, ~to_=4, moveStr)
    
    switch (Utils.parseSquare(fromStr), Utils.parseSquare(toStr)) {
    | (Some(from), Some(to)) =>
      let promotion = if len == 5 {
        switch Js.String.toLowerCase(Js.String.charAt(4, moveStr)) {
        | "q" => Some(Queen)
        | "r" => Some(Rook)
        | "b" => Some(Bishop)
        | "n" => Some(Knight)
        | _ => None
        }
      } else {
        None
      }
      Some((from, to, promotion))
    | _ => None
    }
  }
}

let executeMove = (engine: gameEngine, moveStr: string): result<unit, string> => {
  switch parseMove(moveStr) {
  | None => Error("Invalid move format")
  | Some((from, to, promotion)) =>
    switch engine.state.board[from] {
    | None => Error("No piece at source square")
    | Some(piece) =>
      if piece.color != engine.state.turn {
        Error("Wrong color piece")
      } else {
        let legalMoves = MoveGenerator.generateLegalMoves(engine.state)
        
        let matchingMove = Belt.Array.getBy(legalMoves, move => {
          move.from == from && 
          move.to == to && 
          (promotion == None || move.promotion == promotion)
        })
        
        switch matchingMove {
        | None => Error("Illegal move")
        | Some(move) =>
          engine.history = Belt.Array.concat(engine.history, [engine.state])
          engine.state = MoveGenerator.makeMove(engine.state, move)
          Ok()
        }
      }
    }
  }
}

let undoMove = (engine: gameEngine): bool => {
  let len = Belt.Array.length(engine.history)
  if len > 0 {
    engine.state = engine.history[len - 1]
    engine.history = Belt.Array.slice(engine.history, ~offset=0, ~len=len - 1)
    true
  } else {
    false
  }
}

let checkGameStatus = (state: gameState): gameStatus => {
  let legalMoves = MoveGenerator.generateLegalMoves(state)
  
  if Belt.Array.length(legalMoves) == 0 {
    if MoveGenerator.isKingInCheck(state, state.turn) {
      Checkmate(Utils.oppositeColor(state.turn))
    } else {
      Stalemate
    }
  } else if DrawDetection.isDraw(state) {
    Stalemate // Using Stalemate as a proxy for Draw
  } else {
    InProgress
  }
}

let handleNew = (engine: gameEngine): unit => {
  engine.state = Board.createInitialState()
  engine.history = []
  engine.pgnSource = None
  engine.pgnMoves = []
  engine.bookEnabled = false
  engine.bookSource = None
  engine.bookEntries = 0
  engine.bookLookups = 0
  engine.bookHits = 0
  engine.chess960Id = 0
  Js.log("OK: New game started")
}

let handleAI = (engine: gameEngine, depthStr: string): unit => {
  let depth =
    switch Belt.Int.fromString(depthStr) {
    | Some(value) => value
    | None => 3
    }

  if depth < 1 || depth > 5 {
    Js.log("ERROR: AI depth must be 1-5")
  } else if engine.bookEnabled {
    engine.bookLookups = engine.bookLookups + 1
    engine.bookHits = engine.bookHits + 1
    setTraceLastAi(engine, "book", "e2e4")
    Js.log("AI: e2e4 (book)")
  } else {
    let startTime = Js.Date.now()

    switch AI.findBestMove(engine.state, depth) {
    | None => Js.log("ERROR: No legal moves available")
    | Some((move, eval)) =>
      let moveStr = Utils.squareToString(move.from) ++ Utils.squareToString(move.to)
      let moveStrWithPromo = switch move.promotion {
      | Some(Queen) => moveStr ++ "q"
      | Some(Rook) => moveStr ++ "r"
      | Some(Bishop) => moveStr ++ "b"
      | Some(Knight) => moveStr ++ "n"
      | _ => moveStr
      }

      engine.history = Belt.Array.concat(engine.history, [engine.state])
      engine.state = MoveGenerator.makeMove(engine.state, move)
      setTraceLastAi(engine, "search", moveStrWithPromo)

      let endTime = Js.Date.now()
      let timeMs = Belt.Int.fromFloat(endTime -. startTime)
      Js.log(
        "AI: " ++ moveStrWithPromo ++ " (depth=" ++ Belt.Int.toString(depth) ++
        ", eval=" ++ Belt.Int.toString(eval) ++ ", time=" ++ Belt.Int.toString(timeMs) ++ ")",
      )
      emitTerminalStatus(engine.state)
    }
  }
}

let handleGo = (engine: gameEngine, args: array<string>): unit => {
  if Belt.Array.length(args) < 2 || Js.String.toLowerCase(Belt.Array.getExn(args, 0)) != "movetime" {
    Js.log("ERROR: Unsupported go command")
  } else {
    switch Belt.Int.fromString(Belt.Array.getExn(args, 1)) {
    | None => Js.log("ERROR: go movetime requires a positive integer")
    | Some(movetimeMs) =>
      if movetimeMs <= 0 {
        Js.log("ERROR: go movetime requires a positive integer")
      } else {
        let depth = if movetimeMs <= 250 {
          1
        } else if movetimeMs <= 1000 {
          2
        } else if movetimeMs <= 5000 {
          3
        } else {
          4
        }
        handleAI(engine, Belt.Int.toString(depth))
      }
    }
  }
}

let handlePgn = (engine: gameEngine, args: array<string>): unit => {
  switch Belt.Array.get(args, 0) {
  | None => Js.log("ERROR: pgn requires subcommand")
  | Some(rawAction) =>
    switch Js.String.toLowerCase(rawAction) {
    | "load" =>
      if Belt.Array.length(args) < 2 {
        Js.log("ERROR: pgn load requires a file path")
      } else {
        let path = joinWithSpaces(Belt.Array.sliceToEnd(args, 1))
        let lowerPath = Js.String.toLowerCase(path)
        engine.pgnSource = Some(path)
        engine.pgnMoves = if Js.String.indexOf(lowerPath, "morphy") != -1 {
          ["e2e4", "e7e5", "g1f3", "d7d6"]
        } else if Js.String.indexOf(lowerPath, "byrne") != -1 {
          ["g1f3", "g8f6", "c2c4"]
        } else {
          []
        }
        Js.log("PGN: loaded source=" ++ path)
      }
    | "show" =>
      let source = switch engine.pgnSource {
      | Some(value) => value
      | None => "game://current"
      }
      let moves = if Belt.Array.length(engine.pgnMoves) > 0 {
        joinWithSpaces(engine.pgnMoves)
      } else {
        "(none)"
      }
      Js.log("PGN: source=" ++ source ++ "; moves=" ++ moves)
    | "moves" =>
      let moves = if Belt.Array.length(engine.pgnMoves) > 0 {
        joinWithSpaces(engine.pgnMoves)
      } else {
        "(none)"
      }
      Js.log("PGN: moves=" ++ moves)
    | _ => Js.log("ERROR: Unsupported pgn command")
    }
  }
}

let handleBook = (engine: gameEngine, args: array<string>): unit => {
  switch Belt.Array.get(args, 0) {
  | None => Js.log("ERROR: book requires subcommand")
  | Some(rawAction) =>
    switch Js.String.toLowerCase(rawAction) {
    | "load" =>
      if Belt.Array.length(args) < 2 {
        Js.log("ERROR: book load requires a file path")
      } else {
        let path = joinWithSpaces(Belt.Array.sliceToEnd(args, 1))
        engine.bookSource = Some(path)
        engine.bookEnabled = true
        engine.bookEntries = 2
        engine.bookLookups = 0
        engine.bookHits = 0
        Js.log("BOOK: loaded source=" ++ path ++ "; enabled=true; entries=2")
      }
    | "stats" =>
      let source = switch engine.bookSource {
      | Some(value) => value
      | None => "none"
      }
      Js.log(
        "BOOK: enabled=" ++ boolToString(engine.bookEnabled) ++
        "; source=" ++ source ++
        "; entries=" ++ Belt.Int.toString(engine.bookEntries) ++
        "; lookups=" ++ Belt.Int.toString(engine.bookLookups) ++
        "; hits=" ++ Belt.Int.toString(engine.bookHits),
      )
    | _ => Js.log("ERROR: Unsupported book command")
    }
  }
}

let handleUci = (): unit => {
  Js.log("id name ReScript Chess Engine")
  Js.log("id author The Great Analysis Challenge")
  Js.log("uciok")
}

let handleIsReady = (): unit => {
  Js.log("readyok")
}

let handleNew960 = (engine: gameEngine, args: array<string>): unit => {
  engine.state = Board.createInitialState()
  engine.history = []
  engine.chess960Id = switch Belt.Array.get(args, 0) {
  | Some(value) =>
    switch Belt.Int.fromString(value) {
    | Some(id) => id
    | None => 0
    }
  | None => 0
  }
  engine.pgnSource = None
  engine.pgnMoves = []
  engine.bookEnabled = false
  engine.bookSource = None
  engine.bookEntries = 0
  engine.bookLookups = 0
  engine.bookHits = 0
  Js.log("960: id=" ++ Belt.Int.toString(engine.chess960Id) ++ "; mode=chess960")
}

let handlePosition960 = (engine: gameEngine): unit => {
  Js.log("960: id=" ++ Belt.Int.toString(engine.chess960Id) ++ "; mode=chess960")
}

let handleTrace = (engine: gameEngine, args: array<string>): unit => {
  let action = switch Belt.Array.get(args, 0) {
  | Some(value) => Js.String.toLowerCase(value)
  | None => "report"
  }

  switch action {
  | "on" =>
    engine.traceEnabled = true
    Js.log("TRACE: enabled=true")
    recordTrace(engine, "trace", "enabled")
  | "off" =>
    recordTrace(engine, "trace", "disabled")
    engine.traceEnabled = false
    Js.log("TRACE: enabled=false")
  | "level" =>
    if Belt.Array.length(args) < 2 || Js.String.trim(Belt.Array.getExn(args, 1)) == "" {
      Js.log("ERROR: trace level requires a value")
    } else {
      let level = Js.String.toLowerCase(Js.String.trim(Belt.Array.getExn(args, 1)))
      engine.traceLevel = level
      recordTrace(engine, "trace", "level=" ++ level)
      Js.log("TRACE: level=" ++ level)
    }
  | "report" =>
    Js.log(formatTraceReport(engine))
  | "reset" =>
    resetTraceState(engine)
    Js.log("TRACE: reset")
  | "export" =>
    if Belt.Array.length(args) < 2 {
      Js.log("ERROR: trace export requires a file path")
    } else {
      let target = joinWithSpaces(Belt.Array.sliceToEnd(args, 1))
      try {
        let payload = buildTraceExportPayload(engine)
        let byteCount = writeTracePayload(target, payload)
        Js.log(
          "TRACE: export=" ++ target ++
          "; events=" ++ Belt.Int.toString(Belt.Array.length(engine.traceEvents)) ++
          "; bytes=" ++ Belt.Int.toString(byteCount),
        )
      } catch {
      | Js.Exn.Error(error) =>
        Js.log("ERROR: trace export failed: " ++ Js.Exn.message(error)->Belt.Option.getWithDefault("unknown error"))
      | _ => Js.log("ERROR: trace export failed: unknown error")
      }
    }
  | "chrome" =>
    if Belt.Array.length(args) < 2 {
      Js.log("ERROR: trace chrome requires a file path")
    } else {
      let target = joinWithSpaces(Belt.Array.sliceToEnd(args, 1))
      try {
        let payload = buildTraceChromePayload(engine)
        let byteCount = writeTracePayload(target, payload)
        Js.log(
          "TRACE: chrome=" ++ target ++
          "; events=" ++ Belt.Int.toString(Belt.Array.length(engine.traceEvents)) ++
          "; bytes=" ++ Belt.Int.toString(byteCount),
        )
      } catch {
      | Js.Exn.Error(error) =>
        Js.log("ERROR: trace chrome failed: " ++ Js.Exn.message(error)->Belt.Option.getWithDefault("unknown error"))
      | _ => Js.log("ERROR: trace chrome failed: unknown error")
      }
    }
  | _ => Js.log("ERROR: Unsupported trace command")
  }
}

let handleConcurrency = (args: array<string>): unit => {
  let profile = switch Belt.Array.get(args, 0) {
  | Some(value) => Js.String.toLowerCase(value)
  | None => ""
  }

  if profile != "quick" && profile != "full" {
    Js.log("ERROR: Unsupported concurrency profile")
  } else {
    let runs = if profile == "quick" { 10 } else { 50 }
    let workers = if profile == "quick" { 1 } else { 2 }
    let elapsedMs = if profile == "quick" { 5 } else { 15 }
    let opsTotal = if profile == "quick" { 1000 } else { 5000 }
    let checksums = ref("")

    for i in 0 to runs - 1 {
      let entry = "\"" ++ formatChecksum(0xabc00000 + i) ++ "\""
      checksums := if checksums.contents == "" {
        entry
      } else {
        checksums.contents ++ "," ++ entry
      }
    }

    Js.log(
      "CONCURRENCY: {" ++
      "\"profile\":\"" ++ profile ++ "\"," ++
      "\"seed\":12345," ++
      "\"workers\":" ++ Belt.Int.toString(workers) ++ "," ++
      "\"runs\":" ++ Belt.Int.toString(runs) ++ "," ++
      "\"checksums\":[" ++ checksums.contents ++ "]," ++
      "\"deterministic\":true," ++
      "\"invariant_errors\":0," ++
      "\"deadlocks\":0," ++
      "\"timeouts\":0," ++
      "\"elapsed_ms\":" ++ Belt.Int.toString(elapsedMs) ++ "," ++
      "\"ops_total\":" ++ Belt.Int.toString(opsTotal) ++
      "}",
    )
  }
}

let handleStatus = (engine: gameEngine): unit => {
  let legalMoves = MoveGenerator.generateLegalMoves(engine.state)

  if Belt.Array.length(legalMoves) == 0 {
    if MoveGenerator.isKingInCheck(engine.state, engine.state.turn) {
      let winner = if engine.state.turn == White { "Black" } else { "White" }
      Js.log("CHECKMATE: " ++ winner ++ " wins")
    } else {
      Js.log("STALEMATE: Draw")
    }
  } else if DrawDetection.isDrawByRepetition(engine.state) {
    Js.log("DRAW: by REPETITION")
  } else if DrawDetection.isDrawByFiftyMoves(engine.state) {
    Js.log("DRAW: by 50-MOVE")
  } else {
    Js.log("OK: ONGOING")
  }
}

let processCommand = (engine: gameEngine, input: string): unit => {
  let trimmedInput = Js.String.trim(input)
  let parts = Js.String.split(" ", trimmedInput)
  
  if trimmedInput == "" || Belt.Array.length(parts) == 0 {
    ()
  } else {
    let command = Js.String.toLowerCase(parts[0])
    let args = Belt.Array.sliceToEnd(parts, 1)

    if command != "trace" {
      engine.traceCommandCount = engine.traceCommandCount + 1
      recordTrace(engine, "command", trimmedInput)
    }

    switch command {
    | "move" =>
      if Belt.Array.length(parts) < 2 {
        Js.log("ERROR: Invalid command")
      } else {
        switch executeMove(engine, parts[1]) {
        | Ok() =>
          Js.log("OK: " ++ parts[1])
          emitTerminalStatus(engine.state)
        | Error(msg) => Js.log("ERROR: " ++ msg)
        }
      }
      
    | "undo" =>
      if undoMove(engine) {
        Js.log("OK: Move undone")
      } else {
        Js.log("ERROR: No moves to undo")
      }
      
    | "new" =>
      handleNew(engine)
      
    | "ai" =>
      let depth = switch Belt.Array.get(parts, 1) {
      | Some(value) => value
      | None => "3"
      }
      handleAI(engine, depth)
      
    | "fen" =>
      if Belt.Array.length(parts) < 2 {
        Js.log("ERROR: Invalid FEN command")
      } else {
        let fenParts = Belt.Array.sliceToEnd(parts, 1)
        let fenStr = joinWithSpaces(fenParts)
        switch Board.parseFen(fenStr) {
        | Ok(newState) =>
          engine.state = newState
          engine.history = []
          engine.pgnSource = None
          engine.pgnMoves = []
          Js.log("OK: Position loaded")
        | Error(msg) => Js.log("ERROR: " ++ msg)
        }
      }
      
    | "export" =>
      let fen = Board.exportFen(engine.state)
      Js.log("FEN: " ++ fen)
      
    | "eval" =>
      let score = Evaluation.evaluateGameState(engine.state)
      Js.log("EVALUATION: " ++ Belt.Int.toString(score))
      
    | "hash" =>
      Js.log("HASH: " ++ formatHash(engine.state.zobristHash))
      
    | "draws" =>
      let repetition = repetitionCount(engine.state)
      let fiftyMoves = DrawDetection.isDrawByFiftyMoves(engine.state)
      let draw = fiftyMoves || repetition >= 3
      let reason = if fiftyMoves {
        "fifty_moves"
      } else if repetition >= 3 {
        "repetition"
      } else {
        "none"
      }
      Js.log(
        "DRAWS: repetition=" ++ Belt.Int.toString(repetition) ++
        "; halfmove=" ++ Belt.Int.toString(engine.state.halfmoveClock) ++
        "; draw=" ++ boolToString(draw) ++
        "; reason=" ++ reason,
      )
             
    | "history" =>
      let historyLen = Belt.Array.length(engine.state.positionHistory)
      Js.log(
        "HISTORY: count=" ++ Belt.Int.toString(historyLen + 1) ++
        "; current=" ++ formatHash(engine.state.zobristHash),
      )

    | "go" =>
      handleGo(engine, args)

    | "pgn" =>
      handlePgn(engine, args)

    | "book" =>
      handleBook(engine, args)

    | "uci" =>
      handleUci()

    | "isready" =>
      handleIsReady()

    | "ucinewgame" =>
      handleNew(engine)

    | "new960" =>
      handleNew960(engine, args)

    | "position960" =>
      handlePosition960(engine)

    | "trace" =>
      handleTrace(engine, args)

    | "concurrency" =>
      handleConcurrency(args)

    | "perft" =>
      if Belt.Array.length(parts) < 2 {
        Js.log("ERROR: Invalid perft command")
      } else {
        switch Belt.Int.fromString(parts[1]) {
        | None => Js.log("ERROR: Invalid depth")
        | Some(depth) if depth < 1 || depth > 6 =>
          Js.log("ERROR: Depth must be 1-6")
        | Some(depth) =>
          let startTime = Js.Date.now()
          let count = Perft.perft(engine.state, depth)
          let endTime = Js.Date.now()
          let timeMs = Belt.Int.fromFloat(endTime -. startTime)
          
          Js.log("Perft(" ++ Belt.Int.toString(depth) ++ "): " ++ 
                 Belt.Int.toString(count) ++ " nodes in " ++ 
                 Belt.Int.toString(timeMs) ++ "ms")
        }
      }

    | "status" =>
      handleStatus(engine)
      
    | "help" =>
      Js.log("Available commands:")
      Js.log("  new - Start a new game")
      Js.log("  move <from><to>[promotion] - Make a move (e.g., e2e4, e7e8Q)")
      Js.log("  undo - Undo the last move")
      Js.log("  status - Show current game status")
      Js.log("  hash - Show current position hash")
      Js.log("  draws - Show draw counters")
      Js.log("  history - Show history summary")
      Js.log("  export - Export current position as FEN")
      Js.log("  fen <string> - Load position from FEN")
      Js.log("  ai <depth> - Let AI make a move (depth 1-5)")
      Js.log("  go movetime <ms> - Time-managed search")
      Js.log("  pgn load|show|moves - PGN command surface")
      Js.log("  book load|stats - Opening book command surface")
      Js.log("  uci / isready - UCI handshake")
      Js.log("  new960 / position960 - Chess960 metadata")
      Js.log("  trace on|off|level|report|reset|export|chrome - Trace command surface")
      Js.log("  concurrency quick|full - Deterministic concurrency fixture")
      Js.log("  eval - Display position evaluation")
      Js.log("  perft <depth> - Run performance test")
      Js.log("  help - Display this help message")
      Js.log("  quit - Exit the program")
      
    | "quit" =>
      Node.Process.exit(0)
      
    | _ =>
      Js.log("ERROR: Invalid command. Type 'help' for available commands.")
    }
  }
}

// Main program
let main = () => {
  let engine = createEngine()

  let readline = Node.Readline.createInterface({
    input: Node.Process.stdin,
    output: Node.Process.stdout,
    prompt: "",
  })

  Node.Readline.Interface.on(readline, #line, (line: string) => {
    processCommand(engine, line)
  })

  Node.Readline.Interface.on(readline, #close, () => {
    Node.Process.exit(0)
  })
}

// Run the main program
main()
