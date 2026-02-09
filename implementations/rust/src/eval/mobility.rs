use crate::board::Board;
use crate::types::{Color, PieceType, Square};
use crate::move_generator::MoveGenerator;

const KNIGHT_MOBILITY: [i32; 9] = [-15, -5, 0, 5, 10, 15, 20, 22, 24];
const BISHOP_MOBILITY: [i32; 14] = [-20, -10, 0, 5, 10, 15, 18, 21, 24, 26, 28, 30, 32, 34];
const ROOK_MOBILITY: [i32; 15] = [-15, -8, 0, 3, 6, 9, 12, 14, 16, 18, 20, 22, 24, 26, 28];
const QUEEN_MOBILITY: [i32; 28] = [
    -10, -5, 0, 2, 4, 6, 8, 10, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 22, 23, 23, 24, 24, 25, 25, 26, 26
];

pub fn evaluate(board: &Board) -> i32 {
    let mut score = 0;
    let mg = MoveGenerator::new();
    
    for square in 0..64 {
        if let Some(piece) = board.get_piece(square) {
            let mobility = match piece.piece_type {
                PieceType::Knight => count_knight_mobility(board, square, piece.color),
                PieceType::Bishop => count_bishop_mobility(board, square, piece.color),
                PieceType::Rook => count_rook_mobility(board, square, piece.color),
                PieceType::Queen => count_queen_mobility(board, square, piece.color),
                _ => continue,
            };
            
            let bonus = get_mobility_bonus(piece.piece_type, mobility);
            score += if piece.color == Color::White { bonus } else { -bonus };
        }
    }
    
    score
}

fn count_knight_mobility(board: &Board, square: Square, _color: Color) -> usize {
    let offsets: [(i32, i32); 8] = [
        (-2, -1), (-2, 1), (-1, -2), (-1, 2),
        (1, -2), (1, 2), (2, -1), (2, 1),
    ];
    
    let rank = (square / 8) as i32;
    let file = (square % 8) as i32;
    let mut count = 0;
    
    for (dr, df) in offsets.iter() {
        let new_rank = rank + dr;
        let new_file = file + df;
        
        if new_rank >= 0 && new_rank < 8 && new_file >= 0 && new_file < 8 {
            let target = ((new_rank * 8 + new_file) as usize);
            if let Some(target_piece) = board.get_piece(target) {
                if target_piece.color != board.get_piece(square).unwrap().color {
                    count += 1;
                }
            } else {
                count += 1;
            }
        }
    }
    
    count
}

fn count_bishop_mobility(board: &Board, square: Square, color: Color) -> usize {
    count_sliding_mobility(board, square, color, &[(1, 1), (1, -1), (-1, 1), (-1, -1)])
}

fn count_rook_mobility(board: &Board, square: Square, color: Color) -> usize {
    count_sliding_mobility(board, square, color, &[(0, 1), (0, -1), (1, 0), (-1, 0)])
}

fn count_queen_mobility(board: &Board, square: Square, color: Color) -> usize {
    count_sliding_mobility(board, square, color, &[
        (0, 1), (0, -1), (1, 0), (-1, 0),
        (1, 1), (1, -1), (-1, 1), (-1, -1),
    ])
}

fn count_sliding_mobility(board: &Board, square: Square, color: Color, directions: &[(i32, i32)]) -> usize {
    let rank = (square / 8) as i32;
    let file = (square % 8) as i32;
    let mut count = 0;
    
    for (dr, df) in directions.iter() {
        let mut current_rank = rank + dr;
        let mut current_file = file + df;
        
        while current_rank >= 0 && current_rank < 8 && current_file >= 0 && current_file < 8 {
            let target = ((current_rank * 8 + current_file) as usize);
            
            if let Some(target_piece) = board.get_piece(target) {
                if target_piece.color != color {
                    count += 1;
                }
                break;
            } else {
                count += 1;
            }
            
            current_rank += dr;
            current_file += df;
        }
    }
    
    count
}

fn get_mobility_bonus(piece_type: PieceType, mobility: usize) -> i32 {
    match piece_type {
        PieceType::Knight => KNIGHT_MOBILITY[mobility.min(8)],
        PieceType::Bishop => BISHOP_MOBILITY[mobility.min(13)],
        PieceType::Rook => ROOK_MOBILITY[mobility.min(14)],
        PieceType::Queen => QUEEN_MOBILITY[mobility.min(27)],
        _ => 0,
    }
}
