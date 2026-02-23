// Core chess types and data structures

import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/int

pub type Color {
  White
  Black
}

pub type PieceType {
  King
  Queen
  Rook
  Bishop
  Knight
  Pawn
}

pub type Piece {
  Piece(piece_type: PieceType, color: Color)
}

pub type Square =
  Int

pub type Move {
  Move(
    from: Square,
    to: Square,
    piece: PieceType,
    captured: Option(PieceType),
    promotion: Option(PieceType),
    is_castling: Bool,
    is_en_passant: Bool,
  )
}

pub type CastlingRights {
  CastlingRights(
    white_kingside: Bool,
    white_queenside: Bool,
    black_kingside: Bool,
    black_queenside: Bool,
  )
}

pub type GameState {
  GameState(
    board: List(Option(Piece)),
    turn: Color,
    castling_rights: CastlingRights,
    en_passant_target: Option(Square),
    halfmove_clock: Int,
    fullmove_number: Int,
    move_history: List(Move),
  )
}

pub type SearchResult {
  SearchResult(
    best_move: Option(Move),
    evaluation: Int,
    nodes: Int,
    time_ms: Int,
  )
}

pub fn opposite_color(color: Color) -> Color {
  case color {
    White -> Black
    Black -> White
  }
}

pub fn piece_value(piece_type: PieceType) -> Int {
  case piece_type {
    Pawn -> 100
    Knight -> 320
    Bishop -> 330
    Rook -> 500
    Queen -> 900
    King -> 20000
  }
}

pub fn piece_to_char(piece: Piece) -> String {
  let char = case piece.piece_type {
    King -> "K"
    Queen -> "Q"
    Rook -> "R"
    Bishop -> "B"
    Knight -> "N"
    Pawn -> "P"
  }
  case piece.color {
    White -> char
    Black -> string.lowercase(char)
  }
}

pub fn char_to_piece(char: String) -> Option(Piece) {
  let upper_char = string.uppercase(char)
  let piece_type = case upper_char {
    "K" -> Ok(King)
    "Q" -> Ok(Queen)
    "R" -> Ok(Rook)
    "B" -> Ok(Bishop)
    "N" -> Ok(Knight)
    "P" -> Ok(Pawn)
    _ -> Error(Nil)
  }

  case piece_type {
    Ok(pt) -> {
      let color = case char == upper_char {
        True -> White
        False -> Black
      }
      Some(Piece(pt, color))
    }
    Error(_) -> None
  }
}

pub fn square_to_algebraic(square: Square) -> String {
  let file = square % 8
  let rank = square / 8
  let file_char = case file {
    0 -> "a"
    1 -> "b"
    2 -> "c"
    3 -> "d"
    4 -> "e"
    5 -> "f"
    6 -> "g"
    7 -> "h"
    _ -> ""
  }
  let rank_char = int.to_string(rank + 1)
  file_char <> rank_char
}

pub fn algebraic_to_square(algebraic: String) -> Result(Square, Nil) {
  case string.length(algebraic) {
    2 -> {
      let chars = string.to_graphemes(algebraic)
      case chars {
        [file_char, rank_char] -> {
          let file = case file_char {
            "a" -> Ok(0)
            "b" -> Ok(1)
            "c" -> Ok(2)
            "d" -> Ok(3)
            "e" -> Ok(4)
            "f" -> Ok(5)
            "g" -> Ok(6)
            "h" -> Ok(7)
            _ -> Error(Nil)
          }
          let rank = case int.parse(rank_char) {
            Ok(r) -> {
              case r >= 1 && r <= 8 {
                True -> Ok(r - 1)
                False -> Error(Nil)
              }
            }
            _ -> Error(Nil)
          }
          case file, rank {
            Ok(f), Ok(r) -> Ok(r * 8 + f)
            _, _ -> Error(Nil)
          }
        }
        _ -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

pub fn new_castling_rights() -> CastlingRights {
  CastlingRights(True, True, True, True)
}

pub fn no_castling_rights() -> CastlingRights {
  CastlingRights(False, False, False, False)
}
