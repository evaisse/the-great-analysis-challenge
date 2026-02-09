pub mod tables;
pub mod tapered;
pub mod mobility;
pub mod pawn_structure;
pub mod king_safety;
pub mod positional;

use crate::board::Board;

pub struct RichEvaluator;

impl RichEvaluator {
    pub fn new() -> Self {
        Self
    }

    pub fn evaluate(&self, board: &Board) -> i32 {
        let phase = self.compute_phase(board);
        
        let mg_score = self.evaluate_phase(board, true);
        let eg_score = self.evaluate_phase(board, false);
        
        let tapered_score = tapered::interpolate(mg_score, eg_score, phase);
        
        let mobility_score = mobility::evaluate(board);
        let pawn_score = pawn_structure::evaluate(board);
        let king_score = king_safety::evaluate(board);
        let positional_score = positional::evaluate(board);
        
        tapered_score + mobility_score + pawn_score + king_score + positional_score
    }

    fn compute_phase(&self, board: &Board) -> i32 {
        use crate::types::PieceType;
        
        let mut phase = 0;
        for square in 0..64 {
            if let Some(piece) = board.get_piece(square) {
                phase += match piece.piece_type {
                    PieceType::Knight => 1,
                    PieceType::Bishop => 1,
                    PieceType::Rook => 2,
                    PieceType::Queen => 4,
                    _ => 0,
                };
            }
        }
        
        phase.min(24)
    }

    fn evaluate_phase(&self, board: &Board, middlegame: bool) -> i32 {
        use crate::types::Color;
        
        let mut score = 0;
        
        for square in 0..64 {
            if let Some(piece) = board.get_piece(square) {
                let value = piece.piece_type.value();
                let position_bonus = if middlegame {
                    tables::get_middlegame_bonus(square, piece.piece_type, piece.color)
                } else {
                    tables::get_endgame_bonus(square, piece.piece_type, piece.color)
                };
                
                let total_value = value + position_bonus;
                score += if piece.color == Color::White { total_value } else { -total_value };
            }
        }
        
        score
    }
}
