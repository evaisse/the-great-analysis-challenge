use crate::types::*;
use crate::board::Board;
use crate::move_generator::MoveGenerator;
use crate::transposition_table::{TranspositionTable, BoundType, encode_move};
use std::time::Instant;

pub struct AI {
    move_generator: MoveGenerator,
    nodes_evaluated: u64,
    tt: TranspositionTable,
}

#[derive(Debug)]
pub struct SearchResult {
    pub best_move: Option<Move>,
    pub evaluation: i32,
    pub nodes: u64,
    pub time_ms: u128,
}

impl AI {
    pub fn new() -> Self {
        Self {
            move_generator: MoveGenerator::new(),
            nodes_evaluated: 0,
            tt: TranspositionTable::new(16),
        }
    }

    pub fn get_tt(&self) -> &TranspositionTable {
        &self.tt
    }

    pub fn get_tt_mut(&mut self) -> &mut TranspositionTable {
        &mut self.tt
    }

    pub fn find_best_move(&mut self, board: &Board, depth: u8) -> SearchResult {
        let start_time = Instant::now();
        self.nodes_evaluated = 0;
        
        let color = board.get_turn();
        let moves = self.move_generator.get_legal_moves(board, color);
        
        if moves.is_empty() {
            return SearchResult {
                best_move: None,
                evaluation: 0,
                nodes: 0,
                time_ms: 0,
            };
        }

        let mut best_move = moves[0].clone();
        let mut best_eval = if color == Color::White { i32::MIN } else { i32::MAX };

        for chess_move in &moves {
            let mut board_copy = board.get_state().clone();
            let mut test_board = Board::new();
            test_board.set_state(board_copy);
            test_board.make_move(chess_move);
            
            let evaluation = self.minimax(&test_board, depth - 1, i32::MIN, i32::MAX, color == Color::Black);
            
            if (color == Color::White && evaluation > best_eval) || 
               (color == Color::Black && evaluation < best_eval) {
                best_eval = evaluation;
                best_move = chess_move.clone();
            }
        }

        let elapsed = start_time.elapsed();
        SearchResult {
            best_move: Some(best_move),
            evaluation: best_eval,
            nodes: self.nodes_evaluated,
            time_ms: elapsed.as_millis(),
        }
    }

    fn minimax(&mut self, board: &Board, depth: u8, mut alpha: i32, mut beta: i32, maximizing: bool) -> i32 {
        self.nodes_evaluated += 1;

        // Probe transposition table
        let hash = board.get_state().hash;
        let original_alpha = alpha;

        if let Some(tt_entry) = self.tt.probe(hash) {
            if tt_entry.depth >= depth {
                match tt_entry.bound {
                    BoundType::Exact => {
                        return tt_entry.score;
                    }
                    BoundType::LowerBound => {
                        alpha = alpha.max(tt_entry.score);
                    }
                    BoundType::UpperBound => {
                        beta = beta.min(tt_entry.score);
                    }
                }
                if alpha >= beta {
                    return tt_entry.score;
                }
            }
        }

        if depth == 0 {
            let score = self.evaluate(board);
            self.tt.store(hash, 0, score, BoundType::Exact, None);
            return score;
        }

        let color = board.get_turn();
        let moves = self.move_generator.get_legal_moves(board, color);

        if moves.is_empty() {
            let score = if self.move_generator.is_in_check(board, color) {
                // Checkmate
                if maximizing { -100000 } else { 100000 }
            } else {
                // Stalemate
                0
            };
            self.tt.store(hash, depth, score, BoundType::Exact, None);
            return score;
        }

        if maximizing {
            let mut max_eval = i32::MIN;
            let mut best_move: Option<u16> = None;
            
            for chess_move in &moves {
                let mut board_copy = board.get_state().clone();
                let mut test_board = Board::new();
                test_board.set_state(board_copy);
                test_board.make_move(chess_move);
                
                let evaluation = self.minimax(&test_board, depth - 1, alpha, beta, false);
                
                if evaluation > max_eval {
                    max_eval = evaluation;
                    best_move = Some(encode_move(chess_move.from, chess_move.to));
                }
                alpha = alpha.max(evaluation);
                
                if beta <= alpha {
                    break; // Beta cutoff
                }
            }
            
            // Determine bound type
            let bound = if max_eval <= original_alpha {
                BoundType::UpperBound
            } else if max_eval >= beta {
                BoundType::LowerBound
            } else {
                BoundType::Exact
            };
            
            self.tt.store(hash, depth, max_eval, bound, best_move);
            max_eval
        } else {
            let mut min_eval = i32::MAX;
            let mut best_move: Option<u16> = None;
            
            for chess_move in &moves {
                let mut board_copy = board.get_state().clone();
                let mut test_board = Board::new();
                test_board.set_state(board_copy);
                test_board.make_move(chess_move);
                
                let evaluation = self.minimax(&test_board, depth - 1, alpha, beta, true);
                
                if evaluation < min_eval {
                    min_eval = evaluation;
                    best_move = Some(encode_move(chess_move.from, chess_move.to));
                }
                beta = beta.min(evaluation);
                
                if beta <= alpha {
                    break; // Alpha cutoff
                }
            }
            
            // Determine bound type
            let bound = if min_eval <= alpha {
                BoundType::LowerBound
            } else if min_eval >= beta {
                BoundType::UpperBound
            } else {
                BoundType::Exact
            };
            
            self.tt.store(hash, depth, min_eval, bound, best_move);
            min_eval
        }
    }

    fn evaluate(&self, board: &Board) -> i32 {
        let mut score = 0;

        for square in 0..64 {
            if let Some(piece) = board.get_piece(square) {
                let value = piece.piece_type.value();
                let position_bonus = self.get_position_bonus(square, piece.piece_type, piece.color, board);
                let total_value = value + position_bonus;
                
                score += if piece.color == Color::White { total_value } else { -total_value };
            }
        }

        score
    }

    fn get_position_bonus(&self, square: Square, piece_type: PieceType, color: Color, board: &Board) -> i32 {
        let file = square % 8;
        let rank = square / 8;
        let mut bonus = 0;

        // Center control bonus
        let center_squares = [27, 28, 35, 36]; // d4, e4, d5, e5
        if center_squares.contains(&square) {
            bonus += 10;
        }

        match piece_type {
            PieceType::Pawn => {
                // Pawn advancement bonus
                let advancement = if color == Color::White { rank } else { 7 - rank };
                bonus += (advancement * 5) as i32;
            },
            PieceType::King => {
                // King safety in opening/middlegame
                if !self.is_endgame(board) {
                    let safe_rank = if color == Color::White { 0 } else { 7 };
                    if rank == safe_rank && (file <= 2 || file >= 5) {
                        bonus += 20;
                    } else {
                        bonus -= 20;
                    }
                }
            },
            _ => {}
        }

        bonus
    }

    fn is_endgame(&self, board: &Board) -> bool {
        let mut piece_count = 0;
        let mut queen_count = 0;
        
        for square in 0..64 {
            if let Some(piece) = board.get_piece(square) {
                if piece.piece_type != PieceType::King && piece.piece_type != PieceType::Pawn {
                    piece_count += 1;
                    if piece.piece_type == PieceType::Queen {
                        queen_count += 1;
                    }
                }
            }
        }
        
        piece_count <= 4 || (piece_count <= 6 && queen_count == 0)
    }
}