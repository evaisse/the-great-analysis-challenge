use crate::board::Board;
use crate::types::{Color, PieceType, Square};

const PASSED_PAWN_BONUS: [i32; 8] = [0, 10, 20, 40, 60, 90, 120, 0];
const DOUBLED_PAWN_PENALTY: i32 = -20;
const ISOLATED_PAWN_PENALTY: i32 = -15;
const BACKWARD_PAWN_PENALTY: i32 = -10;
const CONNECTED_PAWN_BONUS: i32 = 5;
const PAWN_CHAIN_BONUS: i32 = 10;

pub fn evaluate(board: &Board) -> i32 {
    let mut score = 0;
    
    score += evaluate_color(board, Color::White);
    score -= evaluate_color(board, Color::Black);
    
    score
}

fn evaluate_color(board: &Board, color: Color) -> i32 {
    let mut score = 0;
    let mut pawn_files = [0u8; 8];
    let mut pawn_positions = Vec::new();
    
    for square in 0..64 {
        if let Some(piece) = board.get_piece(square) {
            if piece.color == color && piece.piece_type == PieceType::Pawn {
                let file = square % 8;
                let rank = square / 8;
                pawn_files[file as usize] += 1;
                pawn_positions.push((square, rank, file));
            }
        }
    }
    
    for (square, rank, file) in pawn_positions.iter() {
        if pawn_files[*file as usize] > 1 {
            score += DOUBLED_PAWN_PENALTY;
        }
        
        if is_isolated(*file, &pawn_files) {
            score += ISOLATED_PAWN_PENALTY;
        }
        
        if is_passed(board, *square, *rank, *file, color) {
            let bonus_rank = if color == Color::White { *rank } else { 7 - *rank };
            score += PASSED_PAWN_BONUS[bonus_rank as usize];
        }
        
        if is_connected(board, *square, *file, color) {
            score += CONNECTED_PAWN_BONUS;
        }
        
        if is_in_chain(board, *square, *rank, *file, color) {
            score += PAWN_CHAIN_BONUS;
        }
        
        if is_backward(board, *square, *rank, *file, color, &pawn_files) {
            score += BACKWARD_PAWN_PENALTY;
        }
    }
    
    score
}

fn is_isolated(file: Square, pawn_files: &[u8; 8]) -> bool {
    let left_file = if file > 0 { pawn_files[(file - 1) as usize] } else { 0 };
    let right_file = if file < 7 { pawn_files[(file + 1) as usize] } else { 0 };
    left_file == 0 && right_file == 0
}

fn is_passed(board: &Board, square: Square, rank: Square, file: Square, color: Color) -> bool {
    let (start_rank, end_rank, direction) = if color == Color::White {
        (rank + 1, 8, 1)
    } else {
        (0, rank, -1)
    };
    
    for check_file in (file.saturating_sub(1))..=(file + 1).min(7) {
        let mut current_rank = start_rank;
        loop {
            if color == Color::White {
                if current_rank >= end_rank { break; }
            } else {
                if current_rank >= rank { break; }
            }
            
            let check_square = current_rank * 8 + check_file;
            if let Some(piece) = board.get_piece(check_square) {
                if piece.piece_type == PieceType::Pawn && piece.color != color {
                    return false;
                }
            }
            
            current_rank = if direction > 0 { current_rank + 1 } else { current_rank.saturating_sub(1) };
            if direction < 0 && current_rank == 0 { break; }
        }
    }
    
    true
}

fn is_connected(board: &Board, square: Square, file: Square, color: Color) -> bool {
    let rank = square / 8;
    
    for adjacent_file in [file.saturating_sub(1), (file + 1).min(7)].iter() {
        if *adjacent_file != file {
            let adjacent_square = rank * 8 + adjacent_file;
            if let Some(piece) = board.get_piece(adjacent_square) {
                if piece.color == color && piece.piece_type == PieceType::Pawn {
                    return true;
                }
            }
        }
    }
    
    false
}

fn is_in_chain(board: &Board, square: Square, rank: Square, file: Square, color: Color) -> bool {
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

fn is_backward(board: &Board, square: Square, rank: Square, file: Square, color: Color, pawn_files: &[u8; 8]) -> bool {
    let left_file = file.saturating_sub(1);
    let right_file = (file + 1).min(7);
    
    for adjacent_file in [left_file, right_file].iter() {
        if *adjacent_file != file && pawn_files[*adjacent_file as usize] > 0 {
            for check_square in 0..64 {
                if let Some(piece) = board.get_piece(check_square) {
                    if piece.color == color && piece.piece_type == PieceType::Pawn {
                        let check_file = check_square % 8;
                        let check_rank = check_square / 8;
                        
                        if check_file == *adjacent_file {
                            let is_ahead = if color == Color::White {
                                check_rank > rank
                            } else {
                                check_rank < rank
                            };
                            
                            if is_ahead {
                                return false;
                            }
                        }
                    }
                }
            }
        }
    }
    
    false
}
