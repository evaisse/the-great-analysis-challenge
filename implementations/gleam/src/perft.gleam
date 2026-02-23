// Performance testing utilities

import gleam/list
import gleam/option.{Some}
import types.{type GameState}
import board.{make_move}
import move_generator.{get_legal_moves}

pub fn perft(game_state: GameState, depth: Int) -> Int {
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
