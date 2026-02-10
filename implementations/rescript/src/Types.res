type pieceType = Pawn | Knight | Bishop | Rook | Queen | King

type color = White | Black

type square = int

type piece = {
  pieceType: pieceType,
  color: color,
}

type move = {
  from: square,
  to: square,
  piece: pieceType,
  captured: option<pieceType>,
  promotion: option<pieceType>,
  castling: option<string>,
  enPassant: bool,
}

type castlingRights = {
  whiteKingside: bool,
  whiteQueenside: bool,
  blackKingside: bool,
  blackQueenside: bool,
}

type irreversibleState = {
  castlingRights: castlingRights,
  enPassantTarget: option<square>,
  halfmoveClock: int,
  zobristHash: bigint,
}

type gameState = {
  board: array<option<piece>>,
  turn: color,
  castlingRights: castlingRights,
  enPassantTarget: option<square>,
  halfmoveClock: int,
  fullmoveNumber: int,
  moveHistory: array<move>,
  zobristHash: bigint,
  positionHistory: array<bigint>,
  irreversibleHistory: array<irreversibleState>,
}

type gameStatus =
  | InProgress
  | Checkmate(color)
  | Stalemate

let files: array<string> = ["a", "b", "c", "d", "e", "f", "g", "h"]
let ranks: array<string> = ["1", "2", "3", "4", "5", "6", "7", "8"]

let promotionPieces: array<pieceType> = [Queen, Rook, Bishop, Knight]

let pieceValue = (pieceType: pieceType): int =>
  switch pieceType {
  | Pawn => 100
  | Knight => 320
  | Bishop => 330
  | Rook => 500
  | Queen => 900
  | King => 20000
  }
