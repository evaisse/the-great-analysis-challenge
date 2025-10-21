use crate::types::*;
use crate::board::Board;

pub struct FenParser;

impl FenParser {
    pub fn new() -> Self {
        Self
    }

    pub fn parse_fen(&self, board: &mut Board, fen: &str) -> Result<(), String> {
        let parts: Vec<&str> = fen.split_whitespace().collect();
        if parts.len() < 4 {
            return Err("ERROR: Invalid FEN string".to_string());
        }

        let pieces = parts[0];
        let turn = parts[1];
        let castling = parts[2];
        let en_passant = parts[3];
        let halfmove = parts.get(4).unwrap_or(&"0");
        let fullmove = parts.get(5).unwrap_or(&"1");

        // Clear board
        for i in 0..64 {
            board.set_piece(i, None);
        }

        // Parse piece positions
        let mut square = 56; // Start at a8 (top-left)
        for ch in pieces.chars() {
            match ch {
                '/' => square -= 16, // Move to next rank
                '1'..='8' => {
                    let empty_squares = ch.to_digit(10).unwrap() as usize;
                    square += empty_squares;
                },
                _ => {
                    if let Some(piece) = Piece::from_char(ch) {
                        board.set_piece(square, Some(piece));
                        square += 1;
                    }
                }
            }
        }

        // Parse turn
        let color = match turn {
            "w" => Color::White,
            "b" => Color::Black,
            _ => return Err("ERROR: Invalid FEN string".to_string()),
        };
        board.set_turn(color);

        // Parse castling rights
        let mut rights = CastlingRights::none();
        if castling.contains('K') { rights.white_kingside = true; }
        if castling.contains('Q') { rights.white_queenside = true; }
        if castling.contains('k') { rights.black_kingside = true; }
        if castling.contains('q') { rights.black_queenside = true; }
        board.set_castling_rights(rights);

        // Parse en passant target
        if en_passant != "-" {
            if let Ok(square) = algebraic_to_square(en_passant) {
                board.set_en_passant_target(Some(square));
            }
        } else {
            board.set_en_passant_target(None);
        }

        // Parse move counters
        let state = board.get_state();
        let mut new_state = state.clone();
        new_state.halfmove_clock = halfmove.parse().unwrap_or(0);
        new_state.fullmove_number = fullmove.parse().unwrap_or(1);
        board.set_state(new_state);

        Ok(())
    }

    pub fn export_fen(&self, board: &Board) -> String {
        let pieces = self.get_pieces_string(board);
        let turn = if board.get_turn() == Color::White { "w" } else { "b" };
        let castling = self.get_castling_string(board);
        let en_passant = self.get_en_passant_string(board);
        let state = board.get_state();
        
        format!("{} {} {} {} {} {}", 
            pieces, turn, castling, en_passant, 
            state.halfmove_clock, state.fullmove_number)
    }

    fn get_pieces_string(&self, board: &Board) -> String {
        let mut result = String::new();
        
        for rank in (0..8).rev() {
            let mut empty_count = 0;
            
            for file in 0..8 {
                let square = rank * 8 + file;
                
                if let Some(piece) = board.get_piece(square) {
                    if empty_count > 0 {
                        result.push_str(&empty_count.to_string());
                        empty_count = 0;
                    }
                    result.push(piece.to_char());
                } else {
                    empty_count += 1;
                }
            }
            
            if empty_count > 0 {
                result.push_str(&empty_count.to_string());
            }
            
            if rank > 0 {
                result.push('/');
            }
        }
        
        result
    }

    fn get_castling_string(&self, board: &Board) -> String {
        let rights = board.get_castling_rights();
        let mut result = String::new();
        
        if rights.white_kingside { result.push('K'); }
        if rights.white_queenside { result.push('Q'); }
        if rights.black_kingside { result.push('k'); }
        if rights.black_queenside { result.push('q'); }
        
        if result.is_empty() {
            result.push('-');
        }
        
        result
    }

    fn get_en_passant_string(&self, board: &Board) -> String {
        match board.get_en_passant_target() {
            Some(square) => square_to_algebraic(square),
            None => "-".to_string(),
        }
    }
}