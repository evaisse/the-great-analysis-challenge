use crate::board::Board;
use crate::types::{Color, PieceType, Square};

const PAWN_SHIELD_BONUS: i32 = 20;
const OPEN_FILE_PENALTY: i32 = -30;
const SEMI_OPEN_FILE_PENALTY: i32 = -15;
const ATTACKER_WEIGHT: i32 = 10;

pub fn evaluate(board: &Board) -> i32 {
    let mut score = 0;
    
    score += evaluate_king_safety(board, Color::White);
    score -= evaluate_king_safety(board, Color::Black);
    
    score
}

fn evaluate_king_safety(board: &Board, color: Color) -> i32 {
    let king_square = find_king(board, color);
    if king_square.is_none() {
        return 0;
    }
    
    let king_square = king_square.unwrap();
    let mut score = 0;
    
    score += evaluate_pawn_shield(board, king_square, color);
    score += evaluate_open_files(board, king_square, color);
    score -= evaluate_attackers(board, king_square, color);
    
    score
}

fn find_king(board: &Board, color: Color) -> Option<Square> {
    for square in 0..64 {
        if let Some(piece) = board.get_piece(square) {
            if piece.color == color && piece.piece_type == PieceType::King {
                return Some(square);
            }
        }
    }
    None
}

fn evaluate_pawn_shield(board: &Board, king_square: Square, color: Color) -> i32 {
    let king_file = king_square % 8;
    let king_rank = king_square / 8;
    let mut shield_count = 0;
    
    let shield_ranks = if color == Color::White {
        [king_rank + 1, king_rank + 2]
    } else {
        [king_rank.saturating_sub(1), king_rank.saturating_sub(2)]
    };
    
    for file in (king_file.saturating_sub(1))..=(king_file + 1).min(7) {
        for rank in shield_ranks.iter() {
            if *rank < 8 {
                let square = rank * 8 + file;
                if let Some(piece) = board.get_piece(square) {
                    if piece.color == color && piece.piece_type == PieceType::Pawn {
                        shield_count += 1;
                    }
                }
            }
        }
    }
    
    shield_count * PAWN_SHIELD_BONUS
}

fn evaluate_open_files(board: &Board, king_square: Square, color: Color) -> i32 {
    let king_file = king_square % 8;
    let mut penalty = 0;
    
    for file in (king_file.saturating_sub(1))..=(king_file + 1).min(7) {
        let (own_pawns, enemy_pawns) = count_pawns_on_file(board, file, color);
        
        if own_pawns == 0 && enemy_pawns == 0 {
            penalty += OPEN_FILE_PENALTY;
        } else if own_pawns == 0 {
            penalty += SEMI_OPEN_FILE_PENALTY;
        }
    }
    
    penalty
}

fn count_pawns_on_file(board: &Board, file: Square, color: Color) -> (i32, i32) {
    let mut own_pawns = 0;
    let mut enemy_pawns = 0;
    
    for rank in 0..8 {
        let square = rank * 8 + file;
        if let Some(piece) = board.get_piece(square) {
            if piece.piece_type == PieceType::Pawn {
                if piece.color == color {
                    own_pawns += 1;
                } else {
                    enemy_pawns += 1;
                }
            }
        }
    }
    
    (own_pawns, enemy_pawns)
}

fn evaluate_attackers(board: &Board, king_square: Square, color: Color) -> i32 {
    let king_file = king_square % 8;
    let king_rank = king_square / 8;
    let mut attacker_count = 0;
    
    let adjacent_squares = [
        (-1, -1), (-1, 0), (-1, 1),
        (0, -1),           (0, 1),
        (1, -1),  (1, 0),  (1, 1),
    ];
    
    for (dr, df) in adjacent_squares.iter() {
        let new_rank = king_rank as i32 + dr;
        let new_file = king_file as i32 + df;
        
        if new_rank >= 0 && new_rank < 8 && new_file >= 0 && new_file < 8 {
            let target_square = (new_rank * 8 + new_file) as Square;
            if is_attacked_by_enemy(board, target_square, color) {
                attacker_count += 1;
            }
        }
    }
    
    attacker_count * ATTACKER_WEIGHT
}

fn is_attacked_by_enemy(board: &Board, square: Square, color: Color) -> bool {
    for attacker_square in 0..64 {
        if let Some(piece) = board.get_piece(attacker_square) {
            if piece.color != color {
                if can_attack(board, attacker_square, square, piece.piece_type, piece.color) {
                    return true;
                }
            }
        }
    }
    false
}

fn can_attack(board: &Board, from: Square, to: Square, piece_type: PieceType, color: Color) -> bool {
    let from_rank = (from / 8) as i32;
    let from_file = (from % 8) as i32;
    let to_rank = (to / 8) as i32;
    let to_file = (to % 8) as i32;
    let rank_diff = (to_rank - from_rank).abs();
    let file_diff = (to_file - from_file).abs();
    
    match piece_type {
        PieceType::Pawn => {
            let forward = if color == Color::White { 1 } else { -1 };
            to_rank - from_rank == forward && file_diff == 1
        },
        PieceType::Knight => {
            (rank_diff == 2 && file_diff == 1) || (rank_diff == 1 && file_diff == 2)
        },
        PieceType::King => {
            rank_diff <= 1 && file_diff <= 1
        },
        _ => false,
    }
}
