open Types
open Utils

let createEmptyBoard = (): array<option<piece>> => Array.make(64, None)

let createInitialBoard = (): array<option<piece>> => {
  let board = Array.make(64, None)

  let setPieceAt = (square: int, pieceType: pieceType, color: color) =>
    Belt.Array.setExn(board, square, Some({pieceType, color}))

  // White pieces
  setPieceAt(0, Rook, White)
  setPieceAt(1, Knight, White)
  setPieceAt(2, Bishop, White)
  setPieceAt(3, Queen, White)
  setPieceAt(4, King, White)
  setPieceAt(5, Bishop, White)
  setPieceAt(6, Knight, White)
  setPieceAt(7, Rook, White)

  for i in 8 to 15 {
    setPieceAt(i, Pawn, White)
  }

  // Black pieces
  setPieceAt(56, Rook, Black)
  setPieceAt(57, Knight, Black)
  setPieceAt(58, Bishop, Black)
  setPieceAt(59, Queen, Black)
  setPieceAt(60, King, Black)
  setPieceAt(61, Bishop, Black)
  setPieceAt(62, Knight, Black)
  setPieceAt(63, Rook, Black)

  for i in 48 to 55 {
    setPieceAt(i, Pawn, Black)
  }

  board
}

let createInitialState = (): gameState => {
  let state = {
    board: createInitialBoard(),
    turn: White,
    castlingRights: {
      whiteKingside: true,
      whiteQueenside: true,
      blackKingside: true,
      blackQueenside: true,
    },
    enPassantTarget: None,
    halfmoveClock: 0,
    fullmoveNumber: 1,
    moveHistory: [],
    zobristHash: 0n,
    positionHistory: [],
    irreversibleHistory: [],
  }
  {...state, zobristHash: Zobrist.computeHash(state)}
}

let getPiece = (state: gameState, square: square): option<piece> => {
  if square < 0 || square >= 64 {
    None
  } else {
    Belt.Array.getExn(state.board, square)
  }
}

let setPiece = (state: gameState, square: square, piece: option<piece>): gameState => {
  let newBoard = Belt.Array.copy(state.board)
  Belt.Array.setExn(newBoard, square, piece)
  {...state, board: newBoard}
}

let boardToString = (state: gameState): string => {
  let output = ref("  a b c d e f g h\n")

  for rowIndex in 0 to 7 {
    let rank = 7 - rowIndex
    output := output.contents ++ Belt.Int.toString(rank + 1) ++ " "

    for file in 0 to 7 {
      let square = rank * 8 + file
      let char =
        switch getPiece(state, square) {
        | Some(piece) => pieceToChar(piece)
        | None => "."
        }
      output := output.contents ++ char ++ " "
    }

    output := output.contents ++ Belt.Int.toString(rank + 1) ++ "\n"
  }

  output := output.contents ++ "  a b c d e f g h\n\n"
  let turnLabel = if state.turn == White { "White" } else { "Black" }
  output := output.contents ++ turnLabel ++ " to move"

  output.contents
}

let parseFen = (fen: string): result<gameState, string> => {
  let parts = Js.String.split(" ", Js.String.trim(fen))

  if Belt.Array.length(parts) < 4 {
    Error("Invalid FEN string")
  } else {
    let pieces = Belt.Array.getExn(parts, 0)
    let turnPart = Belt.Array.getExn(parts, 1)
    let castlingPart = Belt.Array.getExn(parts, 2)
    let enPassantPart = Belt.Array.getExn(parts, 3)
    let halfmovePart =
      switch Belt.Array.get(parts, 4) {
      | Some(value) => value
      | None => "0"
      }
    let fullmovePart =
      switch Belt.Array.get(parts, 5) {
      | Some(value) => value
      | None => "1"
      }

    let board = Array.make(64, None)
    let square = ref(56)
    let length = Js.String.length(pieces)

    for i in 0 to length - 1 {
      let char = Js.String.charAt(i, pieces)
      switch char {
      | "/" => square := square.contents - 16
      | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" =>
        switch Belt.Int.fromString(char) {
        | Some(step) => square := square.contents + step
        | None => ()
        }
      | _ =>
        switch charToPiece(char) {
        | Some(piece) =>
          Belt.Array.setExn(board, square.contents, Some(piece))
          square := square.contents + 1
        | None => ()
        }
      }
    }

    let turn = if turnPart == "w" { White } else { Black }

    let hasCastling = (char: string) => Js.String.indexOf(castlingPart, char) != -1

    let castlingRights = {
      whiteKingside: hasCastling("K"),
      whiteQueenside: hasCastling("Q"),
      blackKingside: hasCastling("k"),
      blackQueenside: hasCastling("q"),
    }

    let enPassantTarget =
      if enPassantPart == "-" {
        None
      } else {
        parseSquare(enPassantPart)
      }

    let halfmoveClock =
      switch Belt.Int.fromString(halfmovePart) {
      | Some(value) => value
      | None => 0
      }

    let fullmoveNumber =
      switch Belt.Int.fromString(fullmovePart) {
      | Some(value) => value
      | None => 1
      }

    let state = {
      board,
      turn,
      castlingRights,
      enPassantTarget,
      halfmoveClock,
      fullmoveNumber,
      moveHistory: [],
      zobristHash: 0n,
      positionHistory: [],
      irreversibleHistory: [],
    }
    Ok({...state, zobristHash: Zobrist.computeHash(state)})
  }
}

let exportFen = (state: gameState): string => {
  let pieces = ref("")

  for rowIndex in 0 to 7 {
    let rank = 7 - rowIndex
    let emptyCount = ref(0)

    for file in 0 to 7 {
      let square = rank * 8 + file
      switch getPiece(state, square) {
      | Some(piece) =>
        if emptyCount.contents > 0 {
          pieces := pieces.contents ++ Belt.Int.toString(emptyCount.contents)
          emptyCount := 0
        }
        pieces := pieces.contents ++ pieceToChar(piece)
      | None => emptyCount := emptyCount.contents + 1
      }
    }

    if emptyCount.contents > 0 {
      pieces := pieces.contents ++ Belt.Int.toString(emptyCount.contents)
    }

    if rank > 0 {
      pieces := pieces.contents ++ "/"
    }
  }

  let turn = if state.turn == White { "w" } else { "b" }

  let castling = ref("")
  if state.castlingRights.whiteKingside { castling := castling.contents ++ "K" }
  if state.castlingRights.whiteQueenside { castling := castling.contents ++ "Q" }
  if state.castlingRights.blackKingside { castling := castling.contents ++ "k" }
  if state.castlingRights.blackQueenside { castling := castling.contents ++ "q" }

  let castlingStr = if castling.contents == "" { "-" } else { castling.contents }

  let enPassant =
    switch state.enPassantTarget {
    | None => "-"
    | Some(square) => squareToString(square)
    }

  pieces.contents ++
  " " ++
  turn ++
  " " ++
  castlingStr ++
  " " ++
  enPassant ++
  " " ++
  Belt.Int.toString(state.halfmoveClock) ++
  " " ++
  Belt.Int.toString(state.fullmoveNumber)
}
