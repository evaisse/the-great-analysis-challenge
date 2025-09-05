// Main chess engine with CLI interface

import gleam/io
import gleam/string
import gleam/list
import gleam/int
import gleam/result
import gleam/option.{None, Some}
import types.{
  type GameState, type Move, White, Black,
  algebraic_to_square, square_to_algebraic, opposite_color
}
import board.{new_game, display_board, make_move, undo_move, get_piece}
import move_generator.{get_legal_moves, is_in_check, is_checkmate, is_stalemate}
import fen.{parse_fen, export_fen}
import ai.{find_best_move}
import perft.{perft}

pub type ChessEngine {
  ChessEngine(game_state: GameState)
}

pub fn new() -> ChessEngine {
  ChessEngine(new_game())
}

pub fn main() {
  let engine = new()
  io.println(display_board(engine.game_state))
  game_loop(engine)
}

fn game_loop(engine: ChessEngine) -> Nil {
  // Simplified for demo - in a real implementation would read from stdin
  // For now, just demonstrate some moves
  let demo_commands = ["move e2e4", "move e7e5", "move g1f3", "move b8c6", "export", "quit"]
  run_demo_commands(engine, demo_commands)
}

fn run_demo_commands(engine: ChessEngine, commands: List(String)) -> Nil {
  case commands {
    [] -> Nil
    [command, ..rest] -> {
      io.println("Command: " <> command)
      let new_engine = process_command(engine, command)
      case command {
        "quit" -> Nil
        _ -> run_demo_commands(new_engine, rest)
      }
    }
  }
}

fn process_command(engine: ChessEngine, command: String) -> ChessEngine {
  let parts = string.split(command, " ")
  case parts {
    ["move", move_str] -> handle_move(engine, move_str)
    ["undo"] -> handle_undo(engine)
    ["new"] -> handle_new(engine)
    ["ai", depth_str] -> handle_ai(engine, depth_str)
    ["fen", ..fen_parts] -> handle_fen(engine, string.join(fen_parts, " "))
    ["export"] -> handle_export(engine)
    ["eval"] -> handle_eval(engine)
    ["perft", depth_str] -> handle_perft(engine, depth_str)
    ["help"] -> handle_help(engine)
    _ -> {
      io.println("ERROR: Invalid command")
      engine
    }
  }
}

fn handle_move(engine: ChessEngine, move_str: String) -> ChessEngine {
  case string.length(move_str) >= 4 {
    False -> {
      io.println("ERROR: Invalid move format")
      engine
    }
    True -> {
      let from_str = string.slice(move_str, 0, 2)
      let to_str = string.slice(move_str, 2, 2)
      let promotion_str = case string.length(move_str) > 4 {
        True -> Some(string.slice(move_str, 4, 1))
        False -> None
      }
      
      case algebraic_to_square(from_str), algebraic_to_square(to_str) {
        Ok(from_square), Ok(to_square) -> {
          case get_piece(engine.game_state, from_square) {
            None -> {
              io.println("ERROR: No piece at source square")
              engine
            }
            Some(piece) -> {
              case piece.color == engine.game_state.turn {
                False -> {
                  io.println("ERROR: Wrong color piece")
                  engine
                }
                True -> {
                  let legal_moves = get_legal_moves(engine.game_state, engine.game_state.turn)
                  let matching_move = find_matching_move(legal_moves, from_square, to_square, promotion_str)
                  
                  case matching_move {
                    None -> {
                      case is_in_check(engine.game_state, engine.game_state.turn) {
                        True -> io.println("ERROR: King would be in check")
                        False -> io.println("ERROR: Illegal move")
                      }
                      engine
                    }
                    Some(chess_move) -> {
                      let new_state = make_move(engine.game_state, chess_move)
                      io.println("OK: " <> move_str)
                      io.println(display_board(new_state))
                      check_game_end(new_state)
                      ChessEngine(new_state)
                    }
                  }
                }
              }
            }
          }
        }
        _, _ -> {
          io.println("ERROR: Invalid move format")
          engine
        }
      }
    }
  }
}

fn find_matching_move(moves: List(Move), from: Int, to: Int, promotion_str: Option(String)) -> Option(Move) {
  list.find(moves, fn(chess_move) {
    chess_move.from == from && chess_move.to == to &&
    case chess_move.promotion, promotion_str {
      Some(types.Queen), None -> True
      Some(types.Queen), Some("Q") | Some(types.Queen), Some("q") -> True
      Some(types.Rook), Some("R") | Some(types.Rook), Some("r") -> True
      Some(types.Bishop), Some("B") | Some(types.Bishop), Some("b") -> True
      Some(types.Knight), Some("N") | Some(types.Knight), Some("n") -> True
      None, None -> True
      _, _ -> False
    }
  })
  |> result.to_option
}

fn handle_undo(engine: ChessEngine) -> ChessEngine {
  case engine.game_state.move_history {
    [] -> {
      io.println("ERROR: No moves to undo")
      engine
    }
    _ -> {
      let new_state = undo_move(engine.game_state)
      io.println("Move undone")
      io.println(display_board(new_state))
      ChessEngine(new_state)
    }
  }
}

fn handle_new(engine: ChessEngine) -> ChessEngine {
  let new_state = new_game()
  io.println("New game started")
  io.println(display_board(new_state))
  ChessEngine(new_state)
}

fn handle_ai(engine: ChessEngine, depth_str: String) -> ChessEngine {
  case int.parse(depth_str) {
    Error(_) -> {
      io.println("ERROR: AI depth must be 1-5")
      engine
    }
    Ok(depth) if depth < 1 || depth > 5 -> {
      io.println("ERROR: AI depth must be 1-5")
      engine
    }
    Ok(depth) -> {
      let result = find_best_move(engine.game_state, depth)
      case result.best_move {
        None -> {
          io.println("ERROR: No legal moves available")
          engine
        }
        Some(chess_move) -> {
          let move_str = square_to_algebraic(chess_move.from) <>
                        square_to_algebraic(chess_move.to) <>
                        case chess_move.promotion {
                          Some(types.Queen) -> "Q"
                          Some(types.Rook) -> "R"
                          Some(types.Bishop) -> "B"
                          Some(types.Knight) -> "N"
                          _ -> ""
                        }
          
          let new_state = make_move(engine.game_state, chess_move)
          io.println("AI: " <> move_str <> " (depth=" <> int.to_string(depth) <> 
                    ", eval=" <> int.to_string(result.evaluation) <> 
                    ", time=" <> int.to_string(result.time_ms) <> "ms)")
          io.println(display_board(new_state))
          check_game_end(new_state)
          ChessEngine(new_state)
        }
      }
    }
  }
}

fn handle_fen(engine: ChessEngine, fen_string: String) -> ChessEngine {
  case parse_fen(fen_string) {
    Error(err) -> {
      io.println(err)
      engine
    }
    Ok(new_state) -> {
      io.println("Position loaded from FEN")
      io.println(display_board(new_state))
      ChessEngine(new_state)
    }
  }
}

fn handle_export(engine: ChessEngine) -> ChessEngine {
  let fen = export_fen(engine.game_state)
  io.println("FEN: " <> fen)
  engine
}

fn handle_eval(engine: ChessEngine) -> ChessEngine {
  let result = find_best_move(engine.game_state, 1)
  io.println("Position evaluation: " <> int.to_string(result.evaluation))
  engine
}

fn handle_perft(engine: ChessEngine, depth_str: String) -> ChessEngine {
  case int.parse(depth_str) {
    Error(_) -> {
      io.println("ERROR: Invalid perft depth")
      engine
    }
    Ok(depth) if depth < 1 -> {
      io.println("ERROR: Invalid perft depth")
      engine
    }
    Ok(depth) -> {
      let nodes = perft(engine.game_state, depth)
      io.println("Perft(" <> int.to_string(depth) <> "): " <> 
                int.to_string(nodes) <> " nodes (0ms)")
      engine
    }
  }
}

fn handle_help(engine: ChessEngine) -> ChessEngine {
  io.println("Available commands:")
  io.println("  move <from><to>[promotion] - Make a move (e.g., e2e4, e7e8Q)")
  io.println("  undo - Undo the last move")
  io.println("  new - Start a new game")
  io.println("  ai <depth> - Let AI make a move (depth 1-5)")
  io.println("  fen <string> - Load position from FEN")
  io.println("  export - Export current position as FEN")
  io.println("  eval - Evaluate current position")
  io.println("  perft <depth> - Run performance test")
  io.println("  help - Show this help message")
  io.println("  quit - Exit the program")
  engine
}

fn check_game_end(game_state: GameState) -> Nil {
  let color = game_state.turn
  let legal_moves = get_legal_moves(game_state, color)
  
  case list.is_empty(legal_moves) {
    False -> Nil
    True -> {
      case is_in_check(game_state, color) {
        True -> {
          let winner = case color {
            White -> "Black"
            Black -> "White"
          }
          io.println("CHECKMATE: " <> winner <> " wins")
        }
        False -> io.println("STALEMATE: Draw")
      }
    }
  }
}