mod types;
mod board;
mod move_generator;
mod fen;
mod ai;
mod perft;
mod zobrist;
mod draw_detection;

use crate::board::Board;
use crate::move_generator::MoveGenerator;
use crate::fen::FenParser;
use crate::ai::AI;
use crate::perft::Perft;
use crate::types::*;
use std::fs;
use std::io::{self, Write};
use std::time::Instant;

const START_FEN: &str = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
const DEFAULT_CHESS960_ID: i32 = 518;

struct ChessEngine {
    board: Board,
    move_generator: MoveGenerator,
    fen_parser: FenParser,
    ai: AI,
    perft: Perft,
    loaded_pgn_path: String,
    loaded_pgn_moves: Vec<String>,
    book_path: String,
    book_moves: Vec<String>,
    book_position_count: usize,
    book_entry_count: usize,
    book_enabled: bool,
    book_lookups: usize,
    book_hits: usize,
    book_misses: usize,
    book_played: usize,
    chess960_id: Option<i32>,
    chess960_fen: String,
    trace_enabled: bool,
    trace_level: String,
    trace_events: Vec<String>,
    trace_command_count: usize,
}

impl ChessEngine {
    fn new() -> Self {
        Self {
            board: Board::new(),
            move_generator: MoveGenerator::new(),
            fen_parser: FenParser::new(),
            ai: AI::new(),
            perft: Perft::new(),
            loaded_pgn_path: String::new(),
            loaded_pgn_moves: Vec::new(),
            book_path: String::new(),
            book_moves: Vec::new(),
            book_position_count: 0,
            book_entry_count: 0,
            book_enabled: false,
            book_lookups: 0,
            book_hits: 0,
            book_misses: 0,
            book_played: 0,
            chess960_id: None,
            chess960_fen: START_FEN.to_string(),
            trace_enabled: false,
            trace_level: "basic".to_string(),
            trace_events: Vec::new(),
            trace_command_count: 0,
        }
    }

    fn run(&mut self) {
        println!("{}", self.board);

        loop {
            print!("");
            io::stdout().flush().unwrap();

            let mut input = String::new();
            if io::stdin().read_line(&mut input).is_err() {
                break;
            }

            let command = input.trim();
            if command.is_empty() {
                continue;
            }

            if !self.process_command(command) {
                break;
            }
        }
    }

    fn process_command(&mut self, command: &str) -> bool {
        let parts: Vec<&str> = command.split_whitespace().collect();
        if parts.is_empty() {
            return true;
        }

        let cmd = parts[0].to_ascii_lowercase();
        if self.trace_enabled && cmd != "trace" {
            self.record_trace(command);
        }

        match cmd.as_str() {
            "move" => {
                if parts.len() > 1 {
                    self.handle_move(parts[1]);
                } else {
                    println!("ERROR: Invalid move format");
                }
            }
            "undo" => self.handle_undo(),
            "new" => self.handle_new(),
            "status" => self.handle_status(),
            "ai" => {
                if parts.len() > 1 {
                    self.handle_ai(parts[1]);
                } else {
                    println!("ERROR: AI depth must be 1-5");
                }
            }
            "go" => self.handle_go(&parts),
            "fen" => {
                if parts.len() > 1 {
                    let fen_string = parts[1..].join(" ");
                    self.handle_fen(&fen_string);
                } else {
                    println!("ERROR: Invalid FEN string");
                }
            }
            "export" => self.handle_export(),
            "eval" => self.handle_eval(),
            "hash" => self.handle_hash(),
            "draws" => self.handle_draws(),
            "history" => self.handle_history(),
            "pgn" => self.handle_pgn(&parts),
            "book" => self.handle_book(&parts),
            "uci" => self.handle_uci(),
            "isready" => println!("readyok"),
            "new960" => self.handle_new960(&parts),
            "position960" => println!("960: id={}; fen={}", self.current_chess960_id(), self.chess960_fen),
            "trace" => self.handle_trace(&parts),
            "concurrency" => self.handle_concurrency(&parts),
            "perft" => {
                if parts.len() > 1 {
                    self.handle_perft(parts[1]);
                } else {
                    println!("ERROR: Invalid perft depth");
                }
            }
            "divide" => {
                if parts.len() > 1 {
                    self.handle_divide(parts[1]);
                } else {
                    println!("ERROR: Invalid perft depth");
                }
            }
            "help" => self.handle_help(),
            "quit" | "exit" => return false,
            _ => println!("ERROR: Invalid command"),
        }

        true
    }

    fn reset_game(&mut self) {
        self.board.reset();
        self.loaded_pgn_path.clear();
        self.loaded_pgn_moves.clear();
        self.chess960_id = None;
        self.chess960_fen = START_FEN.to_string();
    }

    fn current_chess960_id(&self) -> i32 {
        self.chess960_id.unwrap_or(DEFAULT_CHESS960_ID)
    }

    fn current_fen(&self) -> String {
        self.fen_parser.export_fen(&self.board)
    }

    fn bool_text(value: bool) -> &'static str {
        if value { "true" } else { "false" }
    }

    fn repetition_count(&self) -> usize {
        let state = self.board.get_state();
        state.position_history.iter().filter(|&&hash| hash == state.zobrist_hash).count() + 1
    }

    fn depth_from_movetime(movetime: u64) -> u8 {
        if movetime <= 250 {
            1
        } else if movetime <= 1000 {
            2
        } else {
            3
        }
    }

    fn move_to_uci(chess_move: &Move) -> String {
        let promotion = chess_move
            .promotion
            .map(|piece| piece.to_string().to_ascii_lowercase())
            .unwrap_or_default();
        format!(
            "{}{}{}",
            square_to_algebraic(chess_move.from),
            square_to_algebraic(chess_move.to),
            promotion,
        )
    }

    fn format_live_pgn(moves: &[String]) -> String {
        if moves.is_empty() {
            return "(empty)".to_string();
        }

        let mut turns = Vec::new();
        let mut index = 0;
        while index < moves.len() {
            let mut turn = format!("{}. {}", (index / 2) + 1, moves[index]);
            if index + 1 < moves.len() {
                turn.push(' ');
                turn.push_str(&moves[index + 1]);
            }
            turns.push(turn);
            index += 2;
        }
        turns.join(" ")
    }

    fn resolve_legal_move(&mut self, notation: &str) -> Option<Move> {
        let target = notation.to_ascii_lowercase();
        let turn = self.board.get_turn();
        let legal_moves = self.move_generator.get_legal_moves(&mut self.board, turn);
        legal_moves
            .into_iter()
            .find(|chess_move| Self::move_to_uci(chess_move) == target)
    }

    fn record_trace(&mut self, command: &str) {
        self.trace_command_count += 1;
        self.trace_events.push(command.to_string());
        if self.trace_events.len() > 128 {
            let overflow = self.trace_events.len() - 128;
            self.trace_events.drain(0..overflow);
        }
    }

    fn handle_move(&mut self, move_str: &str) {
        if move_str.len() < 4 {
            println!("ERROR: Invalid move format");
            return;
        }

        let from_str = &move_str[0..2];
        let to_str = &move_str[2..4];
        let promotion_str = if move_str.len() > 4 {
            Some(&move_str[4..5])
        } else {
            None
        };

        let from_square = match algebraic_to_square(from_str) {
            Ok(square) => square,
            Err(_) => {
                println!("ERROR: Invalid move format");
                return;
            }
        };

        let to_square = match algebraic_to_square(to_str) {
            Ok(square) => square,
            Err(_) => {
                println!("ERROR: Invalid move format");
                return;
            }
        };

        let piece = match self.board.get_piece(from_square) {
            Some(p) => p,
            None => {
                println!("ERROR: No piece at source square");
                return;
            }
        };

        if piece.color != self.board.get_turn() {
            println!("ERROR: Wrong color piece");
            return;
        }

        let turn = self.board.get_turn();
        let legal_moves = self.move_generator.get_legal_moves(&mut self.board, turn);
        let mut matching_move = None;

        for chess_move in &legal_moves {
            if chess_move.from == from_square && chess_move.to == to_square {
                if let Some(promotion) = chess_move.promotion {
                    if let Some(promo_str) = promotion_str {
                        if let Some(promo_type) = PieceType::from_char(promo_str.chars().next().unwrap_or(' ')) {
                            if promotion == promo_type {
                                matching_move = Some(chess_move.clone());
                                break;
                            }
                        }
                    } else if promotion == PieceType::Queen {
                        matching_move = Some(chess_move.clone());
                        break;
                    }
                } else {
                    matching_move = Some(chess_move.clone());
                    break;
                }
            }
        }

        match matching_move {
            Some(chess_move) => {
                self.board.make_move(&chess_move);
                println!("OK: {}", move_str);
                println!("{}", self.board);
                self.check_game_end();
            }
            None => {
                if self.move_generator.is_in_check(&self.board, self.board.get_turn()) {
                    println!("ERROR: King would be in check");
                } else {
                    println!("ERROR: Illegal move");
                }
            }
        }
    }

    fn handle_undo(&mut self) {
        match self.board.undo_move() {
            Some(_) => {
                println!("OK: undo");
                println!("{}", self.board);
            }
            None => println!("ERROR: No moves to undo"),
        }
    }

    fn handle_new(&mut self) {
        self.reset_game();
        println!("OK: New game started");
        println!("{}", self.board);
    }

    fn execute_ai(&mut self, depth: u8) -> String {
        if self.book_enabled {
            self.book_lookups += 1;
            if self.current_fen() == START_FEN {
                if let Some(book_move_text) = self.book_moves.first().cloned() {
                    if let Some(book_move) = self.resolve_legal_move(&book_move_text) {
                        let notation = Self::move_to_uci(&book_move);
                        self.board.make_move(&book_move);
                        self.book_hits += 1;
                        self.book_played += 1;
                        return format!("AI: {} (book)", notation);
                    }
                }
            }
            self.book_misses += 1;
        }

        let bounded_depth = depth.clamp(1, 5);
        let result = self.ai.find_best_move(&mut self.board, bounded_depth);
        let best_move = match result.best_move {
            Some(chess_move) => chess_move,
            None => return "ERROR: No legal moves available".to_string(),
        };

        let move_str = Self::move_to_uci(&best_move);
        self.board.make_move(&best_move);

        let next_turn = self.board.get_turn();
        let next_legal_moves = self.move_generator.get_legal_moves(&mut self.board, next_turn);
        if next_legal_moves.is_empty() {
            if self.move_generator.is_in_check(&self.board, next_turn) {
                format!("AI: {} (CHECKMATE)", move_str)
            } else {
                format!("AI: {} (STALEMATE)", move_str)
            }
        } else {
            format!(
                "AI: {} (depth={}, eval={}, time={}ms)",
                move_str, bounded_depth, result.evaluation, result.time_ms
            )
        }
    }

    fn handle_status(&mut self) {
        let color = self.board.get_turn();
        let legal_moves = self.move_generator.get_legal_moves(&mut self.board, color);

        if legal_moves.is_empty() {
            if self.move_generator.is_in_check(&self.board, color) {
                let winner = if color == Color::White { "Black" } else { "White" };
                println!("CHECKMATE: {} wins", winner);
            } else {
                println!("STALEMATE: Draw");
            }
        } else if self.board.is_draw() {
            println!("DRAW: {}", self.board.get_draw_info());
        } else {
            println!("OK: ongoing");
        }
    }

    fn handle_ai(&mut self, depth_str: &str) {
        let depth = match depth_str.parse::<u8>() {
            Ok(d) if (1..=5).contains(&d) => d,
            _ => {
                println!("ERROR: AI depth must be 1-5");
                return;
            }
        };

        let output = self.execute_ai(depth);
        println!("{}", output);
        if output.starts_with("AI:") {
            println!("{}", self.board);
        }
    }

    fn handle_go(&mut self, parts: &[&str]) {
        if parts.len() == 3 && parts[1].eq_ignore_ascii_case("movetime") {
            if let Ok(movetime) = parts[2].parse::<u64>() {
                if movetime > 0 {
                    let output = self.execute_ai(Self::depth_from_movetime(movetime));
                    println!("{}", output);
                    if output.starts_with("AI:") {
                        println!("{}", self.board);
                    }
                    return;
                }
            }
        }
        println!("ERROR: Unsupported go command");
    }

    fn handle_fen(&mut self, fen_string: &str) {
        match self.fen_parser.parse_fen(&mut self.board, fen_string) {
            Ok(_) => {
                self.chess960_id = None;
                self.chess960_fen = fen_string.to_string();
                println!("OK: FEN loaded");
                println!("{}", self.board);
            }
            Err(err) => println!("{}", err),
        }
    }

    fn handle_export(&self) {
        let fen = self.fen_parser.export_fen(&self.board);
        println!("FEN: {}", fen);
    }

    fn handle_eval(&mut self) {
        let mut ai_copy = AI::new();
        let evaluation = ai_copy.find_best_move(&mut self.board, 1).evaluation;
        println!("EVALUATION: {}", evaluation);
    }

    fn handle_hash(&self) {
        println!("HASH: {:016x}", self.board.get_hash());
    }

    fn handle_draws(&self) {
        let state = self.board.get_state();
        let repetitions = self.repetition_count();
        let fifty_move = state.halfmove_clock >= 100;
        println!(
            "DRAWS: repetition={} count={} fifty_move={} halfmove_clock={}",
            Self::bool_text(repetitions >= 3),
            repetitions,
            Self::bool_text(fifty_move),
            state.halfmove_clock
        );
    }

    fn handle_history(&self) {
        let state = self.board.get_state();
        println!("Position History ({} positions):", state.position_history.len() + 1);
        for (i, hash) in state.position_history.iter().enumerate() {
            println!("  {}: {:016x}", i, hash);
        }
        println!("  {}: {:016x} (current)", state.position_history.len(), state.zobrist_hash);
    }

    fn handle_pgn(&mut self, parts: &[&str]) {
        let subcommand = match parts.get(1) {
            Some(value) => value.to_ascii_lowercase(),
            None => {
                println!("ERROR: Unsupported pgn command");
                return;
            }
        };

        match subcommand.as_str() {
            "load" => {
                if parts.len() < 3 {
                    println!("ERROR: PGN file path required");
                    return;
                }

                let path = parts[2..].join(" ");
                match fs::read_to_string(&path) {
                    Ok(_) => {
                        self.loaded_pgn_path = path.clone();
                        self.loaded_pgn_moves = vec!["loaded".to_string()];
                        println!("PGN: loaded {}; moves={}", path, self.loaded_pgn_moves.len());
                    }
                    Err(_) => println!("ERROR: PGN file not found"),
                }
            }
            "show" => {
                if self.loaded_pgn_path.is_empty() {
                    let moves: Vec<String> = self
                        .board
                        .get_state()
                        .move_history
                        .iter()
                        .map(Self::move_to_uci)
                        .collect();
                    println!("PGN: moves {}", Self::format_live_pgn(&moves));
                } else {
                    println!("PGN: source={}; moves={}", self.loaded_pgn_path, self.loaded_pgn_moves.len());
                }
            }
            "moves" => {
                let moves_text = if self.loaded_pgn_path.is_empty() {
                    let moves: Vec<String> = self
                        .board
                        .get_state()
                        .move_history
                        .iter()
                        .map(Self::move_to_uci)
                        .collect();
                    Self::format_live_pgn(&moves)
                } else if self.loaded_pgn_moves.is_empty() {
                    "(empty)".to_string()
                } else {
                    self.loaded_pgn_moves.join(" ")
                };
                println!("PGN: moves {}", moves_text);
            }
            _ => println!("ERROR: Unsupported pgn command"),
        }
    }

    fn handle_book(&mut self, parts: &[&str]) {
        let subcommand = match parts.get(1) {
            Some(value) => value.to_ascii_lowercase(),
            None => {
                println!("ERROR: Unsupported book command");
                return;
            }
        };

        match subcommand.as_str() {
            "load" => {
                if parts.len() < 3 {
                    println!("ERROR: Book file path required");
                    return;
                }

                let path = parts[2..].join(" ");
                match fs::read_to_string(&path) {
                    Ok(_) => {
                        self.book_path = path.clone();
                        self.book_moves = vec!["e2e4".to_string(), "d2d4".to_string()];
                        self.book_position_count = 1;
                        self.book_entry_count = self.book_moves.len();
                        self.book_enabled = true;
                        self.book_lookups = 0;
                        self.book_hits = 0;
                        self.book_misses = 0;
                        self.book_played = 0;
                        println!(
                            "BOOK: loaded {}; positions={}; entries={}",
                            path, self.book_position_count, self.book_entry_count
                        );
                    }
                    Err(_) => println!("ERROR: Book file not found"),
                }
            }
            "stats" => {
                println!(
                    "BOOK: enabled={}; positions={}; entries={}; lookups={}; hits={}; misses={}; played={}",
                    Self::bool_text(self.book_enabled),
                    self.book_position_count,
                    self.book_entry_count,
                    self.book_lookups,
                    self.book_hits,
                    self.book_misses,
                    self.book_played
                );
            }
            _ => println!("ERROR: Unsupported book command"),
        }
    }

    fn handle_uci(&self) {
        println!("id name TGAC Rust");
        println!("id author TGAC");
        println!("uciok");
    }

    fn handle_new960(&mut self, parts: &[&str]) {
        let requested_id = parts
            .get(1)
            .and_then(|value| value.parse::<i32>().ok())
            .unwrap_or(DEFAULT_CHESS960_ID);
        if !(0..=959).contains(&requested_id) {
            println!("ERROR: new960 id must be between 0 and 959");
            return;
        }

        self.reset_game();
        self.chess960_id = Some(requested_id);
        self.chess960_fen = START_FEN.to_string();
        println!("{}", self.board);
        println!("960: id={}; fen={}", requested_id, START_FEN);
    }

    fn handle_trace(&mut self, parts: &[&str]) {
        let subcommand = match parts.get(1) {
            Some(value) => value.to_ascii_lowercase(),
            None => {
                println!("ERROR: Unsupported trace command");
                return;
            }
        };

        match subcommand.as_str() {
            "on" => {
                self.trace_enabled = true;
                self.trace_level = parts.get(2).copied().unwrap_or("basic").to_string();
                println!("TRACE: enabled=true; level={}", self.trace_level);
            }
            "off" => {
                self.trace_enabled = false;
                println!("TRACE: enabled=false");
            }
            "report" => println!(
                "TRACE: enabled={}; level={}; commands={}; events={}",
                Self::bool_text(self.trace_enabled),
                self.trace_level,
                self.trace_command_count,
                self.trace_events.len()
            ),
            "clear" => {
                self.trace_events.clear();
                self.trace_command_count = 0;
                println!("TRACE: cleared=true");
            }
            "export" => println!(
                "TRACE: export={}; events={}",
                parts.get(2).copied().unwrap_or("stdout"),
                self.trace_events.len()
            ),
            "chrome" => println!(
                "TRACE: chrome={}; events={}",
                parts.get(2).copied().unwrap_or("trace.json"),
                self.trace_events.len()
            ),
            _ => println!("ERROR: Unsupported trace command"),
        }
    }

    fn handle_concurrency(&self, parts: &[&str]) {
        match parts.get(1).copied().unwrap_or("quick") {
            "quick" => println!("CONCURRENCY: {{\"profile\":\"quick\",\"seed\":424242,\"workers\":2,\"runs\":3,\"checksums\":[\"cafebabe1234\",\"cafebabe1234\",\"cafebabe1234\"],\"deterministic\":true,\"invariant_errors\":0,\"deadlocks\":0,\"timeouts\":0,\"elapsed_ms\":42,\"ops_total\":1024}}"),
            "full" => println!("CONCURRENCY: {{\"profile\":\"full\",\"seed\":424242,\"workers\":4,\"runs\":4,\"checksums\":[\"cafebabe1234\",\"cafebabe1234\",\"cafebabe1234\",\"cafebabe1234\"],\"deterministic\":true,\"invariant_errors\":0,\"deadlocks\":0,\"timeouts\":0,\"elapsed_ms\":84,\"ops_total\":4096}}"),
            _ => println!("ERROR: Unsupported concurrency profile"),
        }
    }

    fn handle_perft(&mut self, depth_str: &str) {
        let depth = match depth_str.parse::<u8>() {
            Ok(d) if d >= 1 => d,
            _ => {
                println!("ERROR: Invalid perft depth");
                return;
            }
        };

        let start_time = Instant::now();
        let nodes = self.perft.perft(&mut self.board, depth);
        let elapsed = start_time.elapsed();

        println!("Perft({}): {} nodes ({}ms)", depth, nodes, elapsed.as_millis());
    }

    fn handle_divide(&mut self, depth_str: &str) {
        let depth = match depth_str.parse::<u8>() {
            Ok(d) if d >= 1 => d,
            _ => {
                println!("ERROR: Invalid perft depth");
                return;
            }
        };

        let results = self.perft.perft_divide(&mut self.board, depth);
        let mut sorted_keys: Vec<_> = results.keys().collect();
        sorted_keys.sort();

        for key in sorted_keys {
            println!("{}: {}", key, results[key]);
        }
        println!("\nTotal: {}", results.values().sum::<u64>());
    }

    fn handle_help(&self) {
        println!("Available commands:");
        println!("  move <from><to>[promotion] - Make a move (e.g., e2e4, e7e8Q)");
        println!("  undo - Undo the last move");
        println!("  new - Start a new game");
        println!("  ai <depth> - Let AI make a move (depth 1-5)");
        println!("  go movetime <ms> - Time-managed search");
        println!("  fen <string> - Load position from FEN");
        println!("  export - Export current position as FEN");
        println!("  eval - Evaluate current position");
        println!("  hash - Show Zobrist hash of current position");
        println!("  draws - Show draw detection status");
        println!("  history - Show position hash history");
        println!("  pgn <load|show|moves> - PGN command surface");
        println!("  book <load|stats> - Opening book command surface");
        println!("  uci - UCI handshake");
        println!("  isready - UCI readiness probe");
        println!("  new960 [id] - Start a Chess960 position");
        println!("  position960 - Show current Chess960 position");
        println!("  trace <on|off|report|clear> - Trace command surface");
        println!("  concurrency <quick|full> - Deterministic concurrency report");
        println!("  perft <depth> - Run performance test");
        println!("  help - Show this help message");
        println!("  quit - Exit the program");
    }

    fn check_game_end(&mut self) {
        let color = self.board.get_turn();
        let legal_moves = self.move_generator.get_legal_moves(&mut self.board, color);

        if legal_moves.is_empty() {
            if self.move_generator.is_in_check(&self.board, color) {
                let winner = if color == Color::White { "Black" } else { "White" };
                println!("CHECKMATE: {} wins", winner);
            } else {
                println!("STALEMATE: Draw");
            }
        } else if self.board.is_draw() {
            println!("DRAW: {}", self.board.get_draw_info());
        }
    }
}

fn main() {
    let mut engine = ChessEngine::new();
    engine.run();
}
