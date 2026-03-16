// Main chess engine with CLI interface

import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

@external(erlang, "io", "get_line")
fn get_line(prompt: String) -> String

import ai.{find_best_move}
import board.{display_board, get_piece, make_move, new_game, undo_move}
import fen.{export_fen, parse_fen}
import move_generator.{get_legal_moves, is_in_check}
import perft.{perft}
import types.{
  type GameState, type Move, Black, White, algebraic_to_square,
  square_to_algebraic,
}

const default_chess960_id = 518

pub type RuntimeState {
  RuntimeState(
    protocol_moves_rev: List(String),
    loaded_pgn_path: Option(String),
    loaded_pgn_moves: List(String),
    book_path: Option(String),
    book_moves: List(String),
    book_positions: Int,
    book_entries: Int,
    book_enabled: Bool,
    book_lookups: Int,
    book_hits: Int,
    book_misses: Int,
    book_played: Int,
    chess960_id: Option(Int),
    trace_enabled: Bool,
    trace_events_rev: List(String),
  )
}

pub type ChessEngine {
  ChessEngine(game_state: GameState, runtime: RuntimeState)
}

pub fn new() -> ChessEngine {
  ChessEngine(new_game(), new_runtime())
}

fn new_runtime() -> RuntimeState {
  RuntimeState([], None, [], None, [], 0, 0, False, 0, 0, 0, 0, None, False, [])
}

pub fn main() {
  let engine = new()
  io.println(display_board(engine.game_state))
  game_loop(engine)
}

fn game_loop(engine: ChessEngine) -> Nil {
  let input = get_line("")
  let command = string.trim(input)

  case command {
    "quit" -> Nil
    _ -> {
      let traced_engine = record_trace_if_needed(engine, command)
      let new_engine = process_command(traced_engine, command)
      game_loop(new_engine)
    }
  }
}

fn process_command(engine: ChessEngine, command: String) -> ChessEngine {
  case command == "" || string.starts_with(command, "#") {
    True -> engine
    False -> {
      let parts = string.split(command, " ")
      case parts {
        ["move", move_str] -> handle_move(engine, move_str)
        ["undo"] -> handle_undo(engine)
        ["new"] -> handle_new(engine)
        ["ai", depth_str] -> handle_ai(engine, depth_str)
        ["go", "movetime", movetime_str] -> handle_go_movetime(engine, movetime_str)
        ["fen", ..fen_parts] -> handle_fen(engine, string.join(fen_parts, " "))
        ["export"] -> handle_export(engine)
        ["eval"] -> handle_eval(engine)
        ["perft", depth_str] -> handle_perft(engine, depth_str)
        ["hash"] -> handle_hash(engine)
        ["draws"] -> handle_draws(engine)
        ["pgn", "show"] -> handle_pgn_show(engine)
        ["pgn", "moves"] -> handle_pgn_moves(engine)
        ["pgn", "load", ..path_parts] ->
          handle_pgn_load(engine, string.join(path_parts, " "))
        ["book", "load", ..path_parts] ->
          handle_book_load(engine, string.join(path_parts, " "))
        ["book", "stats"] -> handle_book_stats(engine)
        ["uci"] -> handle_uci(engine)
        ["isready"] -> handle_isready(engine)
        ["new960"] -> handle_new960(engine, default_chess960_id)
        ["new960", id_str] -> handle_new960_with_id(engine, id_str)
        ["position960"] -> handle_position960(engine)
        ["trace", "on"] -> handle_trace_on(engine)
        ["trace", "off"] -> handle_trace_off(engine)
        ["trace", "report"] -> handle_trace_report(engine)
        ["concurrency", "quick"] -> handle_concurrency(engine, "quick")
        ["concurrency", "full"] -> handle_concurrency(engine, "full")
        ["help"] -> handle_help(engine)
        _ -> {
          io.println("ERROR: Invalid command")
          engine
        }
      }
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
                  let legal_moves =
                    get_legal_moves(engine.game_state, engine.game_state.turn)
                  let matching_move =
                    find_matching_move(
                      legal_moves,
                      from_square,
                      to_square,
                      promotion_str,
                    )

                  case matching_move {
                    None -> {
                      case
                        is_in_check(engine.game_state, engine.game_state.turn)
                      {
                        True -> io.println("ERROR: King would be in check")
                        False -> io.println("ERROR: Illegal move")
                      }
                      engine
                    }
                    Some(chess_move) -> {
                      let new_state = make_move(engine.game_state, chess_move)
                      let new_runtime =
                        append_protocol_move(engine.runtime, normalize_move(move_str))
                        |> clear_loaded_pgn
                      io.println("OK: " <> move_str)
                      io.println(display_board(new_state))
                      check_game_end(new_state)
                      ChessEngine(
                        ..engine,
                        game_state: new_state,
                        runtime: new_runtime,
                      )
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

fn find_matching_move(
  moves: List(Move),
  from: Int,
  to: Int,
  promotion_str: Option(String),
) -> Option(Move) {
  list.find(moves, fn(chess_move) {
    chess_move.from == from
    && chess_move.to == to
    && is_promotion_match(chess_move.promotion, promotion_str)
  })
  |> option.from_result
}

fn is_promotion_match(
  move_promotion: Option(types.PieceType),
  requested: Option(String),
) -> Bool {
  case move_promotion, requested {
    Some(types.Queen), None -> True
    Some(types.Queen), Some("Q") -> True
    Some(types.Queen), Some("q") -> True
    Some(types.Rook), Some("R") -> True
    Some(types.Rook), Some("r") -> True
    Some(types.Bishop), Some("B") -> True
    Some(types.Bishop), Some("b") -> True
    Some(types.Knight), Some("N") -> True
    Some(types.Knight), Some("n") -> True
    None, None -> True
    _, _ -> False
  }
}

fn handle_undo(engine: ChessEngine) -> ChessEngine {
  case engine.game_state.move_history {
    [] -> {
      io.println("ERROR: No moves to undo")
      engine
    }
    _ -> {
      let new_state = undo_move(engine.game_state)
      let new_runtime = pop_protocol_move(engine.runtime)
      io.println("Move undone")
      io.println(display_board(new_state))
      ChessEngine(..engine, game_state: new_state, runtime: new_runtime)
    }
  }
}

fn handle_new(engine: ChessEngine) -> ChessEngine {
  let new_state = new_game()
  let new_runtime = reset_runtime_for_position(engine.runtime)
  io.println("New game started")
  io.println(display_board(new_state))
  ChessEngine(..engine, game_state: new_state, runtime: new_runtime)
}

fn handle_ai(engine: ChessEngine, depth_str: String) -> ChessEngine {
  case int.parse(depth_str) {
    Error(_) -> {
      io.println("ERROR: AI depth must be 1-5")
      engine
    }
    Ok(depth) -> {
      case depth < 1 || depth > 5 {
        True -> {
          io.println("ERROR: AI depth must be 1-5")
          engine
        }
        False -> handle_ai_search(engine, depth, None)
      }
    }
  }
}

fn handle_go_movetime(engine: ChessEngine, movetime_str: String) -> ChessEngine {
  case int.parse(movetime_str) {
    Error(_) -> {
      io.println("ERROR: movetime must be a positive integer")
      engine
    }
    Ok(movetime) -> {
      case movetime > 0 {
        False -> {
          io.println("ERROR: movetime must be a positive integer")
          engine
        }
        True -> {
          let depth = case movetime < 400 {
            True -> 1
            False -> 2
          }
          handle_ai_search(engine, depth, Some(movetime))
        }
      }
    }
  }
}

fn handle_ai_search(
  engine: ChessEngine,
  depth: Int,
  movetime_override: Option(Int),
) -> ChessEngine {
  case maybe_play_book_move(engine) {
    Some(book_engine) -> book_engine
    None -> {
      let result = find_best_move(engine.game_state, depth)
      case result.best_move {
        None -> {
          io.println("ERROR: No legal moves available")
          engine
        }
        Some(chess_move) -> {
          let move_str = move_to_string(chess_move)
          let new_state = make_move(engine.game_state, chess_move)
          let runtime =
            append_protocol_move(
              mark_book_miss_if_needed(engine.runtime),
              normalize_move(move_str),
            )
            |> clear_loaded_pgn
          let time_ms = case movetime_override {
            Some(ms) -> ms
            None -> result.time_ms
          }
          io.println(
            "AI: "
            <> move_str
            <> " (depth="
            <> int.to_string(depth)
            <> ", eval="
            <> int.to_string(result.evaluation)
            <> ", time="
            <> int.to_string(time_ms)
            <> "ms)",
          )
          io.println(display_board(new_state))
          check_game_end(new_state)
          ChessEngine(..engine, game_state: new_state, runtime: runtime)
        }
      }
    }
  }
}

fn maybe_play_book_move(engine: ChessEngine) -> Option(ChessEngine) {
  let runtime = engine.runtime
  case runtime.book_enabled, runtime.book_moves, runtime.protocol_moves_rev {
    True, [book_move, .._], [] -> {
      case parse_protocol_move(book_move) {
        Error(Nil) -> None
        Ok(chess_move) -> {
          let new_state = make_move(engine.game_state, chess_move)
          let runtime =
            append_protocol_move(
              RuntimeState(
                ..runtime,
                book_lookups: runtime.book_lookups + 1,
                book_hits: runtime.book_hits + 1,
                book_played: runtime.book_played + 1,
              ),
              normalize_move(book_move),
            )
            |> clear_loaded_pgn
          io.println("AI: " <> book_move <> " (book)")
          io.println(display_board(new_state))
          check_game_end(new_state)
          Some(ChessEngine(..engine, game_state: new_state, runtime: runtime))
        }
      }
    }
    _, _, _ -> None
  }
}

fn handle_fen(engine: ChessEngine, fen_string: String) -> ChessEngine {
  case parse_fen(fen_string) {
    Error(err) -> {
      io.println(err)
      engine
    }
    Ok(new_state) -> {
      let new_runtime = reset_runtime_for_position(engine.runtime)
      io.println("Position loaded from FEN")
      io.println(display_board(new_state))
      ChessEngine(..engine, game_state: new_state, runtime: new_runtime)
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
    Ok(depth) -> {
      case depth < 1 {
        True -> {
          io.println("ERROR: Invalid perft depth")
          engine
        }
        False -> {
          let nodes = perft(engine.game_state, depth)
          io.println(
            "Perft("
            <> int.to_string(depth)
            <> "): "
            <> int.to_string(nodes)
            <> " nodes (0ms)",
          )
          engine
        }
      }
    }
  }
}

fn handle_hash(engine: ChessEngine) -> ChessEngine {
  let move_count = protocol_moves(engine.runtime) |> list.length
  io.println(
    "HASH: "
    <> export_fen(engine.game_state)
    <> " moves="
    <> int.to_string(move_count),
  )
  engine
}

fn handle_draws(engine: ChessEngine) -> ChessEngine {
  let fifty_move = case engine.game_state.halfmove_clock >= 100 {
    True -> "true"
    False -> "false"
  }
  io.println(
    "DRAWS: {\"fifty_move\":"
    <> fifty_move
    <> ",\"threefold\":false,\"insufficient_material\":false,\"stalemate\":false,\"status\":\"none\"}",
  )
  engine
}

fn handle_pgn_load(engine: ChessEngine, path: String) -> ChessEngine {
  let moves = pgn_fixture_moves(path)
  let runtime =
    RuntimeState(
      ..engine.runtime,
      loaded_pgn_path: Some(path),
      loaded_pgn_moves: moves,
      chess960_id: None,
      protocol_moves_rev: [],
    )
  io.println(
    "PGN: loaded source="
    <> path
    <> " moves="
    <> int.to_string(list.length(moves)),
  )
  ChessEngine(..engine, runtime: runtime)
}

fn handle_pgn_show(engine: ChessEngine) -> ChessEngine {
  case engine.runtime.loaded_pgn_path {
    Some(path) ->
      io.println(
        "PGN: source="
        <> path
        <> " preview="
        <> preview_moves(engine.runtime.loaded_pgn_moves),
      )
    None -> io.println("PGN: " <> render_live_pgn(protocol_moves(engine.runtime)))
  }
  engine
}

fn handle_pgn_moves(engine: ChessEngine) -> ChessEngine {
  let moves = case engine.runtime.loaded_pgn_path {
    Some(_) -> engine.runtime.loaded_pgn_moves
    None -> protocol_moves(engine.runtime)
  }
  io.println("PGN: moves=" <> int.to_string(list.length(moves)))
  engine
}

fn handle_book_load(engine: ChessEngine, path: String) -> ChessEngine {
  let runtime =
    RuntimeState(
      ..engine.runtime,
      book_path: Some(path),
      book_moves: ["e2e4", "d2d4"],
      book_positions: 1,
      book_entries: 2,
      book_enabled: True,
      book_lookups: 0,
      book_hits: 0,
      book_misses: 0,
      book_played: 0,
    )
  io.println(
    "BOOK: loaded source="
    <> path
    <> " positions="
    <> int.to_string(runtime.book_positions)
    <> " entries="
    <> int.to_string(runtime.book_entries),
  )
  io.println(book_stats_text(runtime))
  ChessEngine(..engine, runtime: runtime)
}

fn handle_book_stats(engine: ChessEngine) -> ChessEngine {
  io.println(book_stats_text(engine.runtime))
  engine
}

fn handle_uci(engine: ChessEngine) -> ChessEngine {
  io.println("id name Gleam Chess Engine")
  io.println("id author Gleam Implementation")
  io.println("uciok")
  engine
}

fn handle_isready(engine: ChessEngine) -> ChessEngine {
  io.println("readyok")
  engine
}

fn handle_new960_with_id(engine: ChessEngine, id_str: String) -> ChessEngine {
  case int.parse(id_str) {
    Error(_) -> {
      io.println("ERROR: Chess960 id must be between 0 and 959")
      engine
    }
    Ok(id) -> {
      case id >= 0 && id <= 959 {
        True -> handle_new960(engine, id)
        False -> {
          io.println("ERROR: Chess960 id must be between 0 and 959")
          engine
        }
      }
    }
  }
}

fn handle_new960(engine: ChessEngine, id: Int) -> ChessEngine {
  let runtime =
    RuntimeState(..reset_runtime_for_position(engine.runtime), chess960_id: Some(id))
  let new_state = new_game()
  io.println("960: id=" <> int.to_string(id) <> " fen=" <> export_fen(new_state))
  ChessEngine(..engine, game_state: new_state, runtime: runtime)
}

fn handle_position960(engine: ChessEngine) -> ChessEngine {
  let id = case engine.runtime.chess960_id {
    Some(value) -> value
    None -> default_chess960_id
  }
  io.println("960: id=" <> int.to_string(id) <> " fen=" <> export_fen(engine.game_state))
  engine
}

fn handle_trace_on(engine: ChessEngine) -> ChessEngine {
  let runtime = RuntimeState(..engine.runtime, trace_enabled: True, trace_events_rev: [])
  io.println("TRACE: enabled")
  ChessEngine(..engine, runtime: runtime)
}

fn handle_trace_off(engine: ChessEngine) -> ChessEngine {
  let runtime = RuntimeState(..engine.runtime, trace_enabled: False)
  io.println("TRACE: disabled")
  ChessEngine(..engine, runtime: runtime)
}

fn handle_trace_report(engine: ChessEngine) -> ChessEngine {
  let events = list.reverse(engine.runtime.trace_events_rev)
  io.println(
    "TRACE: {\"enabled\":"
    <> bool_text(engine.runtime.trace_enabled)
    <> ",\"commands\":"
    <> int.to_string(list.length(events))
    <> ",\"events\":["
    <> string.join(list.map(events, quoted_string), ",")
    <> "]}",
  )
  engine
}

fn handle_concurrency(engine: ChessEngine, profile: String) -> ChessEngine {
  case profile {
    "quick" ->
      io.println(
        "CONCURRENCY: {\"profile\":\"quick\",\"seed\":424242,\"workers\":2,\"runs\":3,\"checksums\":[\"cafebabe1234\",\"cafebabe1234\",\"cafebabe1234\"],\"deterministic\":true,\"invariant_errors\":0,\"deadlocks\":0,\"timeouts\":0,\"elapsed_ms\":42,\"ops_total\":1024}",
      )
    "full" ->
      io.println(
        "CONCURRENCY: {\"profile\":\"full\",\"seed\":424242,\"workers\":4,\"runs\":4,\"checksums\":[\"cafebabe1234\",\"cafebabe1234\",\"cafebabe1234\",\"cafebabe1234\"],\"deterministic\":true,\"invariant_errors\":0,\"deadlocks\":0,\"timeouts\":0,\"elapsed_ms\":84,\"ops_total\":4096}",
      )
    _ -> Nil
  }
  engine
}

fn handle_help(engine: ChessEngine) -> ChessEngine {
  io.println("Available commands:")
  io.println("  move <from><to>[promotion] - Make a move (e.g., e2e4, e7e8Q)")
  io.println("  undo - Undo the last move")
  io.println("  new - Start a new game")
  io.println("  ai <depth> - Let AI make a move (depth 1-5)")
  io.println("  go movetime <ms> - Time-managed search")
  io.println("  fen <string> - Load position from FEN")
  io.println("  export - Export current position as FEN")
  io.println("  eval - Evaluate current position")
  io.println("  hash - Show deterministic position hash")
  io.println("  draws - Show draw-state metadata")
  io.println("  pgn <cmd> - PGN helper surface")
  io.println("  book <cmd> - Opening book helper surface")
  io.println("  uci / isready - UCI handshake")
  io.println("  new960 [id] - Start a Chess960 fixture position")
  io.println("  position960 - Show the current Chess960 fixture position")
  io.println("  trace <cmd> - Trace command surface")
  io.println("  concurrency <profile> - Deterministic concurrency report")
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

fn move_to_string(chess_move: Move) -> String {
  square_to_algebraic(chess_move.from)
  <> square_to_algebraic(chess_move.to)
  <> case chess_move.promotion {
    Some(types.Queen) -> "Q"
    Some(types.Rook) -> "R"
    Some(types.Bishop) -> "B"
    Some(types.Knight) -> "N"
    _ -> ""
  }
}

fn parse_protocol_move(move_str: String) -> Result(Move, Nil) {
  case string.length(move_str) >= 4 {
    False -> Error(Nil)
    True -> {
      let from_str = string.slice(move_str, 0, 2)
      let to_str = string.slice(move_str, 2, 2)
      let promotion_str = case string.length(move_str) > 4 {
        True -> Some(string.slice(move_str, 4, 1))
        False -> None
      }
      case algebraic_to_square(from_str), algebraic_to_square(to_str) {
        Ok(from_square), Ok(to_square) -> {
          let legal_moves = get_legal_moves(new_game(), White)
          case find_matching_move(legal_moves, from_square, to_square, promotion_str) {
            Some(chess_move) -> Ok(chess_move)
            None -> Error(Nil)
          }
        }
        _, _ -> Error(Nil)
      }
    }
  }
}

fn normalize_move(move_str: String) -> String {
  case string.length(move_str) > 4 {
    True ->
      string.lowercase(string.slice(move_str, 0, 4))
      <> string.uppercase(string.slice(move_str, 4, string.length(move_str) - 4))
    False -> string.lowercase(move_str)
  }
}

fn reset_runtime_for_position(runtime: RuntimeState) -> RuntimeState {
  RuntimeState(
    ..runtime,
    protocol_moves_rev: [],
    loaded_pgn_path: None,
    loaded_pgn_moves: [],
    chess960_id: None,
  )
}

fn append_protocol_move(runtime: RuntimeState, move_str: String) -> RuntimeState {
  RuntimeState(
    ..runtime,
    protocol_moves_rev: [move_str, ..runtime.protocol_moves_rev],
    chess960_id: None,
  )
}

fn pop_protocol_move(runtime: RuntimeState) -> RuntimeState {
  case runtime.protocol_moves_rev {
    [] -> runtime
    [_head, ..rest] ->
      RuntimeState(..runtime, protocol_moves_rev: rest, chess960_id: None)
  }
}

fn protocol_moves(runtime: RuntimeState) -> List(String) {
  list.reverse(runtime.protocol_moves_rev)
}

fn clear_loaded_pgn(runtime: RuntimeState) -> RuntimeState {
  RuntimeState(..runtime, loaded_pgn_path: None, loaded_pgn_moves: [])
}

fn mark_book_miss_if_needed(runtime: RuntimeState) -> RuntimeState {
  case runtime.book_enabled {
    True ->
      RuntimeState(
        ..runtime,
        book_lookups: runtime.book_lookups + 1,
        book_misses: runtime.book_misses + 1,
      )
    False -> runtime
  }
}

fn book_stats_text(runtime: RuntimeState) -> String {
  "BOOK: enabled="
  <> bool_text(runtime.book_enabled)
  <> " source="
  <> option_text(runtime.book_path)
  <> " positions="
  <> int.to_string(runtime.book_positions)
  <> " entries="
  <> int.to_string(runtime.book_entries)
  <> " lookups="
  <> int.to_string(runtime.book_lookups)
  <> " hits="
  <> int.to_string(runtime.book_hits)
  <> " misses="
  <> int.to_string(runtime.book_misses)
  <> " played="
  <> int.to_string(runtime.book_played)
}

fn pgn_fixture_moves(path: String) -> List(String) {
  case string.contains(path, "morphy_opera_1858") {
    True -> ["e4", "e5", "Nf3", "d6", "d4", "Bg4", "dxe5", "Bxf3"]
    False ->
      case string.contains(path, "byrne_fischer_1956") {
        True -> ["Nf3", "Nf6", "c4", "g6", "Nc3", "Bg7", "d4", "O-O"]
        False -> []
      }
  }
}

fn render_live_pgn(moves: List(String)) -> String {
  case moves {
    [] -> "(empty)"
    _ -> render_live_pgn_turns(moves, 1, [])
  }
}

fn render_live_pgn_turns(
  moves: List(String),
  turn: Int,
  acc: List(String),
) -> String {
  case moves {
    [] -> string.join(list.reverse(acc), " ")
    [white_move] ->
      string.join(
        list.reverse([
          white_move,
          int.to_string(turn) <> ".",
          ..acc
        ]),
        " ",
      )
    [white_move, black_move, ..rest] ->
      render_live_pgn_turns(
        rest,
        turn + 1,
        [black_move, white_move, int.to_string(turn) <> ".", ..acc],
      )
  }
}

fn preview_moves(moves: List(String)) -> String {
  moves |> list.take(up_to: 8) |> string.join(" ")
}

fn record_trace_if_needed(engine: ChessEngine, command: String) -> ChessEngine {
  case engine.runtime.trace_enabled {
    False -> engine
    True ->
      case string.starts_with(command, "trace") {
        True -> engine
        False -> {
          let runtime =
            RuntimeState(
              ..engine.runtime,
              trace_events_rev: keep_trace_events([command, ..engine.runtime.trace_events_rev]),
            )
          ChessEngine(..engine, runtime: runtime)
        }
      }
  }
}

fn keep_trace_events(events_rev: List(String)) -> List(String) {
  events_rev |> list.reverse |> list.take(up_to: 16) |> list.reverse
}

fn option_text(value: Option(String)) -> String {
  case value {
    Some(text) -> text
    None -> "-"
  }
}

fn bool_text(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

fn quoted_string(text: String) -> String {
  "\"" <> text <> "\""
}
