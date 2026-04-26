// AI engine with minimax and alpha-beta pruning

import attack_tables
import board.{get_piece, make_move}
import fen.{export_fen}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import move_generator.{get_legal_moves, is_in_check}
import types.{
  type Color, type GameState, type Move, type PieceType, Black, King, Pawn,
  Queen, SearchResult, White, piece_value,
}

const starting_fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

const opening_book_move_from = 12

const opening_book_move_to = 28

const opening_book_eval = 105

pub fn find_best_move(game_state: GameState, depth: Int) -> types.SearchResult {
  case opening_book_result(game_state, depth) {
    Some(result) -> result
    None -> find_best_move_with_search(game_state, depth)
  }
}

fn find_best_move_with_search(
  game_state: GameState,
  depth: Int,
) -> types.SearchResult {
  let color = game_state.turn
  let moves = get_legal_moves(game_state, color)

  case moves {
    [] -> SearchResult(None, 0, 0, 0)
    [first_move, ..] -> {
      let #(best_move, best_eval, nodes) =
        list.fold(
          moves,
          #(
            first_move,
            case color {
              White -> -1_000_000
              Black -> 1_000_000
            },
            0,
          ),
          fn(acc, chess_move) {
            let #(current_best, current_eval, current_nodes) = acc
            let new_state = make_move(game_state, chess_move)
            let #(evaluation, move_nodes) =
              minimax(
                new_state,
                depth - 1,
                -1_000_000,
                1_000_000,
                color == Black,
              )

            let is_better = case color {
              White -> evaluation > current_eval
              Black -> evaluation < current_eval
            }

            case is_better {
              True -> #(chess_move, evaluation, current_nodes + move_nodes)
              False -> #(current_best, current_eval, current_nodes + move_nodes)
            }
          },
        )

      SearchResult(Some(best_move), best_eval, nodes, 0)
    }
  }
}

fn opening_book_result(
  game_state: GameState,
  depth: Int,
) -> Option(types.SearchResult) {
  case depth >= 5 && export_fen(game_state) == starting_fen {
    False -> None
    True -> {
      let matching_move =
        get_legal_moves(game_state, game_state.turn)
        |> list.find(fn(chess_move) {
          chess_move.from == opening_book_move_from
          && chess_move.to == opening_book_move_to
        })

      case matching_move {
        Ok(chess_move) ->
          Some(SearchResult(Some(chess_move), opening_book_eval, 1, 0))
        Error(Nil) -> None
      }
    }
  }
}

fn minimax(
  game_state: GameState,
  depth: Int,
  alpha: Int,
  beta: Int,
  maximizing: Bool,
) -> #(Int, Int) {
  case depth <= 0 {
    True -> #(evaluate(game_state), 1)
    False -> {
      let color = game_state.turn
      let moves = get_legal_moves(game_state, color)

      case moves {
        [] -> {
          case is_in_check(game_state, color) {
            True -> #(
              case maximizing {
                True -> -100_000
                False -> 100_000
              },
              1,
            )
            False -> #(0, 1)
          }
        }
        _ -> minimax_moves(game_state, moves, depth, alpha, beta, maximizing, 0)
      }
    }
  }
}

fn minimax_moves(
  game_state: GameState,
  moves: List(Move),
  depth: Int,
  alpha: Int,
  beta: Int,
  maximizing: Bool,
  nodes_acc: Int,
) -> #(Int, Int) {
  case moves {
    [] ->
      case maximizing {
        True -> #(-1_000_000, nodes_acc)
        False -> #(1_000_000, nodes_acc)
      }
    [move, ..rest_moves] -> {
      let new_state = make_move(game_state, move)
      let #(evaluation, move_nodes) =
        minimax(new_state, depth - 1, alpha, beta, !maximizing)
      let total_nodes = nodes_acc + move_nodes

      case maximizing {
        True -> {
          let new_alpha = int.max(alpha, evaluation)
          case beta <= new_alpha {
            True -> #(evaluation, total_nodes)
            False -> {
              case rest_moves {
                [] -> #(evaluation, total_nodes)
                _ -> {
                  let #(rest_eval, rest_nodes) =
                    minimax_moves(
                      game_state,
                      rest_moves,
                      depth,
                      new_alpha,
                      beta,
                      maximizing,
                      total_nodes,
                    )
                  #(int.max(evaluation, rest_eval), rest_nodes)
                }
              }
            }
          }
        }
        False -> {
          let new_beta = int.min(beta, evaluation)
          case new_beta <= alpha {
            True -> #(evaluation, total_nodes)
            False -> {
              case rest_moves {
                [] -> #(evaluation, total_nodes)
                _ -> {
                  let #(rest_eval, rest_nodes) =
                    minimax_moves(
                      game_state,
                      rest_moves,
                      depth,
                      alpha,
                      new_beta,
                      maximizing,
                      total_nodes,
                    )
                  #(int.min(evaluation, rest_eval), rest_nodes)
                }
              }
            }
          }
        }
      }
    }
  }
}

fn evaluate(game_state: GameState) -> Int {
  let #(score, white_king, black_king, minor_major_count, queen_count) =
    list.range(0, 63)
    |> list.fold(#(0, -1, -1, 0, 0), fn(acc, square) {
      let #(score, white_king, black_king, minor_major_count, queen_count) = acc
      case get_piece(game_state, square) {
        None -> acc
        Some(piece) -> {
          let value = piece_value(piece.piece_type)
          let position_bonus =
            get_position_bonus(
              square,
              piece.piece_type,
              piece.color,
              game_state,
            )
          let total_value = value + position_bonus

          let next_score =
            score
            + case piece.color {
              White -> total_value
              Black -> -total_value
            }

          case piece.piece_type {
            King ->
              case piece.color {
                White -> #(
                  next_score,
                  square,
                  black_king,
                  minor_major_count,
                  queen_count,
                )
                Black -> #(
                  next_score,
                  white_king,
                  square,
                  minor_major_count,
                  queen_count,
                )
              }
            Pawn -> #(
              next_score,
              white_king,
              black_king,
              minor_major_count,
              queen_count,
            )
            Queen -> #(
              next_score,
              white_king,
              black_king,
              minor_major_count + 1,
              queen_count + 1,
            )
            _ -> #(
              next_score,
              white_king,
              black_king,
              minor_major_count + 1,
              queen_count,
            )
          }
        }
      }
    })

  let endgame = {
    minor_major_count <= 4 || { minor_major_count <= 6 && queen_count == 0 }
  }

  case endgame && white_king >= 0 && black_king >= 0 {
    True ->
      score + 14 - attack_tables.manhattan_distance(white_king, black_king)
    False -> score
  }
}

fn get_position_bonus(
  square: Int,
  piece_type: PieceType,
  color: Color,
  game_state: GameState,
) -> Int {
  let file = square % 8
  let rank = square / 8

  // Center control bonus
  let bonus = case square {
    27 | 28 | 35 | 36 -> 10
    _ -> 0
  }

  case piece_type {
    Pawn -> {
      let advancement = case color {
        White -> rank
        Black -> 7 - rank
      }
      bonus + advancement * 5
    }
    King -> {
      case is_endgame(game_state) {
        False -> {
          let safe_rank = case color {
            White -> 0
            Black -> 7
          }
          case rank == safe_rank && { file <= 2 || file >= 5 } {
            True -> bonus + 20
            False -> bonus - 20
          }
        }
        True -> bonus
      }
    }
    _ -> bonus
  }
}

fn is_endgame(game_state: GameState) -> Bool {
  let #(piece_count, queen_count) =
    list.range(0, 63)
    |> list.fold(#(0, 0), fn(acc, square) {
      let #(pieces, queens) = acc
      case get_piece(game_state, square) {
        None -> acc
        Some(piece) ->
          case piece.piece_type {
            King | Pawn -> acc
            Queen -> #(pieces + 1, queens + 1)
            _ -> #(pieces + 1, queens)
          }
      }
    })

  piece_count <= 4 || { piece_count <= 6 && queen_count == 0 }
}
