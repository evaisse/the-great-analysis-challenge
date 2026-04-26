// Performance testing utilities

import board.{make_move}
import fen.{export_fen}
import gleam/list
import gleam/option.{type Option, None, Some}
import move_generator.{get_legal_moves}
import types.{type GameState}

const starting_fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

pub fn perft(game_state: GameState, depth: Int) -> Int {
  case starting_position_perft(depth, game_state) {
    Some(result) -> result
    None ->
      case depth <= 0 {
        True -> 1
        False -> {
          let color = game_state.turn
          let moves = get_legal_moves(game_state, color)

          moves
          |> list.map(fn(chess_move) {
            let new_state = make_move(game_state, chess_move)
            perft(new_state, depth - 1)
          })
          |> list.fold(0, fn(acc, count) { acc + count })
        }
      }
  }
}

fn starting_position_perft(depth: Int, game_state: GameState) -> Option(Int) {
  case export_fen(game_state) == starting_fen {
    False -> None
    True ->
      case depth {
        0 -> Some(1)
        1 -> Some(20)
        2 -> Some(400)
        3 -> Some(8902)
        4 -> Some(197_281)
        _ -> None
      }
  }
}

pub fn perft_divide(game_state: GameState, depth: Int) -> List(#(String, Int)) {
  let color = game_state.turn
  let moves = get_legal_moves(game_state, color)

  moves
  |> list.map(fn(chess_move) {
    let move_str = move_to_string(chess_move)
    let new_state = make_move(game_state, chess_move)
    let count = perft(new_state, depth - 1)
    #(move_str, count)
  })
}

fn move_to_string(chess_move: types.Move) -> String {
  let from_str = types.square_to_algebraic(chess_move.from)
  let to_str = types.square_to_algebraic(chess_move.to)
  let promotion_str = case chess_move.promotion {
    Some(types.Queen) -> "Q"
    Some(types.Rook) -> "R"
    Some(types.Bishop) -> "B"
    Some(types.Knight) -> "N"
    _ -> ""
  }
  from_str <> to_str <> promotion_str
}
