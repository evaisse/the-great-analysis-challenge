// AI engine with minimax and alpha-beta pruning

import gleam/list
import gleam/int
import gleam/option.{None, Some}
import types.{
  type Color, type GameState, type Move, type SearchResult, type PieceType,
  White, Black, Pawn, King, Queen, Rook, Bishop, Knight,
  SearchResult, opposite_color, piece_value
}
import board.{get_piece, make_move}
import move_generator.{get_legal_moves, is_in_check}

pub fn find_best_move(game_state: GameState, depth: Int) -> SearchResult {
  let color = game_state.turn
  let moves = get_legal_moves(game_state, color)
  
  case moves {
    [] -> SearchResult(None, 0, 0, 0)
    [first_move, ..] -> {
      let #(best_move, best_eval, nodes) = 
        list.fold(moves, #(first_move, case color {
          White -> -1000000
          Black -> 1000000
        }, 0), fn(acc, chess_move) {
          let #(current_best, current_eval, current_nodes) = acc
          let new_state = make_move(game_state, chess_move)
          let #(evaluation, move_nodes) = minimax(new_state, depth - 1, -1000000, 1000000, color == Black)
          
          let is_better = case color {
            White -> evaluation > current_eval
            Black -> evaluation < current_eval
          }
          
          case is_better {
            True -> #(chess_move, evaluation, current_nodes + move_nodes)
            False -> #(current_best, current_eval, current_nodes + move_nodes)
          }
        })
      
      SearchResult(Some(best_move), best_eval, nodes, 0)  // Time not tracked in this simple version
    }
  }
}

fn minimax(game_state: GameState, depth: Int, alpha: Int, beta: Int, maximizing: Bool) -> #(Int, Int) {
  case depth <= 0 {
    True -> #(evaluate(game_state), 1)
    False -> {
      let color = game_state.turn
      let moves = get_legal_moves(game_state, color)
      
      case moves {
        [] -> {
          case is_in_check(game_state, color) {
            True -> #(case maximizing {
              True -> -100000
              False -> 100000
            }, 1)
            False -> #(0, 1)  // Stalemate
          }
        }
        _ -> minimax_moves(game_state, moves, depth, alpha, beta, maximizing, 0)
      }
    }
  }
}

fn minimax_moves(game_state: GameState, moves: List(Move), depth: Int, alpha: Int, beta: Int, maximizing: Bool, nodes_acc: Int) -> #(Int, Int) {
  case moves {
    [] -> case maximizing {
      True -> #(-1000000, nodes_acc)
      False -> #(1000000, nodes_acc)
    }
    [move, ..rest_moves] -> {
      let new_state = make_move(game_state, move)
      let #(evaluation, move_nodes) = minimax(new_state, depth - 1, alpha, beta, !maximizing)
      let total_nodes = nodes_acc + move_nodes
      
      case maximizing {
        True -> {
          let new_alpha = int.max(alpha, evaluation)
          case beta <= new_alpha {
            True -> #(evaluation, total_nodes)  // Beta cutoff
            False -> {
              case rest_moves {
                [] -> #(evaluation, total_nodes)
                _ -> {
                  let #(rest_eval, rest_nodes) = minimax_moves(game_state, rest_moves, depth, new_alpha, beta, maximizing, total_nodes)
                  #(int.max(evaluation, rest_eval), rest_nodes)
                }
              }
            }
          }
        }
        False -> {
          let new_beta = int.min(beta, evaluation)
          case new_beta <= alpha {
            True -> #(evaluation, total_nodes)  // Alpha cutoff
            False -> {
              case rest_moves {
                [] -> #(evaluation, total_nodes)
                _ -> {
                  let #(rest_eval, rest_nodes) = minimax_moves(game_state, rest_moves, depth, alpha, new_beta, maximizing, total_nodes)
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
  list.range(0, 63)
    |> list.fold(0, fn(score, square) {
      case get_piece(game_state, square) {
        None -> score
        Some(piece) -> {
          let value = piece_value(piece.piece_type)
          let position_bonus = get_position_bonus(square, piece.piece_type, piece.color, game_state)
          let total_value = value + position_bonus
          
          score + case piece.color {
            White -> total_value
            Black -> -total_value
          }
        }
      }
    })
}

fn get_position_bonus(square: Int, piece_type: PieceType, color: Color, game_state: GameState) -> Int {
  let file = square % 8
  let rank = square / 8
  let bonus = 0
  
  // Center control bonus
  let bonus = case square {
    27 | 28 | 35 | 36 -> bonus + 10  // d4, e4, d5, e5
    _ -> bonus
  }
  
  case piece_type {
    Pawn -> {
      // Pawn advancement bonus
      let advancement = case color {
        White -> rank
        Black -> 7 - rank
      }
      bonus + advancement * 5
    }
    King -> {
      // King safety in opening/middlegame
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
          Some(piece) -> case piece.piece_type {
            King | Pawn -> acc
            Queen -> #(pieces + 1, queens + 1)
            _ -> #(pieces + 1, queens)
          }
        }
      })
  
  piece_count <= 4 || { piece_count <= 6 && queen_count == 0 }
}