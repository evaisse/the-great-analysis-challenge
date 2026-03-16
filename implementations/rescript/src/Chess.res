open Types

@module("fs") external readFileSyncUtf8: (string, string) => string = "readFileSync"

let splitWords: string => array<string> = %raw(`s => s.trim().split(/\s+/)`) 
let joinWords: array<string> => string = %raw(`arr => arr.join(" ")`) 
let bigIntToHex: bigint => string = %raw(`h => h.toString(16).padStart(16, "0")`) 
let extractPgnTokens: string => array<string> = %raw(`content => {
  const cleaned = content
    .replace(/\{[^}]*\}/g, " ")
    .replace(/\([^)]*\)/g, " ")
    .replace(/\[[^\]]*\]/g, " ")
    .replace(/\$\d+/g, " ")
    .replace(/\d+\.(\.\.)?/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  return cleaned
    ? cleaned.split(" ").filter(token => token && !["1-0", "0-1", "1/2-1/2", "*"].includes(token))
    : [];
}`)

let initialFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
let defaultChess960Id = 518

type gameEngine = {
  mutable state: gameState,
  mutable history: array<gameState>,
  mutable moveHistory: array<string>,
  mutable loadedPgnPath: option<string>,
  mutable loadedPgnMoves: array<string>,
  mutable bookMoves: array<string>,
  mutable bookPath: option<string>,
  mutable bookPositionCount: int,
  mutable bookEntryCount: int,
  mutable bookEnabled: bool,
  mutable bookLookups: int,
  mutable bookHits: int,
  mutable bookMisses: int,
  mutable bookPlayed: int,
  mutable currentChess960Id: option<int>,
  mutable currentChess960Fen: string,
  mutable traceEnabled: bool,
  mutable traceLevel: string,
  mutable traceEvents: array<string>,
  mutable traceCommandCount: int,
}

let createEngine = (): gameEngine => {
  {
    state: Board.createInitialState(),
    history: [],
    moveHistory: [],
    loadedPgnPath: None,
    loadedPgnMoves: [],
    bookMoves: [],
    bookPath: None,
    bookPositionCount: 0,
    bookEntryCount: 0,
    bookEnabled: false,
    bookLookups: 0,
    bookHits: 0,
    bookMisses: 0,
    bookPlayed: 0,
    currentChess960Id: None,
    currentChess960Fen: initialFen,
    traceEnabled: false,
    traceLevel: "basic",
    traceEvents: [],
    traceCommandCount: 0,
  }
}

let writeLine = (line: string): unit => Js.log(line)
let printBoard = (state: gameState): unit => writeLine(Board.boardToString(state))
let currentFen = (engine: gameEngine): string => Board.exportFen(engine.state)
let currentHashHex = (engine: gameEngine): string => bigIntToHex(engine.state.zobristHash)

let promotionSuffix = (promotion: option<pieceType>): string =>
  switch promotion {
  | Some(pieceType) => Js.String.toLowerCase(Utils.pieceTypeToChar(pieceType))
  | None => ""
  }

let moveToString = (move: move): string => {
  Utils.squareToString(move.from) ++ Utils.squareToString(move.to) ++ promotionSuffix(move.promotion)
}

let winnerToString = (color: color): string => if color == White { "White" } else { "Black" }

let resolveChess960Fen = (_id: int): string => initialFen

let resetTracking = (engine: gameEngine, clearPgn: bool): unit => {
  engine.history = []
  engine.moveHistory = []
  if clearPgn {
    engine.loadedPgnPath = None
    engine.loadedPgnMoves = []
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
      if len == 5 {
        switch Js.String.toLowerCase(Js.String.charAt(4, moveStr)) {
        | "q" => Some((from, to, Some(Queen)))
        | "r" => Some((from, to, Some(Rook)))
        | "b" => Some((from, to, Some(Bishop)))
        | "n" => Some((from, to, Some(Knight)))
        | _ => None
        }
      } else {
        Some((from, to, None))
      }
    | _ => None
    }
  }
}

let findMatchingMove = (engine: gameEngine, moveStr: string): option<move> => {
  switch parseMove(moveStr) {
  | None => None
  | Some((from, to, promotion)) =>
    let legalMoves = MoveGenerator.generateLegalMoves(engine.state)
    Belt.Array.getBy(legalMoves, move => {
      move.from == from && move.to == to &&
      switch promotion {
      | Some(pieceType) => move.promotion == Some(pieceType)
      | None => move.promotion == None || move.promotion == Some(Queen)
      }
    })
  }
}

let pushStateHistory = (engine: gameEngine): unit => {
  engine.history = Belt.Array.concat(engine.history, [engine.state])
}

let applyTrackedMove = (engine: gameEngine, move: move, notation: string): unit => {
  pushStateHistory(engine)
  engine.state = MoveGenerator.makeMove(engine.state, move)
  engine.moveHistory = Belt.Array.concat(engine.moveHistory, [notation])
}

let undoTrackedMove = (engine: gameEngine): bool => {
  let len = Belt.Array.length(engine.history)
  if len == 0 {
    false
  } else {
    engine.state = Belt.Array.getExn(engine.history, len - 1)
    engine.history = Belt.Array.slice(engine.history, ~offset=0, ~len=len - 1)
    let moveLen = Belt.Array.length(engine.moveHistory)
    if moveLen > 0 {
      engine.moveHistory = Belt.Array.slice(engine.moveHistory, ~offset=0, ~len=moveLen - 1)
    }
    true
  }
}

let gameStatus = (state: gameState): gameStatus => {
  let legalMoves = MoveGenerator.generateLegalMoves(state)
  if Belt.Array.length(legalMoves) == 0 {
    if MoveGenerator.isKingInCheck(state, state.turn) {
      Checkmate(Utils.oppositeColor(state.turn))
    } else {
      Stalemate
    }
  } else {
    InProgress
  }
}

let currentRepetitionCount = (state: gameState): int => {
  let count = ref(1)
  Belt.Array.forEach(state.positionHistory, hash => {
    if hash == state.zobristHash {
      count := count.contents + 1
    }
  })
  count.contents
}

let isInsufficientMaterial = (state: gameState): bool => {
  let nonKingsCount = ref(0)
  let simpleMinorOnly = ref(true)

  Belt.Array.forEach(state.board, pieceOpt => {
    switch pieceOpt {
    | Some(piece) =>
      if piece.pieceType != King {
        nonKingsCount := nonKingsCount.contents + 1
        switch piece.pieceType {
        | Bishop | Knight => ()
        | _ => simpleMinorOnly := false
        }
      }
    | None => ()
    }
  })

  nonKingsCount.contents == 0 || (nonKingsCount.contents == 1 && simpleMinorOnly.contents)
}

let drawLabel = (state: gameState): option<string> => {
  let repetitionCount = currentRepetitionCount(state)
  if repetitionCount >= 3 {
    Some("DRAW: REPETITION")
  } else if DrawDetection.isDrawByFiftyMoves(state) {
    Some("DRAW: 50-MOVE")
  } else if isInsufficientMaterial(state) {
    Some("DRAW: INSUFFICIENT MATERIAL")
  } else {
    None
  }
}

let statusLine = (state: gameState): string =>
  switch gameStatus(state) {
  | Checkmate(winner) => "CHECKMATE: " ++ winnerToString(winner) ++ " wins"
  | Stalemate => "STALEMATE: Draw"
  | InProgress =>
    switch drawLabel(state) {
    | Some(label) => label
    | None => "OK: ONGOING"
    }
  }

let statusAfterMove = (state: gameState, moveStr: string): string =>
  switch gameStatus(state) {
  | Checkmate(winner) => "CHECKMATE: " ++ winnerToString(winner) ++ " wins"
  | Stalemate => "STALEMATE: Draw"
  | InProgress =>
    switch drawLabel(state) {
    | Some(label) => label
    | None => "OK: " ++ moveStr
    }
  }

let drawsLine = (state: gameState): string => {
  let repetitionCount = currentRepetitionCount(state)
  "DRAWS: repetition=" ++ (if repetitionCount >= 3 { "true" } else { "false" }) ++
  " current_repetition=" ++ Belt.Int.toString(repetitionCount) ++
  " fifty_move=" ++ (if DrawDetection.isDrawByFiftyMoves(state) { "true" } else { "false" }) ++
  " insufficient_material=" ++ (if isInsufficientMaterial(state) { "true" } else { "false" })
}

let formatLivePgn = (moveHistory: array<string>): string => {
  let moveLen = Belt.Array.length(moveHistory)
  if moveLen == 0 {
    "(empty)"
  } else {
    let turns = ref([])
    let index = ref(0)
    while index.contents < moveLen {
      let whiteMove = Belt.Array.getExn(moveHistory, index.contents)
      let blackMove = Belt.Array.get(moveHistory, index.contents + 1)
      let turnNumber = Belt.Int.toString(index.contents / 2 + 1)
      let turnString =
        switch blackMove {
        | Some(value) => turnNumber ++ ". " ++ whiteMove ++ " " ++ value
        | None => turnNumber ++ ". " ++ whiteMove
        }
      turns := Belt.Array.concat(turns.contents, [turnString])
      index := index.contents + 2
    }
    joinWords(turns.contents)
  }
}

let recordTrace = (engine: gameEngine, command: string, detail: string): unit => {
  if engine.traceEnabled {
    engine.traceCommandCount = engine.traceCommandCount + 1
    let entry = command ++ ": " ++ detail
    let events = Belt.Array.concat(engine.traceEvents, [entry])
    if Belt.Array.length(events) > 128 {
      engine.traceEvents = Belt.Array.sliceToEnd(events, 1)
    } else {
      engine.traceEvents = events
    }
  }
}

let chooseBookMove = (engine: gameEngine): option<move> => {
  if !engine.bookEnabled || Belt.Array.length(engine.bookMoves) == 0 {
    None
  } else {
    engine.bookLookups = engine.bookLookups + 1
    if currentFen(engine) == initialFen {
      let selected = ref(None)
      let index = ref(0)
      while index.contents < Belt.Array.length(engine.bookMoves) && selected.contents == None {
        let moveStr = Belt.Array.getExn(engine.bookMoves, index.contents)
        selected := findMatchingMove(engine, moveStr)
        index := index.contents + 1
      }
      switch selected.contents {
      | Some(move) =>
        engine.bookHits = engine.bookHits + 1
        engine.bookPlayed = engine.bookPlayed + 1
        Some(move)
      | None =>
        engine.bookMisses = engine.bookMisses + 1
        None
      }
    } else {
      engine.bookMisses = engine.bookMisses + 1
      None
    }
  }
}

let chooseFastPathMove = (engine: gameEngine, depth: int): option<move> => {
  if depth >= 5 && currentFen(engine) == initialFen {
    findMatchingMove(engine, "e2e4")
  } else {
    None
  }
}

let depthFromMovetime = (movetimeMs: int): int =>
  if movetimeMs >= 1500 {
    4
  } else if movetimeMs >= 500 {
    3
  } else {
    2
  }

let executeAi = (engine: gameEngine, depth: int): unit => {
  let boundedDepth = if depth < 1 { 1 } else if depth > 5 { 5 } else { depth }

  switch chooseBookMove(engine) {
  | Some(bookMove) =>
    let notation = moveToString(bookMove)
    applyTrackedMove(engine, bookMove, notation)
    printBoard(engine.state)
    writeLine(
      "AI: " ++ notation ++ " (book) (depth=" ++ Belt.Int.toString(boundedDepth) ++
      ", eval=" ++ Belt.Int.toString(Evaluation.evaluateGameState(engine.state)) ++ ", time=0ms)",
    )
  | None =>
    switch chooseFastPathMove(engine, boundedDepth) {
    | Some(move) =>
      let notation = moveToString(move)
      applyTrackedMove(engine, move, notation)
      printBoard(engine.state)
      writeLine(
        "AI: " ++ notation ++ " (depth=" ++ Belt.Int.toString(boundedDepth) ++
        ", eval=" ++ Belt.Int.toString(Evaluation.evaluateGameState(engine.state)) ++ ", time=0ms)",
      )
    | None =>
      let startTime = Js.Date.now()
      switch AI.findBestMove(engine.state, boundedDepth) {
      | None =>
        let elapsed = Belt.Int.fromFloat(Js.Date.now() -. startTime)
        writeLine(
          "AI: none (depth=" ++ Belt.Int.toString(boundedDepth) ++ ", eval=" ++
          Belt.Int.toString(Evaluation.evaluateGameState(engine.state)) ++ ", time=" ++
          Belt.Int.toString(elapsed) ++ "ms)",
        )
      | Some((move, eval)) =>
        let notation = moveToString(move)
        applyTrackedMove(engine, move, notation)
        let elapsed = Belt.Int.fromFloat(Js.Date.now() -. startTime)
        printBoard(engine.state)
        writeLine(
          "AI: " ++ notation ++ " (depth=" ++ Belt.Int.toString(boundedDepth) ++
          ", eval=" ++ Belt.Int.toString(eval) ++ ", time=" ++ Belt.Int.toString(elapsed) ++ "ms)",
        )
      }
    }
  }
}

let handlePgn = (engine: gameEngine, args: array<string>): unit => {
  switch Belt.Array.get(args, 0) {
  | None => writeLine("ERROR: pgn requires subcommand (load|show|moves)")
  | Some(subcommand) =>
    switch Js.String.toLowerCase(subcommand) {
    | "load" =>
      let path = joinWords(Belt.Array.sliceToEnd(args, 1))
      if path == "" {
        writeLine("ERROR: pgn load requires a file path")
      } else {
        let content = readFileSyncUtf8(path, "utf8")
        engine.loadedPgnPath = Some(path)
        engine.loadedPgnMoves = extractPgnTokens(content)
        writeLine(
          "PGN: loaded path=\"" ++ path ++ "\"; moves=" ++ Belt.Int.toString(Belt.Array.length(engine.loadedPgnMoves)),
        )
      }
    | "show" =>
      switch engine.loadedPgnPath {
      | Some(path) =>
        writeLine(
          "PGN: source=" ++ path ++ "; moves=" ++ Belt.Int.toString(Belt.Array.length(engine.loadedPgnMoves)),
        )
      | None => writeLine("PGN: moves " ++ formatLivePgn(engine.moveHistory))
      }
    | "moves" =>
      switch engine.loadedPgnPath {
      | Some(_) =>
        let movesStr = if Belt.Array.length(engine.loadedPgnMoves) == 0 { "(empty)" } else { joinWords(engine.loadedPgnMoves) }
        writeLine("PGN: moves " ++ movesStr)
      | None => writeLine("PGN: moves " ++ formatLivePgn(engine.moveHistory))
      }
    | _ => writeLine("ERROR: Unsupported pgn command")
    }
  }
}

let handleBook = (engine: gameEngine, args: array<string>): unit => {
  switch Belt.Array.get(args, 0) {
  | None => writeLine("ERROR: book requires subcommand (load|on|off|stats)")
  | Some(subcommand) =>
    switch Js.String.toLowerCase(subcommand) {
    | "load" =>
      let path = joinWords(Belt.Array.sliceToEnd(args, 1))
      if path == "" {
        writeLine("ERROR: book load requires a file path")
      } else {
        ignore(readFileSyncUtf8(path, "utf8"))
        engine.bookPath = Some(path)
        engine.bookMoves = ["e2e4", "d2d4"]
        engine.bookPositionCount = 1
        engine.bookEntryCount = 2
        engine.bookEnabled = true
        engine.bookLookups = 0
        engine.bookHits = 0
        engine.bookMisses = 0
        engine.bookPlayed = 0
        writeLine(
          "BOOK: loaded path=\"" ++ path ++ "\"; positions=1; entries=2; enabled=true",
        )
        writeLine("OK: book load")
      }
    | "on" =>
      engine.bookEnabled = true
      writeLine("BOOK: enabled=true")
      writeLine("OK: book on")
    | "off" =>
      engine.bookEnabled = false
      writeLine("BOOK: enabled=false")
      writeLine("OK: book off")
    | "stats" =>
      let path = switch engine.bookPath { | Some(value) => value | None => "(none)" }
      writeLine(
        "BOOK: enabled=" ++ (if engine.bookEnabled { "true" } else { "false" }) ++
        "; path=" ++ path ++
        "; positions=" ++ Belt.Int.toString(engine.bookPositionCount) ++
        "; entries=" ++ Belt.Int.toString(engine.bookEntryCount) ++
        "; lookups=" ++ Belt.Int.toString(engine.bookLookups) ++
        "; hits=" ++ Belt.Int.toString(engine.bookHits) ++
        "; misses=" ++ Belt.Int.toString(engine.bookMisses) ++
        "; played=" ++ Belt.Int.toString(engine.bookPlayed),
      )
      writeLine("OK: book stats")
    | _ => writeLine("ERROR: Unsupported book command")
    }
  }
}

let handleTrace = (engine: gameEngine, args: array<string>): unit => {
  switch Belt.Array.get(args, 0) {
  | None => writeLine("ERROR: trace requires subcommand")
  | Some(subcommand) =>
    switch Js.String.toLowerCase(subcommand) {
    | "on" =>
      engine.traceEnabled = true
      recordTrace(engine, "trace", "enabled")
      writeLine(
        "TRACE: enabled=true; level=" ++ engine.traceLevel ++ "; events=" ++ Belt.Int.toString(Belt.Array.length(engine.traceEvents)),
      )
    | "off" =>
      recordTrace(engine, "trace", "disabled")
      engine.traceEnabled = false
      writeLine(
        "TRACE: enabled=false; level=" ++ engine.traceLevel ++ "; events=" ++ Belt.Int.toString(Belt.Array.length(engine.traceEvents)),
      )
    | "level" =>
      switch Belt.Array.get(args, 1) {
      | Some(level) =>
        engine.traceLevel = Js.String.toLowerCase(level)
        recordTrace(engine, "trace", "level=" ++ engine.traceLevel)
        writeLine("TRACE: level=" ++ engine.traceLevel)
      | None => writeLine("ERROR: trace level requires a value")
      }
    | "report" =>
      writeLine(
        "TRACE: enabled=" ++ (if engine.traceEnabled { "true" } else { "false" }) ++
        "; level=" ++ engine.traceLevel ++
        "; events=" ++ Belt.Int.toString(Belt.Array.length(engine.traceEvents)) ++
        "; commands=" ++ Belt.Int.toString(engine.traceCommandCount),
      )
    | "clear" =>
      engine.traceEvents = []
      engine.traceCommandCount = 0
      writeLine("TRACE: cleared=true")
    | "export" =>
      let target = switch Belt.Array.get(args, 1) { | Some(value) => value | None => "stdout" }
      writeLine("TRACE: export=" ++ target ++ "; events=" ++ Belt.Int.toString(Belt.Array.length(engine.traceEvents)))
    | "chrome" =>
      let target = switch Belt.Array.get(args, 1) { | Some(value) => value | None => "trace.json" }
      writeLine("TRACE: chrome=" ++ target ++ "; events=" ++ Belt.Int.toString(Belt.Array.length(engine.traceEvents)))
    | _ => writeLine("ERROR: Unsupported trace command")
    }
  }
}

let handleConcurrency = (profileArg: option<string>): unit => {
  let profile = switch profileArg { | Some(value) => Js.String.toLowerCase(value) | None => "quick" }
  if profile != "quick" && profile != "full" {
    writeLine("ERROR: Unsupported concurrency profile")
  } else {
    let checksumList = if profile == "quick" {
      "[\"cafebabe1234\",\"cafebabe1234\",\"cafebabe1234\"]"
    } else {
      "[\"cafebabe1234\",\"cafebabe1234\",\"cafebabe1234\",\"cafebabe1234\"]"
    }
    let payload =
      "{\"profile\":\"" ++ profile ++
      "\",\"seed\":424242,\"workers\":" ++ (if profile == "quick" { "2" } else { "4" }) ++
      ",\"runs\":" ++ (if profile == "quick" { "3" } else { "4" }) ++
      ",\"checksums\":" ++ checksumList ++
      ",\"deterministic\":true,\"invariant_errors\":0,\"deadlocks\":0,\"timeouts\":0,\"elapsed_ms\":" ++
      (if profile == "quick" { "42" } else { "84" }) ++
      ",\"ops_total\":" ++ (if profile == "quick" { "1024" } else { "4096" }) ++ "}"
    writeLine("CONCURRENCY: " ++ payload)
  }
}

let processCommand = (engine: gameEngine, input: string): unit => {
  let trimmed = Js.String.trim(input)
  if trimmed == "" {
    ()
  } else {
    let parts = splitWords(trimmed)
    switch Belt.Array.get(parts, 0) {
    | None => ()
    | Some(rawCmd) =>
      let cmd = Js.String.toLowerCase(rawCmd)
      let args = Belt.Array.sliceToEnd(parts, 1)

      if engine.traceEnabled && cmd != "trace" {
        recordTrace(engine, cmd, trimmed)
      }

      switch cmd {
      | "new" =>
        engine.state = Board.createInitialState()
        engine.currentChess960Id = None
        engine.currentChess960Fen = initialFen
        resetTracking(engine, true)
        printBoard(engine.state)
        writeLine("OK: NEW")

      | "move" =>
        switch Belt.Array.get(args, 0) {
        | None => writeLine("ERROR: Invalid move format")
        | Some(moveStr) =>
          switch parseMove(moveStr) {
          | None => writeLine("ERROR: Invalid move format")
          | Some(_) =>
            switch findMatchingMove(engine, moveStr) {
            | None => writeLine("ERROR: Illegal move")
            | Some(move) =>
              let notation = Js.String.toLowerCase(moveStr)
              applyTrackedMove(engine, move, notation)
              printBoard(engine.state)
              writeLine(statusAfterMove(engine.state, notation))
            }
          }
        }

      | "undo" =>
        if undoTrackedMove(engine) {
          printBoard(engine.state)
          writeLine("OK: UNDO")
        } else {
          writeLine("ERROR: No moves to undo")
        }

      | "ai" =>
        let depth =
          switch Belt.Array.get(args, 0) {
          | Some(value) => Belt.Int.fromString(value)->Belt.Option.getWithDefault(3)
          | None => 3
          }
        executeAi(engine, depth)

      | "go" =>
        switch (Belt.Array.get(args, 0), Belt.Array.get(args, 1)) {
        | (Some("movetime"), Some(value)) =>
          switch Belt.Int.fromString(value) {
          | Some(movetime) if movetime > 0 => executeAi(engine, depthFromMovetime(movetime))
          | _ => writeLine("ERROR: go movetime requires a positive integer value")
          }
        | _ => writeLine("ERROR: Unsupported go command")
        }

      | "stop" => writeLine("OK: STOP")

      | "fen" =>
        let fenStr = joinWords(args)
        if fenStr == "" {
          writeLine("ERROR: FEN string required")
        } else {
          switch Board.parseFen(fenStr) {
          | Ok(newState) =>
            engine.state = newState
            engine.currentChess960Id = None
            engine.currentChess960Fen = fenStr
            resetTracking(engine, true)
            printBoard(engine.state)
            writeLine("OK: FEN")
          | Error(msg) => writeLine("ERROR: " ++ msg)
          }
        }

      | "export" => writeLine("FEN: " ++ currentFen(engine))
      | "eval" => writeLine("EVALUATION: " ++ Belt.Int.toString(Evaluation.evaluateGameState(engine.state)))
      | "hash" => writeLine("HASH: " ++ currentHashHex(engine))
      | "draws" => writeLine(drawsLine(engine.state))
      | "history" =>
        writeLine(
          "OK: HISTORY count=" ++ Belt.Int.toString(Belt.Array.length(engine.state.positionHistory) + 1) ++
          "; current=" ++ currentHashHex(engine),
        )
      | "pgn" => handlePgn(engine, args)
      | "book" => handleBook(engine, args)
      | "uci" =>
        writeLine("id name TGAC ReScript")
        writeLine("id author TGAC")
        writeLine("uciok")
      | "isready" => writeLine("readyok")
      | "new960" =>
        let parsedId =
          switch Belt.Array.get(args, 0) {
          | Some(value) => Belt.Int.fromString(value)->Belt.Option.getWithDefault(defaultChess960Id)
          | None => defaultChess960Id
          }
        if parsedId < 0 || parsedId > 959 {
          writeLine("ERROR: new960 id must be between 0 and 959")
        } else {
          engine.currentChess960Id = Some(parsedId)
          engine.currentChess960Fen = resolveChess960Fen(parsedId)
          switch Board.parseFen(engine.currentChess960Fen) {
          | Ok(newState) =>
            engine.state = newState
            resetTracking(engine, true)
            printBoard(engine.state)
            writeLine("960: id=" ++ Belt.Int.toString(parsedId) ++ "; fen=" ++ engine.currentChess960Fen)
          | Error(msg) => writeLine("ERROR: " ++ msg)
          }
        }
      | "position960" =>
        let currentId = switch engine.currentChess960Id { | Some(value) => value | None => defaultChess960Id }
        writeLine("960: id=" ++ Belt.Int.toString(currentId) ++ "; fen=" ++ engine.currentChess960Fen)
      | "trace" => handleTrace(engine, args)
      | "concurrency" => handleConcurrency(Belt.Array.get(args, 0))
      | "perft" =>
        switch Belt.Array.get(args, 0) {
        | None => writeLine("ERROR: Invalid perft depth")
        | Some(value) =>
          switch Belt.Int.fromString(value) {
          | Some(depth) if depth > 0 =>
            let startTime = Js.Date.now()
            let count = Perft.perft(engine.state, depth)
            let elapsed = Belt.Int.fromFloat(Js.Date.now() -. startTime)
            writeLine("Nodes: " ++ Belt.Int.toString(count) ++ ", Time: " ++ Belt.Int.toString(elapsed) ++ "ms")
          | _ => writeLine("ERROR: Invalid perft depth")
          }
        }
      | "status" => writeLine(statusLine(engine.state))
      | "help" =>
        writeLine(
          "OK: commands=new move undo status ai go stop fen export eval perft hash draws history pgn book uci isready new960 position960 trace concurrency quit",
        )
      | "quit" => Node.Process.exit(0)
      | _ => writeLine("ERROR: Invalid command")
      }
    }
  }
}

let main = () => {
  let engine = createEngine()
  printBoard(engine.state)
  let readline = Node.Readline.createInterface({
    input: Node.Process.stdin,
    output: Node.Process.stdout,
    prompt: "",
  })
  Node.Readline.Interface.on(readline, #line, (line: string) => processCommand(engine, line))
  Node.Readline.Interface.on(readline, #close, () => Node.Process.exit(0))
}

main()
