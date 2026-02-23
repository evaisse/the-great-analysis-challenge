// FEN parsing and export functionality

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/int
import gleam/result
import types.{
  type Color, type GameState, type CastlingRights, White, Black,
  CastlingRights, GameState, char_to_piece, piece_to_char,
  algebraic_to_square, square_to_algebraic, no_castling_rights,
}
import board.{get_piece}

pub fn parse_fen(fen: String) -> Result(GameState, String) {
  let parts = string.split(fen, " ")
  case parts {
    [pieces, turn, castling, en_passant, halfmove, fullmove] ->
      parse_fen_parts(pieces, turn, castling, en_passant, halfmove, fullmove)
    [pieces, turn, castling, en_passant] ->
      parse_fen_parts(pieces, turn, castling, en_passant, "0", "1")
    _ -> Error("ERROR: Invalid FEN string")
  }
}

fn parse_fen_parts(
  pieces: String,
  turn: String,
  castling: String,
  en_passant: String,
  halfmove: String,
  fullmove: String,
) -> Result(GameState, String) {
  use board <- result.try(parse_pieces(pieces))
  use color <- result.try(parse_turn(turn))
  use rights <- result.try(parse_castling_rights(castling))
  use en_passant_target <- result.try(parse_en_passant(en_passant))
  use halfmove_clock <- result.try(parse_int_field(halfmove))
  use fullmove_number <- result.try(parse_int_field(fullmove))

  Ok(GameState(
    board: board,
    turn: color,
    castling_rights: rights,
    en_passant_target: en_passant_target,
    halfmove_clock: halfmove_clock,
    fullmove_number: fullmove_number,
    move_history: [],
  ))
}

fn parse_pieces(
  pieces: String,
) -> Result(List(Option(types.Piece)), String) {
  let ranks = string.split(pieces, "/")
  case list.length(ranks) {
    8 -> {
      ranks
      |> list.reverse
      |> list.try_map(parse_rank)
      |> result.map(list.flatten)
      |> result.map_error(fn(_) { "ERROR: Invalid FEN string" })
    }
    _ -> Error("ERROR: Invalid FEN string")
  }
}

fn parse_rank(rank: String) -> Result(List(Option(types.Piece)), Nil) {
  rank
  |> string.to_graphemes
  |> list.try_fold([], fn(acc, char) {
    case int.parse(char) {
      Ok(num) -> {
        case num >= 1 && num <= 8 {
          True -> {
            let empty_squares = list.repeat(None, num)
            Ok(list.concat([acc, empty_squares]))
          }
          False -> Error(Nil)
        }
      }
      Error(_) -> {
        case char_to_piece(char) {
          Some(piece) -> Ok(list.concat([acc, [Some(piece)]]))
          None -> Error(Nil)
        }
      }
    }
  })
}

fn parse_turn(turn: String) -> Result(Color, String) {
  case turn {
    "w" -> Ok(White)
    "b" -> Ok(Black)
    _ -> Error("ERROR: Invalid FEN string")
  }
}

fn parse_castling_rights(castling: String) -> Result(CastlingRights, String) {
  case castling {
    "-" -> Ok(no_castling_rights())
    _ -> {
      let white_kingside = string.contains(castling, "K")
      let white_queenside = string.contains(castling, "Q")
      let black_kingside = string.contains(castling, "k")
      let black_queenside = string.contains(castling, "q")

      Ok(CastlingRights(
        white_kingside: white_kingside,
        white_queenside: white_queenside,
        black_kingside: black_kingside,
        black_queenside: black_queenside,
      ))
    }
  }
}

fn parse_en_passant(en_passant: String) -> Result(Option(Int), String) {
  case en_passant {
    "-" -> Ok(None)
    _ -> {
      algebraic_to_square(en_passant)
      |> result.map(Some)
      |> result.map_error(fn(_) { "ERROR: Invalid FEN string" })
    }
  }
}

fn parse_int_field(str: String) -> Result(Int, String) {
  int.parse(str)
  |> result.map_error(fn(_) { "ERROR: Invalid FEN string" })
}

pub fn export_fen(game_state: GameState) -> String {
  let pieces = export_pieces(game_state)
  let turn = case game_state.turn {
    White -> "w"
    Black -> "b"
  }
  let castling = export_castling_rights(game_state.castling_rights)
  let en_passant = export_en_passant(game_state.en_passant_target)
  let halfmove = int.to_string(game_state.halfmove_clock)
  let fullmove = int.to_string(game_state.fullmove_number)

  pieces
  <> " "
  <> turn
  <> " "
  <> castling
  <> " "
  <> en_passant
  <> " "
  <> halfmove
  <> " "
  <> fullmove
}

fn export_pieces(game_state: GameState) -> String {
  list.range(7, 0)
  |> list.map(fn(rank) {
    list.range(0, 7)
    |> list.map(fn(file) {
      let square = rank * 8 + file
      get_piece(game_state, square)
    })
    |> export_rank
  })
  |> string.join("/")
}

fn export_rank(rank_pieces: List(Option(types.Piece))) -> String {
  let #(result, empty_count) =
    list.fold(rank_pieces, #("", 0), fn(acc, piece) {
      let #(str, count) = acc
      case piece {
        None -> #(str, count + 1)
        Some(p) -> {
          let prefix = case count > 0 {
            True -> str <> int.to_string(count)
            False -> str
          }
          #(prefix <> piece_to_char(p), 0)
        }
      }
    })
  case empty_count > 0 {
    True -> result <> int.to_string(empty_count)
    False -> result
  }
}

fn export_castling_rights(rights: CastlingRights) -> String {
  let castling_chars = []
  let castling_chars = case rights.white_kingside {
    True -> ["K", ..castling_chars]
    False -> castling_chars
  }
  let castling_chars = case rights.white_queenside {
    True -> ["Q", ..castling_chars]
    False -> castling_chars
  }
  let castling_chars = case rights.black_kingside {
    True -> ["k", ..castling_chars]
    False -> castling_chars
  }
  let castling_chars = case rights.black_queenside {
    True -> ["q", ..castling_chars]
    False -> castling_chars
  }

  case castling_chars {
    [] -> "-"
    _ -> castling_chars |> list.reverse |> string.join("")
  }
}

fn export_en_passant(en_passant_target: Option(Int)) -> String {
  case en_passant_target {
    None -> "-"
    Some(square) -> square_to_algebraic(square)
  }
}
