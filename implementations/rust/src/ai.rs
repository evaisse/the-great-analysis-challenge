use crate::types::*;
use crate::board::Board;
use crate::move_generator::MoveGenerator;
use crate::eval::RichEvaluator;
use std::time::Instant;

pub struct AI {
    move_generator: MoveGenerator,
    nodes_evaluated: u64,
    use_rich_eval: bool,
    rich_evaluator: Option<RichEvaluator>,
}

#[derive(Debug)]
pub struct SearchResult {
    pub best_move: Option<Move>,
    pub evaluation: i32,
    pub nodes: u64,
    pub time_ms: u128,
}

impl AI {
    pub fn new(use_rich_eval: bool) -> Self {
        Self {
            move_generator: MoveGenerator::new(),
            nodes_evaluated: 0,
            use_rich_eval,
            rich_evaluator: if use_rich_eval {
                Some(RichEvaluator::new())
            } else {
                None
            },
        }
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

    fn minimax(&mut self, board: &Board, depth: u8, alpha: i32, beta: i32, maximizing: bool) -> i32 {
        self.nodes_evaluated += 1;

        if depth == 0 {
            return self.evaluate(board);
        }

        let color = board.get_turn();
        let moves = self.move_generator.get_legal_moves(board, color);

        if moves.is_empty() {
            if self.move_generator.is_in_check(board, color) {
                // Checkmate
                return if maximizing { -100000 } else { 100000 };
            } else {
                // Stalemate
                return 0;
            }
        }

        if maximizing {
            let mut max_eval = i32::MIN;
            let mut current_alpha = alpha;
            
            for chess_move in &moves {
                let mut board_copy = board.get_state().clone();
                let mut test_board = Board::new();
                test_board.set_state(board_copy);
                test_board.make_move(chess_move);
                
                let evaluation = self.minimax(&test_board, depth - 1, current_alpha, beta, false);
                max_eval = max_eval.max(evaluation);
                current_alpha = current_alpha.max(evaluation);
                
                if beta <= current_alpha {
                    break; // Beta cutoff
                }
            }
            
            max_eval
        } else {
            let mut min_eval = i32::MAX;
            let mut current_beta = beta;
            
            for chess_move in &moves {
                let mut board_copy = board.get_state().clone();
                let mut test_board = Board::new();
                test_board.set_state(board_copy);
                test_board.make_move(chess_move);
                
                let evaluation = self.minimax(&test_board, depth - 1, alpha, current_beta, true);
                min_eval = min_eval.min(evaluation);
                current_beta = current_beta.min(evaluation);
                
                if current_beta <= alpha {
                    break; // Alpha cutoff
                }
            }
            
            min_eval
        }
    }

    fn evaluate(&self, board: &Board) -> i32 {
        if self.use_rich_eval {
            if let Some(ref evaluator) = self.rich_evaluator {
                return evaluator.evaluate(board);
            }
        }
        
        // Simple evaluation (fallback or default)
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