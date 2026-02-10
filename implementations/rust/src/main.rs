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
use std::io::{self, Write};
use std::time::Instant;

struct ChessEngine {
    board: Board,
    move_generator: MoveGenerator,
    fen_parser: FenParser,
    ai: AI,
    perft: Perft,
}

impl ChessEngine {
    fn new() -> Self {
        Self {
            board: Board::new(),
            move_generator: MoveGenerator::new(),
            fen_parser: FenParser::new(),
            ai: AI::new(),
            perft: Perft::new(),
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

        match parts[0].to_lowercase().as_str() {
            "move" => {
                if parts.len() > 1 {
                    self.handle_move(parts[1]);
                } else {
                    println!("ERROR: Invalid move format");
                }
            },
            "undo" => self.handle_undo(),
            "new" => self.handle_new(),
            "status" => self.handle_status(),
            "ai" => {
                if parts.len() > 1 {
                    self.handle_ai(parts[1]);
                } else {
                    println!("ERROR: AI depth must be 1-5");
                }
            },
            "fen" => {
                if parts.len() > 1 {
                    let fen_string = parts[1..].join(" ");
                    self.handle_fen(&fen_string);
                } else {
                    println!("ERROR: Invalid FEN string");
                }
            },
            "export" => self.handle_export(),
            "eval" => self.handle_eval(),
            "hash" => self.handle_hash(),
            "draws" => self.handle_draws(),
            "history" => self.handle_history(),
            "perft" => {
                if parts.len() > 1 {
                    self.handle_perft(parts[1]);
                } else {
                    println!("ERROR: Invalid perft depth");
                }
            },
            "divide" => {
                if parts.len() > 1 {
                    self.handle_divide(parts[1]);
                } else {
                    println!("ERROR: Invalid perft depth");
                }
            },
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
                        if let Some(promo_type) = PieceType::from_char(promo_str.chars().next().unwrap_or(' ')) {
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
            },
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
            },
            None => println!("ERROR: No moves to undo"),
        }
    }

    fn handle_new(&mut self) {
        self.board.reset();
        println!("OK: New game started");
        println!("{}", self.board);
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
            Ok(d) if d >= 1 && d <= 5 => d,
            _ => {
                println!("ERROR: AI depth must be 1-5");
                return;
            }
        };

        let result = self.ai.find_best_move(&mut self.board, depth);
        
        match result.best_move {
            Some(chess_move) => {
                let move_str = format!("{}{}{}", 
                    square_to_algebraic(chess_move.from),
                    square_to_algebraic(chess_move.to),
                    chess_move.promotion.map_or(String::new(), |p| p.to_string())
                );
                
                self.board.make_move(&chess_move);
                println!("AI: {} (depth={}, eval={}, time={}ms)", 
                    move_str, depth, result.evaluation, result.time_ms);
                println!("{}", self.board);
                self.check_game_end();
            },
            None => println!("ERROR: No legal moves available"),
        }
    }

    fn handle_fen(&mut self, fen_string: &str) {
        match self.fen_parser.parse_fen(&mut self.board, fen_string) {
            Ok(_) => {
                println!("OK: FEN loaded");
                println!("{}", self.board);
            },
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
        println!("{}", self.board.get_draw_info());
    }

    fn handle_history(&self) {
        let state = self.board.get_state();
        println!("Position History ({} positions):", state.position_history.len() + 1);
        for (i, hash) in state.position_history.iter().enumerate() {
            println!("  {}: {:016x}", i, hash);
        }
        println!("  {}: {:016x} (current)", state.position_history.len(), state.zobrist_hash);
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
        println!("  fen <string> - Load position from FEN");
        println!("  export - Export current position as FEN");
        println!("  eval - Evaluate current position");
        println!("  hash - Show Zobrist hash of current position");
        println!("  draws - Show draw detection status");
        println!("  history - Show position hash history");
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