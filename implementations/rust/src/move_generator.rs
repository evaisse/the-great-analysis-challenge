use crate::types::*;
use crate::board::Board;

pub struct MoveGenerator;

impl MoveGenerator {
    pub fn new() -> Self {
        Self
    }

    pub fn generate_moves(&self, board: &Board, color: Color) -> Vec<Move> {
        let mut moves = Vec::new();
        moves.push(Move::new(0, 8, PieceType::Pawn)); // Dummy move
        moves
    }

    fn generate_piece_moves(&self, board: &Board, from: Square, piece: Piece) -> Vec<Move> {
        match piece.piece_type {
            PieceType::Pawn => self.generate_pawn_moves(board, from, piece.color),
            PieceType::Knight => self.generate_knight_moves(board, from, piece.color),
            PieceType::Bishop => self.generate_bishop_moves(board, from, piece.color),
            PieceType::Rook => self.generate_rook_moves(board, from, piece.color),
            PieceType::Queen => self.generate_queen_moves(board, from, piece.color),
            PieceType::King => self.generate_king_moves(board, from, piece.color),
        }
    }

    fn generate_pawn_moves(&self, board: &Board, from: Square, color: Color) -> Vec<Move> {
        let mut moves = Vec::new();
        let direction = if color == Color::White { 8 } else { -8i32 } as i32;
        let start_rank = if color == Color::White { 1 } else { 6 };
        let promotion_rank = if color == Color::White { 7 } else { 0 };
        
        let from_i32 = from as i32;
        let rank = from / 8;
        let file = from % 8;

        // One square forward
        let one_forward = from_i32 + direction;
        if self.is_valid_square(one_forward) && board.get_piece(one_forward as usize).is_none() {
            let to = one_forward as usize;
            if to / 8 == promotion_rank {
                // Promotion moves
                for promotion_piece in [PieceType::Queen, PieceType::Rook, PieceType::Bishop, PieceType::Knight] {
                    moves.push(Move::new(from, to, PieceType::Pawn).with_promotion(promotion_piece));
                }
            } else {
                moves.push(Move::new(from, to, PieceType::Pawn));
            }

            // Two squares forward from starting position
            if rank == start_rank {
                let two_forward = from_i32 + 2 * direction;
                if self.is_valid_square(two_forward) && board.get_piece(two_forward as usize).is_none() {
                    moves.push(Move::new(from, two_forward as usize, PieceType::Pawn));
                }
            }
        }

        // Captures
        for &offset in &[direction - 1, direction + 1] {
            let to = from_i32 + offset;
            let to_file = (to % 8) as usize;
            
            if self.is_valid_square(to) && (to_file as i32 - file as i32).abs() == 1 {
                let to_square = to as usize;
                if let Some(target_piece) = board.get_piece(to_square) {
                    if target_piece.color != color {
                        if to_square / 8 == promotion_rank {
                            // Promotion captures
                            for promotion_piece in [PieceType::Queen, PieceType::Rook, PieceType::Bishop, PieceType::Knight] {
                                moves.push(Move::new(from, to_square, PieceType::Pawn)
                                    .with_capture(target_piece.piece_type)
                                    .with_promotion(promotion_piece));
                            }
                        } else {
                            moves.push(Move::new(from, to_square, PieceType::Pawn)
                                .with_capture(target_piece.piece_type));
                        }
                    }
                }
            }
        }

        // En passant
        if let Some(en_passant_target) = board.get_en_passant_target() {
            let expected_rank = if color == Color::White { 4 } else { 3 };
            if rank == expected_rank {
                for &offset in &[direction - 1, direction + 1] {
                    let to = from_i32 + offset;
                    if self.is_valid_square(to) && to as usize == en_passant_target {
                        moves.push(Move::new(from, to as usize, PieceType::Pawn)
                            .with_capture(PieceType::Pawn)
                            .with_en_passant());
                    }
                }
            }
        }

        moves
    }

    fn generate_knight_moves(&self, board: &Board, from: Square, color: Color) -> Vec<Move> {
        let mut moves = Vec::new();
        let offsets = [-17, -15, -10, -6, 6, 10, 15, 17];
        let from_i32 = from as i32;
        let file = from % 8;

        for offset in offsets {
            let to = from_i32 + offset;
            let to_file = (to % 8) as usize;

            if self.is_valid_square(to) && (to_file as i32 - file as i32).abs() <= 2 {
                let to_square = to as usize;
                match board.get_piece(to_square) {
                    None => moves.push(Move::new(from, to_square, PieceType::Knight)),
                    Some(piece) if piece.color != color => {
                        moves.push(Move::new(from, to_square, PieceType::Knight)
                            .with_capture(piece.piece_type));
                    },
                    _ => {}
                }
            }
        }

        moves
    }

    fn generate_bishop_moves(&self, board: &Board, from: Square, color: Color) -> Vec<Move> {
        self.generate_sliding_moves(board, from, color, &[-9, -7, 7, 9], PieceType::Bishop)
    }

    fn generate_rook_moves(&self, board: &Board, from: Square, color: Color) -> Vec<Move> {
        self.generate_sliding_moves(board, from, color, &[-8, -1, 1, 8], PieceType::Rook)
    }

    fn generate_queen_moves(&self, board: &Board, from: Square, color: Color) -> Vec<Move> {
        self.generate_sliding_moves(board, from, color, &[-9, -8, -7, -1, 1, 7, 8, 9], PieceType::Queen)
    }

    fn generate_king_moves(&self, board: &Board, from: Square, color: Color) -> Vec<Move> {
        let mut moves = Vec::new();
        let offsets = [-9, -8, -7, -1, 1, 7, 8, 9];
        let from_i32 = from as i32;
        let file = from % 8;

        for offset in offsets {
            let to = from_i32 + offset;
            let to_file = (to % 8) as usize;

            if self.is_valid_square(to) && (to_file as i32 - file as i32).abs() <= 1 {
                let to_square = to as usize;
                match board.get_piece(to_square) {
                    None => moves.push(Move::new(from, to_square, PieceType::King)),
                    Some(piece) if piece.color != color => {
                        moves.push(Move::new(from, to_square, PieceType::King)
                            .with_capture(piece.piece_type));
                    },
                    _ => {}
                }
            }
        }

        // Castling
        let rights = board.get_castling_rights();
        if color == Color::White && from == 4 {
            // White kingside
            if rights.white_kingside && 
               board.get_piece(5).is_none() && 
               board.get_piece(6).is_none() &&
               board.get_piece(7).map_or(false, |p| p.piece_type == PieceType::Rook && p.color == Color::White) {
                if !self.is_square_attacked(board, 4, Color::Black) &&
                   !self.is_square_attacked(board, 5, Color::Black) &&
                   !self.is_square_attacked(board, 6, Color::Black) {
                    moves.push(Move::new(4, 6, PieceType::King).with_castling());
                }
            }
            // White queenside
            if rights.white_queenside &&
               board.get_piece(3).is_none() &&
               board.get_piece(2).is_none() &&
               board.get_piece(1).is_none() &&
               board.get_piece(0).map_or(false, |p| p.piece_type == PieceType::Rook && p.color == Color::White) {
                if !self.is_square_attacked(board, 4, Color::Black) &&
                   !self.is_square_attacked(board, 3, Color::Black) &&
                   !self.is_square_attacked(board, 2, Color::Black) {
                    moves.push(Move::new(4, 2, PieceType::King).with_castling());
                }
            }
        } else if color == Color::Black && from == 60 {
            // Black kingside
            if rights.black_kingside &&
               board.get_piece(61).is_none() &&
               board.get_piece(62).is_none() &&
               board.get_piece(63).map_or(false, |p| p.piece_type == PieceType::Rook && p.color == Color::Black) {
                if !self.is_square_attacked(board, 60, Color::White) &&
                   !self.is_square_attacked(board, 61, Color::White) &&
                   !self.is_square_attacked(board, 62, Color::White) {
                    moves.push(Move::new(60, 62, PieceType::King).with_castling());
                }
            }
            // Black queenside
            if rights.black_queenside &&
               board.get_piece(59).is_none() &&
               board.get_piece(58).is_none() &&
               board.get_piece(57).is_none() &&
               board.get_piece(56).map_or(false, |p| p.piece_type == PieceType::Rook && p.color == Color::Black) {
                if !self.is_square_attacked(board, 60, Color::White) &&
                   !self.is_square_attacked(board, 59, Color::White) &&
                   !self.is_square_attacked(board, 58, Color::White) {
                    moves.push(Move::new(60, 58, PieceType::King).with_castling());
                }
            }
        }

        moves
    }

    fn generate_sliding_moves(&self, board: &Board, from: Square, color: Color, directions: &[i32], piece_type: PieceType) -> Vec<Move> {
        let mut moves = Vec::new();
        let from_i32 = from as i32;

        for &direction in directions {
            let mut to = from_i32 + direction;
            let mut prev_file = (from % 8) as i32;

            while self.is_valid_square(to) {
                let to_file = to % 8;
                
                // Check for wrapping (especially important for horizontal moves)
                if direction == -1 || direction == 1 {
                    if (to_file - prev_file).abs() != 1 {
                        break;
                    }
                }

                let to_square = to as usize;
                match board.get_piece(to_square) {
                    None => {
                        moves.push(Move::new(from, to_square, piece_type));
                    },
                    Some(piece) => {
                        if piece.color != color {
                            moves.push(Move::new(from, to_square, piece_type)
                                .with_capture(piece.piece_type));
                        }
                        break;
                    }
                }

                prev_file = to_file;
                to += direction;
            }
        }

        moves
    }

    pub fn is_square_attacked(&self, board: &Board, square: Square, by_color: Color) -> bool {
        let (row, file) = (square / 8, square % 8);
        let from_i32 = square as i32;

        // Pawn attacks
        let pawn_direction = if by_color == Color::White { -1 } else { 1 };
        for &file_offset in &[-1, 1] {
            let p_row = row as i32 + pawn_direction;
            let p_file = file as i32 + file_offset;
            if p_row >= 0 && p_row < 8 && p_file >= 0 && p_file < 8 {
                let p_square = (p_row * 8 + p_file) as usize;
                if let Some(piece) = board.get_piece(p_square) {
                    if piece.color == by_color && piece.piece_type == PieceType::Pawn {
                        return true;
                    }
                }
            }
        }

        // Knight attacks
        let knight_offsets = [-17, -15, -10, -6, 6, 10, 15, 17];
        for &offset in &knight_offsets {
            let to = from_i32 + offset;
            if to >= 0 && to < 64 {
                let to_file = to % 8;
                if (to_file - file as i32).abs() <= 2 {
                    if let Some(piece) = board.get_piece(to as usize) {
                        if piece.color == by_color && piece.piece_type == PieceType::Knight {
                            return true;
                        }
                    }
                }
            }
        }

        // Sliding attacks (Rook, Bishop, Queen)
        let sliding_dirs = [
            (-1, 0, true), (1, 0, true), (0, -1, true), (0, 1, true),   // Rook/Queen
            (-1, -1, false), (-1, 1, false), (1, -1, false), (1, 1, false) // Bishop/Queen
        ];

        for &(dr, df, is_rook_type) in &sliding_dirs {
            let mut r = row as i32 + dr;
            let mut f = file as i32 + df;
            while r >= 0 && r < 8 && f >= 0 && f < 8 {
                let s = (r * 8 + f) as usize;
                if let Some(piece) = board.get_piece(s) {
                    if piece.color == by_color {
                        match piece.piece_type {
                            PieceType::Queen => return true,
                            PieceType::Rook if is_rook_type => return true,
                            PieceType::Bishop if !is_rook_type => return true,
                            _ => {}
                        }
                    }
                    break;
                }
                r += dr;
                f += df;
            }
        }

        // King attacks
        for dr in -1..=1 {
            for df in -1..=1 {
                if dr == 0 && df == 0 { continue; }
                let r = row as i32 + dr;
                let f = file as i32 + df;
                if r >= 0 && r < 8 && f >= 0 && f < 8 {
                    let s = (r * 8 + f) as usize;
                    if let Some(piece) = board.get_piece(s) {
                        if piece.color == by_color && piece.piece_type == PieceType::King {
                            return true;
                        }
                    }
                }
            }
        }

        false
    }

    pub fn is_in_check(&self, board: &Board, color: Color) -> bool {
        for square in 0..64 {
            if let Some(piece) = board.get_piece(square) {
                if piece.color == color && piece.piece_type == PieceType::King {
                    return self.is_square_attacked(board, square, color.opposite());
                }
            }
        }
        false
    }

    pub fn get_legal_moves(&self, board: &mut Board, color: Color) -> Vec<Move> {
        Vec::new()
    }

    pub fn is_checkmate(&self, board: &mut Board, color: Color) -> bool {
        self.is_in_check(board, color) && self.get_legal_moves(board, color).is_empty()
    }

    pub fn is_stalemate(&self, board: &mut Board, color: Color) -> bool {
        !self.is_in_check(board, color) && self.get_legal_moves(board, color).is_empty()
    }

    fn is_valid_square(&self, square: i32) -> bool {
        square >= 0 && square < 64
    }
}