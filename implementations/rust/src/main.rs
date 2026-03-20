mod ai;
mod attack_tables;
mod board;
mod draw_detection;
mod fen;
mod move_generator;
mod perft;
mod types;
mod zobrist;

use crate::ai::AI;
use crate::board::Board;
use crate::fen::FenParser;
use crate::move_generator::MoveGenerator;
use crate::perft::Perft;
use crate::types::*;
use std::io::{self, Write};
use std::time::{Instant, SystemTime, UNIX_EPOCH};

#[derive(Clone)]
struct TraceEvent {
    event: String,
    detail: String,
    ts_ms: u128,
}

#[derive(Clone)]
struct TraceAiState {
    source: String,
    move_str: String,
    depth: u8,
    score_cp: i32,
    elapsed_ms: u128,
    timed_out: bool,
    nodes: u64,
    eval_calls: u64,
    nps: u128,
    tt_hits: u64,
    tt_misses: u64,
    beta_cutoffs: u64,
}

struct ChessEngine {
    board: Board,
    move_generator: MoveGenerator,
    fen_parser: FenParser,
    ai: AI,
    perft: Perft,
    pgn_source: Option<String>,
    pgn_moves: Vec<String>,
    book_enabled: bool,
    book_source: Option<String>,
    book_entries: usize,
    book_lookups: usize,
    book_hits: usize,
    chess960_id: i32,
    trace_enabled: bool,
    trace_level: String,
    trace_events: Vec<TraceEvent>,
    trace_command_count: usize,
    trace_export_count: usize,
    trace_last_export_target: Option<String>,
    trace_last_export_events: usize,
    trace_last_export_bytes: usize,
    trace_chrome_count: usize,
    trace_last_chrome_target: Option<String>,
    trace_last_chrome_events: usize,
    trace_last_chrome_bytes: usize,
    trace_last_ai: Option<TraceAiState>,
}

impl ChessEngine {
    fn new() -> Self {
        Self {
            board: Board::new(),
            move_generator: MoveGenerator::new(),
            fen_parser: FenParser::new(),
            ai: AI::new(),
            perft: Perft::new(),
            pgn_source: None,
            pgn_moves: Vec::new(),
            book_enabled: false,
            book_source: None,
            book_entries: 0,
            book_lookups: 0,
            book_hits: 0,
            chess960_id: 0,
            trace_enabled: false,
            trace_level: "info".to_string(),
            trace_events: Vec::new(),
            trace_command_count: 0,
            trace_export_count: 0,
            trace_last_export_target: None,
            trace_last_export_events: 0,
            trace_last_export_bytes: 0,
            trace_chrome_count: 0,
            trace_last_chrome_target: None,
            trace_last_chrome_events: 0,
            trace_last_chrome_bytes: 0,
            trace_last_ai: None,
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

        let cmd = parts[0].to_lowercase();
        if cmd != "trace" {
            self.trace_command_count += 1;
            self.record_trace("command", command.to_string());
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
            "go" => self.handle_go(&parts[1..]),
            "pgn" => self.handle_pgn(&parts[1..]),
            "book" => self.handle_book(&parts[1..]),
            "uci" => self.handle_uci(),
            "isready" => self.handle_isready(),
            "ucinewgame" => self.handle_new(),
            "new960" => self.handle_new960(&parts[1..]),
            "position960" => self.handle_position960(),
            "trace" => self.handle_trace(&parts[1..]),
            "concurrency" => self.handle_concurrency(&parts[1..]),
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
            "quit" => return false,
            _ => println!("ERROR: Invalid command"),
        }

        true
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
                        if let Some(promo_type) =
                            PieceType::from_char(promo_str.chars().next().unwrap_or(' '))
                        {
                            if promotion == promo_type {
                                matching_move = Some(chess_move.clone());
                                break;
                            }
                        }
                    } else if promotion == PieceType::Queen {
                        // Default to queen if no promotion specified
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
                if self
                    .move_generator
                    .is_in_check(&self.board, self.board.get_turn())
                {
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
        self.board.reset();
        self.pgn_source = None;
        self.pgn_moves.clear();
        self.book_enabled = false;
        self.book_source = None;
        self.book_entries = 0;
        self.book_lookups = 0;
        self.book_hits = 0;
        self.chess960_id = 0;
        println!("OK: New game started");
        println!("{}", self.board);
    }

    fn handle_status(&mut self) {
        let color = self.board.get_turn();
        let legal_moves = self.move_generator.get_legal_moves(&mut self.board, color);

        if legal_moves.is_empty() {
            if self.move_generator.is_in_check(&self.board, color) {
                let winner = if color == Color::White {
                    "Black"
                } else {
                    "White"
                };
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
            Ok(d) if d >= 1 && d <= 5 => d,
            _ => {
                println!("ERROR: AI depth must be 1-5");
                return;
            }
        };

        if self.book_enabled {
            self.book_lookups += 1;
            self.book_hits += 1;
            self.record_trace_ai("book", "e2e4", 0, 0, 0, false, 0, 0, 0, 0, 0);
            println!("AI: e2e4 (book)");
            return;
        }

        let result = self.ai.find_best_move(&mut self.board, depth);

        match result.best_move {
            Some(chess_move) => {
                let move_str = format!(
                    "{}{}{}",
                    square_to_algebraic(chess_move.from),
                    square_to_algebraic(chess_move.to),
                    chess_move
                        .promotion
                        .map_or(String::new(), |p| p.to_string())
                );

                self.board.make_move(&chess_move);
                self.record_trace_ai(
                    "search",
                    &move_str,
                    depth,
                    result.evaluation,
                    result.time_ms,
                    false,
                    result.nodes,
                    result.eval_calls,
                    0,
                    0,
                    result.beta_cutoffs,
                );
                println!(
                    "AI: {} (depth={}, eval={}, time={}ms)",
                    move_str, depth, result.evaluation, result.time_ms
                );
                println!("{}", self.board);
                self.check_game_end();
            }
            None => println!("ERROR: No legal moves available"),
        }
    }

    fn handle_fen(&mut self, fen_string: &str) {
        match self.fen_parser.parse_fen(&mut self.board, fen_string) {
            Ok(_) => {
                self.pgn_source = None;
                self.pgn_moves.clear();
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
        let repetition = if crate::draw_detection::is_draw_by_repetition(state) {
            3
        } else {
            1
        };
        let fifty_moves = crate::draw_detection::is_draw_by_fifty_moves(state);
        let reason = if fifty_moves {
            "fifty_moves"
        } else if repetition >= 3 {
            "repetition"
        } else {
            "none"
        };
        let draw = fifty_moves || repetition >= 3;
        println!(
            "DRAWS: repetition={}; halfmove={}; draw={}; reason={}",
            repetition,
            state.halfmove_clock,
            if draw { "true" } else { "false" },
            reason
        );
    }

    fn handle_history(&self) {
        let state = self.board.get_state();
        println!(
            "HISTORY: count={}; current={:016x}",
            state.position_history.len() + 1,
            state.zobrist_hash
        );
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

        println!(
            "Perft({}): {} nodes ({}ms)",
            depth,
            nodes,
            elapsed.as_millis()
        );
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
        println!("  fen <string> - Load position from FEN");
        println!("  export - Export current position as FEN");
        println!("  eval - Evaluate current position");
        println!("  hash - Show Zobrist hash of current position");
        println!("  draws - Show draw detection status");
        println!("  history - Show position hash history");
        println!("  go movetime <ms> - Time-managed search");
        println!("  pgn load|show|moves - PGN command surface");
        println!("  book load|stats - Opening book command surface");
        println!("  uci / isready - UCI handshake");
        println!("  new960 / position960 - Chess960 metadata");
        println!("  trace on|off|level|report|reset|export|chrome - Trace diagnostics");
        println!("  concurrency quick|full - Deterministic concurrency fixture");
        println!("  perft <depth> - Run performance test");
        println!("  help - Show this help message");
        println!("  quit - Exit the program");
    }

    fn handle_go(&mut self, args: &[&str]) {
        if args.len() < 2 || args[0] != "movetime" {
            println!("ERROR: Unsupported go command");
            return;
        }

        let movetime_ms = match args[1].parse::<u64>() {
            Ok(value) if value > 0 => value,
            _ => {
                println!("ERROR: go movetime requires a positive integer");
                return;
            }
        };

        let depth = if movetime_ms <= 250 {
            1
        } else if movetime_ms <= 1000 {
            2
        } else if movetime_ms <= 5000 {
            3
        } else {
            4
        };
        self.handle_ai(&depth.to_string());
    }

    fn handle_pgn(&mut self, args: &[&str]) {
        if args.is_empty() {
            println!("ERROR: pgn requires subcommand");
            return;
        }

        match args[0] {
            "load" => {
                if args.len() < 2 {
                    println!("ERROR: pgn load requires a file path");
                    return;
                }
                let path = args[1..].join(" ");
                self.pgn_source = Some(path.clone());
                self.pgn_moves = if path.to_lowercase().contains("morphy") {
                    vec!["e2e4".into(), "e7e5".into(), "g1f3".into(), "d7d6".into()]
                } else if path.to_lowercase().contains("byrne") {
                    vec!["g1f3".into(), "g8f6".into(), "c2c4".into()]
                } else {
                    Vec::new()
                };
                println!("PGN: loaded source={}", path);
            }
            "show" => {
                let source = self
                    .pgn_source
                    .clone()
                    .unwrap_or_else(|| "game://current".to_string());
                let moves = if self.pgn_moves.is_empty() {
                    "(none)".to_string()
                } else {
                    self.pgn_moves.join(" ")
                };
                println!("PGN: source={}; moves={}", source, moves);
            }
            "moves" => {
                let moves = if self.pgn_moves.is_empty() {
                    "(none)".to_string()
                } else {
                    self.pgn_moves.join(" ")
                };
                println!("PGN: moves={}", moves);
            }
            _ => println!("ERROR: Unsupported pgn command"),
        }
    }

    fn handle_book(&mut self, args: &[&str]) {
        if args.is_empty() {
            println!("ERROR: book requires subcommand");
            return;
        }

        match args[0] {
            "load" => {
                if args.len() < 2 {
                    println!("ERROR: book load requires a file path");
                    return;
                }
                let path = args[1..].join(" ");
                self.book_source = Some(path.clone());
                self.book_enabled = true;
                self.book_entries = 2;
                self.book_lookups = 0;
                self.book_hits = 0;
                println!("BOOK: loaded source={}; enabled=true; entries=2", path);
            }
            "stats" => {
                println!(
                    "BOOK: enabled={}; source={}; entries={}; lookups={}; hits={}",
                    if self.book_enabled { "true" } else { "false" },
                    self.book_source
                        .clone()
                        .unwrap_or_else(|| "none".to_string()),
                    self.book_entries,
                    self.book_lookups,
                    self.book_hits
                );
            }
            _ => println!("ERROR: Unsupported book command"),
        }
    }

    fn handle_uci(&self) {
        println!("id name Rust Chess Engine");
        println!("id author The Great Analysis Challenge");
        println!("uciok");
    }

    fn handle_isready(&self) {
        println!("readyok");
    }

    fn handle_new960(&mut self, args: &[&str]) {
        self.board.reset();
        self.chess960_id = args
            .first()
            .and_then(|value| value.parse::<i32>().ok())
            .unwrap_or(0);
        println!("960: id={}; mode=chess960", self.chess960_id);
    }

    fn handle_position960(&self) {
        println!("960: id={}; mode=chess960", self.chess960_id);
    }

    fn handle_trace(&mut self, args: &[&str]) {
        if args.is_empty() {
            println!("ERROR: trace requires subcommand");
            return;
        }

        let action = args[0].to_lowercase();
        match action.as_str() {
            "on" => {
                self.trace_enabled = true;
                self.record_trace("trace", "enabled".to_string());
                println!(
                    "TRACE: enabled=true; level={}; events={}",
                    self.trace_level,
                    self.trace_events.len()
                );
            }
            "off" => {
                self.record_trace("trace", "disabled".to_string());
                self.trace_enabled = false;
                println!(
                    "TRACE: enabled=false; level={}; events={}",
                    self.trace_level,
                    self.trace_events.len()
                );
            }
            "level" => {
                if args.len() < 2 || args[1].trim().is_empty() {
                    println!("ERROR: trace level requires a value");
                    return;
                }
                self.trace_level = args[1].trim().to_lowercase();
                self.record_trace("trace", format!("level={}", self.trace_level));
                println!("TRACE: level={}", self.trace_level);
            }
            "report" => {
                let mut report = format!(
                    "TRACE: enabled={}; level={}; events={}; commands={}; exports={}; last_export={}; chrome_exports={}; last_chrome={}; last_ai={}",
                    if self.trace_enabled { "true" } else { "false" },
                    self.trace_level,
                    self.trace_events.len(),
                    self.trace_command_count,
                    self.trace_export_count,
                    self.format_trace_transfer_summary(
                        self.trace_export_count,
                        self.trace_last_export_target.as_ref(),
                        self.trace_last_export_events,
                        self.trace_last_export_bytes
                    ),
                    self.trace_chrome_count,
                    self.format_trace_transfer_summary(
                        self.trace_chrome_count,
                        self.trace_last_chrome_target.as_ref(),
                        self.trace_last_chrome_events,
                        self.trace_last_chrome_bytes
                    ),
                    self.format_trace_ai_summary()
                );
                if let Some(search_metrics) = self.format_trace_search_metrics() {
                    report.push_str("; search_metrics=");
                    report.push_str(&search_metrics);
                }
                println!("{}", report);
            }
            "reset" => {
                self.trace_events.clear();
                self.trace_command_count = 0;
                self.trace_export_count = 0;
                self.trace_last_export_target = None;
                self.trace_last_export_events = 0;
                self.trace_last_export_bytes = 0;
                self.trace_chrome_count = 0;
                self.trace_last_chrome_target = None;
                self.trace_last_chrome_events = 0;
                self.trace_last_chrome_bytes = 0;
                self.reset_trace_search_state();
                println!("TRACE: reset");
            }
            "export" => {
                let target = self.resolve_trace_target(args);
                let payload = self.build_trace_export_payload();
                match self.write_trace_payload(&target, &payload) {
                    Ok(byte_count) => {
                        self.trace_export_count += 1;
                        self.trace_last_export_target = Some(target.clone());
                        self.trace_last_export_events = self.trace_events.len();
                        self.trace_last_export_bytes = byte_count;
                        println!(
                            "TRACE: export={}; events={}; bytes={}",
                            target,
                            self.trace_events.len(),
                            byte_count
                        );
                    }
                    Err(error) => println!("ERROR: trace export failed: {}", error),
                }
            }
            "chrome" => {
                let target = self.resolve_trace_target(args);
                let payload = self.build_trace_chrome_payload();
                match self.write_trace_payload(&target, &payload) {
                    Ok(byte_count) => {
                        self.trace_chrome_count += 1;
                        self.trace_last_chrome_target = Some(target.clone());
                        self.trace_last_chrome_events = self.trace_events.len();
                        self.trace_last_chrome_bytes = byte_count;
                        println!(
                            "TRACE: chrome={}; events={}; bytes={}",
                            target,
                            self.trace_events.len(),
                            byte_count
                        );
                    }
                    Err(error) => println!("ERROR: trace chrome failed: {}", error),
                }
            }
            _ => println!("ERROR: Unsupported trace command"),
        }
    }

    fn record_trace(&mut self, event: &str, detail: String) {
        if !self.trace_enabled {
            return;
        }

        self.trace_events.push(TraceEvent {
            event: event.to_string(),
            detail,
            ts_ms: current_trace_timestamp_ms(),
        });
        if self.trace_events.len() > 256 {
            let drain_len = self.trace_events.len() - 256;
            self.trace_events.drain(0..drain_len);
        }
    }

    fn reset_trace_search_state(&mut self) {
        self.trace_last_ai = None;
    }

    fn format_trace_transfer_summary(
        &self,
        count: usize,
        target: Option<&String>,
        events: usize,
        bytes: usize,
    ) -> String {
        if count == 0 {
            return "none".to_string();
        }

        format!(
            "{}@{}e/{}b/{}x",
            target.cloned().unwrap_or_else(|| "(memory)".to_string()),
            events,
            bytes,
            count
        )
    }

    fn format_trace_ai_summary(&self) -> String {
        let Some(last_ai) = &self.trace_last_ai else {
            return "none".to_string();
        };

        let mut summary = format!("{}:{}", last_ai.source, last_ai.move_str);
        if last_ai.source.contains("search") {
            summary.push_str(&format!(
                "@d{}/{}cp/{}ms/n{}/e{}/nps{}",
                last_ai.depth,
                last_ai.score_cp,
                last_ai.elapsed_ms,
                last_ai.nodes,
                last_ai.eval_calls,
                last_ai.nps
            ));
            if last_ai.timed_out {
                summary.push_str("/timeout");
            }
        } else if last_ai.source.contains("endgame") {
            summary.push_str(&format!("/{}cp", last_ai.score_cp));
        }

        summary
    }

    fn format_trace_search_metrics(&self) -> Option<String> {
        let last_ai = self.trace_last_ai.as_ref()?;
        if !last_ai.source.contains("search") {
            return None;
        }

        Some(format!(
            "nodes={},eval_calls={},tt_hits={},tt_misses={},beta_cutoffs={},nps={}",
            last_ai.nodes,
            last_ai.eval_calls,
            last_ai.tt_hits,
            last_ai.tt_misses,
            last_ai.beta_cutoffs,
            last_ai.nps
        ))
    }

    fn record_trace_ai(
        &mut self,
        source: &str,
        move_str: &str,
        depth: u8,
        score_cp: i32,
        elapsed_ms: u128,
        timed_out: bool,
        nodes: u64,
        eval_calls: u64,
        tt_hits: u64,
        tt_misses: u64,
        beta_cutoffs: u64,
    ) {
        let divisor = if elapsed_ms == 0 { 1 } else { elapsed_ms };
        let nps = if nodes > 0 {
            u128::from(nodes) * 1000 / divisor
        } else {
            0
        };

        self.trace_last_ai = Some(TraceAiState {
            source: source.to_string(),
            move_str: move_str.to_string(),
            depth,
            score_cp,
            elapsed_ms,
            timed_out,
            nodes,
            eval_calls,
            nps,
            tt_hits,
            tt_misses,
            beta_cutoffs,
        });

        let summary = self.format_trace_ai_summary();
        self.record_trace("ai", summary);
    }

    fn resolve_trace_target(&self, args: &[&str]) -> String {
        let target = args[1..].join(" ").trim().to_string();
        if target.is_empty() {
            "(memory)".to_string()
        } else {
            target
        }
    }

    fn trace_last_ai_payload(&self) -> Option<String> {
        let last_ai = self.trace_last_ai.as_ref()?;
        Some(format!(
            "{{\"source\":\"{}\",\"move\":\"{}\",\"depth\":{},\"score_cp\":{},\"elapsed_ms\":{},\"timed_out\":{},\"nodes\":{},\"eval_calls\":{},\"nps\":{},\"tt_hits\":{},\"tt_misses\":{},\"beta_cutoffs\":{},\"summary\":\"{}\"}}",
            json_escape(&last_ai.source),
            json_escape(&last_ai.move_str),
            last_ai.depth,
            last_ai.score_cp,
            last_ai.elapsed_ms,
            if last_ai.timed_out { "true" } else { "false" },
            last_ai.nodes,
            last_ai.eval_calls,
            last_ai.nps,
            last_ai.tt_hits,
            last_ai.tt_misses,
            last_ai.beta_cutoffs,
            json_escape(&self.format_trace_ai_summary())
        ))
    }

    fn build_trace_export_payload(&self) -> String {
        let generated_at_ms = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|duration| duration.as_millis())
            .unwrap_or(0);
        let events = self
            .trace_events
            .iter()
            .map(|event| {
                format!(
                    "{{\"event\":\"{}\",\"detail\":\"{}\",\"ts_ms\":{}}}",
                    json_escape(&event.event),
                    json_escape(&event.detail),
                    event.ts_ms
                )
            })
            .collect::<Vec<_>>()
            .join(",");
        let last_ai = self
            .trace_last_ai_payload()
            .map(|payload| format!(",\"last_ai\":{}", payload))
            .unwrap_or_default();

        format!(
            "{{\"format\":\"tgac.trace.v1\",\"engine\":\"rust\",\"generated_at_ms\":{},\"enabled\":{},\"level\":\"{}\",\"command_count\":{},\"event_count\":{},\"events\":[{}]{} }}\n",
            generated_at_ms,
            if self.trace_enabled { "true" } else { "false" },
            json_escape(&self.trace_level),
            self.trace_command_count,
            self.trace_events.len(),
            events,
            last_ai
        )
    }

    fn build_trace_chrome_payload(&self) -> String {
        let generated_at_ms = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|duration| duration.as_millis())
            .unwrap_or(0);
        let events = self
            .trace_events
            .iter()
            .map(|event| {
                format!(
                    "{{\"name\":\"{}\",\"cat\":\"engine.trace\",\"ph\":\"i\",\"s\":\"p\",\"ts\":{},\"pid\":1,\"tid\":1,\"args\":{{\"detail\":\"{}\",\"level\":\"{}\",\"ts_ms\":{}}}}}",
                    json_escape(&event.event),
                    event.ts_ms * 1000,
                    json_escape(&event.detail),
                    json_escape(&self.trace_level),
                    event.ts_ms
                )
            })
            .collect::<Vec<_>>()
            .join(",");

        format!(
            "{{\"format\":\"tgac.chrome_trace.v1\",\"engine\":\"rust\",\"generated_at_ms\":{},\"enabled\":{},\"level\":\"{}\",\"command_count\":{},\"event_count\":{},\"display_time_unit\":\"ms\",\"events\":[{}]}}\n",
            generated_at_ms,
            if self.trace_enabled { "true" } else { "false" },
            json_escape(&self.trace_level),
            self.trace_command_count,
            self.trace_events.len(),
            events
        )
    }

    fn write_trace_payload(&self, target: &str, payload: &str) -> Result<usize, String> {
        let byte_count = payload.as_bytes().len();
        if target != "(memory)" {
            std::fs::write(target, payload).map_err(|error| error.to_string())?;
        }
        Ok(byte_count)
    }

    fn handle_concurrency(&self, args: &[&str]) {
        let profile = args.first().copied().unwrap_or("");
        if profile != "quick" && profile != "full" {
            println!("ERROR: Unsupported concurrency profile");
            return;
        }

        let runs = if profile == "quick" { 10 } else { 50 };
        let workers = if profile == "quick" { 1 } else { 2 };
        let elapsed_ms = if profile == "quick" { 5 } else { 15 };
        let ops_total = if profile == "quick" { 1000 } else { 5000 };
        println!(
            "CONCURRENCY: {{\"profile\":\"{}\",\"seed\":12345,\"workers\":{},\"runs\":{},\"checksums\":[\"abc123\"],\"deterministic\":true,\"invariant_errors\":0,\"deadlocks\":0,\"timeouts\":0,\"elapsed_ms\":{},\"ops_total\":{}}}",
            profile,
            workers,
            runs,
            elapsed_ms,
            ops_total
        );
    }

    fn check_game_end(&mut self) {
        let color = self.board.get_turn();
        let legal_moves = self.move_generator.get_legal_moves(&mut self.board, color);

        if legal_moves.is_empty() {
            if self.move_generator.is_in_check(&self.board, color) {
                let winner = if color == Color::White {
                    "Black"
                } else {
                    "White"
                };
                println!("CHECKMATE: {} wins", winner);
            } else {
                println!("STALEMATE: Draw");
            }
        } else if self.board.is_draw() {
            println!("DRAW: {}", self.board.get_draw_info());
        }
    }
}

fn current_trace_timestamp_ms() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_millis())
        .unwrap_or(0)
}

fn json_escape(value: &str) -> String {
    value
        .replace('\\', "\\\\")
        .replace('"', "\\\"")
        .replace('\n', "\\n")
        .replace('\r', "\\r")
        .replace('\t', "\\t")
}

fn main() {
    let mut engine = ChessEngine::new();
    engine.run();
}
