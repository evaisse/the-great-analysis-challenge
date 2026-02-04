open Types

type gameEngine = {
  mutable state: gameState,
  mutable history: array<gameState>,
}

let createEngine = (): gameEngine => {
  {
    state: Board.createInitialState(),
    history: [],
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
  } else {
    InProgress
  }
}

let processCommand = (engine: gameEngine, input: string): unit => {
  let parts = Js.String.split(" ", Js.String.trim(input))
  
  if Belt.Array.length(parts) == 0 {
    ()
  } else {
    switch parts[0] {
    | "move" =>
      if Belt.Array.length(parts) < 2 {
        Js.log("ERROR: Invalid command")
      } else {
        switch executeMove(engine, parts[1]) {
        | Ok() =>
          Js.log("OK: " ++ parts[1])
          
          switch checkGameStatus(engine.state) {
          | Checkmate(winner) =>
            let winnerStr = if winner == White { "White" } else { "Black" }
            Js.log("CHECKMATE: " ++ winnerStr ++ " wins")
          | Stalemate => Js.log("STALEMATE: Draw")
          | _ => ()
          }
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
      engine.state = Board.createInitialState()
      engine.history = []
      Js.log("OK: New game started")
      
    | "ai" =>
      let depth = if Belt.Array.length(parts) > 1 {
        Belt.Int.fromString(parts[1])->Belt.Option.getWithDefault(3)
      } else {
        3
      }
      
      if depth < 1 || depth > 5 {
        Js.log("ERROR: AI depth must be 1-5")
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
          
          let endTime = Js.Date.now()
          let timeMs = Belt.Int.fromFloat(endTime -. startTime)
          
          Js.log("AI: " ++ moveStrWithPromo ++ " (depth=" ++ Belt.Int.toString(depth) ++ 
                 ", eval=" ++ Belt.Int.toString(eval) ++ ", time=" ++ Belt.Int.toString(timeMs) ++ ")")
          
          switch checkGameStatus(engine.state) {
          | Checkmate(winner) =>
            let winnerStr = if winner == White { "White" } else { "Black" }
            Js.log("CHECKMATE: " ++ winnerStr ++ " wins")
          | Stalemate => Js.log("STALEMATE: Draw")
          | _ => ()
          }
        }
      }
      
    | "fen" =>
      if Belt.Array.length(parts) < 2 {
        Js.log("ERROR: Invalid FEN command")
      } else {
        let fenParts = Belt.Array.sliceToEnd(parts, 1)
        let fenStr =
          Belt.Array.reduce(fenParts, "", (acc, item) =>
            if acc == "" { item } else { acc ++ " " ++ item }
          )
        switch Board.parseFen(fenStr) {
        | Ok(newState) =>
          engine.state = newState
          engine.history = []
          Js.log("OK: Position loaded")
        | Error(msg) => Js.log("ERROR: " ++ msg)
        }
      }
      
    | "export" =>
      let fen = Board.exportFen(engine.state)
      Js.log("FEN: " ++ fen)
      
    | "eval" =>
      let score = Evaluation.evaluateGameState(engine.state)
      Js.log("Evaluation: " ++ Belt.Int.toString(score))
      
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
      
    | "help" =>
      Js.log("Available commands:")
      Js.log("  move <from><to>[promotion] - Make a move (e.g., e2e4, e7e8Q)")
      Js.log("  undo - Undo the last move")
      Js.log("  new - Start a new game")
      Js.log("  ai <depth> - Let AI make a move (depth 1-5)")
      Js.log("  fen <string> - Load position from FEN")
      Js.log("  export - Export current position as FEN")
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
  
  // Display board after each command
  if parts[0] != "help" && parts[0] != "quit" {
    Js.log("")
    Js.log(Board.boardToString(engine.state))
  }
}

// Main program
let main = () => {
  let engine = createEngine()
  
  Js.log("Chess Engine - ReScript Implementation")
  Js.log("Type 'help' for available commands")
  Js.log("")
  Js.log(Board.boardToString(engine.state))
  
  // Setup readline interface
  let readline = Node.Readline.createInterface({
    input: Node.Process.stdin,
    output: Node.Process.stdout,
    prompt: "> ",
  })
  
  Node.Readline.Interface.prompt(readline)
  
  Node.Readline.Interface.on(readline, #line, (line: string) => {
    processCommand(engine, line)
    Node.Readline.Interface.prompt(readline)
  })
  
  Node.Readline.Interface.on(readline, #close, () => {
    Js.log("\nGoodbye!")
    Node.Process.exit(0)
  })
}

// Run the main program
main()
