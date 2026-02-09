use crate::board::Board;
use crate::types::{Color, PieceType, Square};

const BISHOP_PAIR_BONUS: i32 = 30;
const ROOK_OPEN_FILE_BONUS: i32 = 25;
const ROOK_SEMI_OPEN_FILE_BONUS: i32 = 15;
const ROOK_SEVENTH_RANK_BONUS: i32 = 20;
const KNIGHT_OUTPOST_BONUS: i32 = 20;

pub fn evaluate(board: &Board) -> i32 {
    let mut score = 0;
    
    score += evaluate_color(board, Color::White);
    score -= evaluate_color(board, Color::Black);
    
    score
}

fn evaluate_color(board: &Board, color: Color) -> i32 {
    let mut score = 0;
    
    if has_bishop_pair(board, color) {
        score += BISHOP_PAIR_BONUS;
    }
    
    for square in 0..64 {
        if let Some(piece) = board.get_piece(square) {
            if piece.color == color {
                match piece.piece_type {
                    PieceType::Rook => {
                        score += evaluate_rook(board, square, color);
                    },
                    PieceType::Knight => {
                        score += evaluate_knight(board, square, color);
                    },
                    _ => {},
                }
            }
        }
    }
    
    score
}

fn has_bishop_pair(board: &Board, color: Color) -> bool {
    let mut bishop_count = 0;
    
    for square in 0..64 {
        if let Some(piece) = board.get_piece(square) {
            if piece.color == color && piece.piece_type == PieceType::Bishop {
                bishop_count += 1;
            }
        }
    }
    
    bishop_count >= 2
}

fn evaluate_rook(board: &Board, square: Square, color: Color) -> i32 {
    let file = square % 8;
    let rank = square / 8;
    let mut bonus = 0;
    
    let (own_pawns, enemy_pawns) = count_pawns_on_file(board, file, color);
    
    if own_pawns == 0 && enemy_pawns == 0 {
        bonus += ROOK_OPEN_FILE_BONUS;
    } else if own_pawns == 0 {
        bonus += ROOK_SEMI_OPEN_FILE_BONUS;
    }
    
    let seventh_rank = if color == Color::White { 6 } else { 1 };
    if rank == seventh_rank {
        bonus += ROOK_SEVENTH_RANK_BONUS;
    }
    
    bonus
}

fn evaluate_knight(board: &Board, square: Square, color: Color) -> i32 {
    if is_outpost(board, square, color) {
        KNIGHT_OUTPOST_BONUS
    } else {
        0
    }
}

fn is_outpost(board: &Board, square: Square, color: Color) -> bool {
    let file = square % 8;
    let rank = square / 8;
    
    let protected_by_pawn = is_protected_by_pawn(board, square, color);
    if !protected_by_pawn {
        return false;
    }
    
    let cannot_be_attacked = !can_be_attacked_by_enemy_pawn(board, square, file, rank, color);
    
    protected_by_pawn && cannot_be_attacked
}

fn is_protected_by_pawn(board: &Board, square: Square, color: Color) -> bool {
    let file = square % 8;
    let rank = square / 8;
    
    let behind_rank = if color == Color::White {
        rank.saturating_sub(1)
    } else {
        (rank + 1).min(7)
    };
    
    for adjacent_file in [file.saturating_sub(1), (file + 1).min(7)].iter() {
        if *adjacent_file != file {
            let check_square = behind_rank * 8 + adjacent_file;
            if let Some(piece) = board.get_piece(check_square) {
                if piece.color == color && piece.piece_type == PieceType::Pawn {
                    return true;
                }
            }
        }
    }
    
    false
}

fn can_be_attacked_by_enemy_pawn(board: &Board, square: Square, file: Square, rank: Square, color: Color) -> bool {
    let ahead_ranks = if color == Color::White {
        rank + 1..8
    } else {
        0..rank
    };
    
    for check_rank in ahead_ranks {
        for adjacent_file in [file.saturating_sub(1), (file + 1).min(7)].iter() {
            if *adjacent_file != file {
                let check_square = check_rank * 8 + adjacent_file;
                if let Some(piece) = board.get_piece(check_square) {
                    if piece.color != color && piece.piece_type == PieceType::Pawn {
                        return true;
                    }
                }
            }
        }
    }
    
    false
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
