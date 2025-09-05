use crate::types::*;
use std::fmt;

pub struct Board {
    state: GameState,
}

impl Board {
    pub fn new() -> Self {
        Self {
            state: GameState::new(),
        }
    }

    pub fn reset(&mut self) {
        self.state = GameState::new();
    }

    pub fn get_piece(&self, square: Square) -> Option<Piece> {
        self.state.board[square]
    }

    pub fn set_piece(&mut self, square: Square, piece: Option<Piece>) {
        self.state.board[square] = piece;
    }

    pub fn get_turn(&self) -> Color {
        self.state.turn
    }

    pub fn set_turn(&mut self, color: Color) {
        self.state.turn = color;
    }

    pub fn get_castling_rights(&self) -> CastlingRights {
        self.state.castling_rights
    }

    pub fn set_castling_rights(&mut self, rights: CastlingRights) {
        self.state.castling_rights = rights;
    }

    pub fn get_en_passant_target(&self) -> Option<Square> {
        self.state.en_passant_target
    }

    pub fn set_en_passant_target(&mut self, square: Option<Square>) {
        self.state.en_passant_target = square;
    }

    pub fn get_state(&self) -> &GameState {
        &self.state
    }

    pub fn set_state(&mut self, state: GameState) {
        self.state = state;
    }

    pub fn make_move(&mut self, chess_move: &Move) {
        let piece = self.get_piece(chess_move.from);
        if piece.is_none() {
            return;
        }
        let piece = piece.unwrap();

        // Move piece
        self.set_piece(chess_move.to, Some(piece));
        self.set_piece(chess_move.from, None);

        // Handle castling
        if chess_move.is_castling {
            let rank = if piece.color == Color::White { 0 } else { 7 };
            let (rook_from, rook_to) = if chess_move.to == rank * 8 + 6 {
                // Kingside
                (rank * 8 + 7, rank * 8 + 5)
            } else {
                // Queenside
                (rank * 8, rank * 8 + 3)
            };

            if let Some(rook) = self.get_piece(rook_from) {
                self.set_piece(rook_to, Some(rook));
                self.set_piece(rook_from, None);
            }
        }

        // Handle en passant
        if chess_move.is_en_passant {
            let captured_pawn_square = if piece.color == Color::White {
                chess_move.to - 8
            } else {
                chess_move.to + 8
            };
            self.set_piece(captured_pawn_square, None);
        }

        // Handle promotion
        if let Some(promotion) = chess_move.promotion {
            self.set_piece(chess_move.to, Some(Piece::new(promotion, piece.color)));
        }

        // Update castling rights
        let mut rights = self.get_castling_rights();
        if piece.piece_type == PieceType::King {
            if piece.color == Color::White {
                rights.white_kingside = false;
                rights.white_queenside = false;
            } else {
                rights.black_kingside = false;
                rights.black_queenside = false;
            }
        } else if piece.piece_type == PieceType::Rook {
            match (piece.color, chess_move.from) {
                (Color::White, 0) => rights.white_queenside = false,
                (Color::White, 7) => rights.white_kingside = false,
                (Color::Black, 56) => rights.black_queenside = false,
                (Color::Black, 63) => rights.black_kingside = false,
                _ => {}
            }
        }
        self.set_castling_rights(rights);

        // Update en passant target
        if piece.piece_type == PieceType::Pawn && 
           (chess_move.to as i32 - chess_move.from as i32).abs() == 16 {
            let en_passant_square = (chess_move.from + chess_move.to) / 2;
            self.set_en_passant_target(Some(en_passant_square));
        } else {
            self.set_en_passant_target(None);
        }

        // Update halfmove clock
        if piece.piece_type == PieceType::Pawn || chess_move.captured.is_some() {
            self.state.halfmove_clock = 0;
        } else {
            self.state.halfmove_clock += 1;
        }

        // Update fullmove number
        if piece.color == Color::Black {
            self.state.fullmove_number += 1;
        }

        // Switch turn
        self.state.turn = piece.color.opposite();
        self.state.move_history.push(chess_move.clone());
    }

    pub fn undo_move(&mut self) -> Option<Move> {
        let chess_move = self.state.move_history.pop()?;
        
        // Get the piece that was moved
        let moved_piece = self.get_piece(chess_move.to)?;
        
        // Restore the original piece (handle promotion)
        let original_piece = if chess_move.promotion.is_some() {
            Piece::new(PieceType::Pawn, moved_piece.color)
        } else {
            moved_piece
        };
        
        // Move piece back
        self.set_piece(chess_move.from, Some(original_piece));
        
        // Restore captured piece or clear destination
        if let Some(captured) = chess_move.captured {
            let captured_color = moved_piece.color.opposite();
            self.set_piece(chess_move.to, Some(Piece::new(captured, captured_color)));
        } else {
            self.set_piece(chess_move.to, None);
        }

        // Handle castling
        if chess_move.is_castling {
            let rank = if moved_piece.color == Color::White { 0 } else { 7 };
            let (rook_from, rook_to) = if chess_move.to == rank * 8 + 6 {
                // Kingside
                (rank * 8 + 5, rank * 8 + 7)
            } else {
                // Queenside  
                (rank * 8 + 3, rank * 8)
            };

            if let Some(rook) = self.get_piece(rook_from) {
                self.set_piece(rook_to, Some(rook));
                self.set_piece(rook_from, None);
            }
        }

        // Handle en passant
        if chess_move.is_en_passant {
            let captured_pawn_square = if moved_piece.color == Color::White {
                chess_move.to - 8
            } else {
                chess_move.to + 8
            };
            let captured_color = moved_piece.color.opposite();
            self.set_piece(captured_pawn_square, Some(Piece::new(PieceType::Pawn, captured_color)));
        }

        // Restore turn
        self.state.turn = moved_piece.color;

        Some(chess_move)
    }
}

impl fmt::Display for Board {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        writeln!(f, "  a b c d e f g h")?;
        
        for rank in (0..8).rev() {
            write!(f, "{} ", rank + 1)?;
            for file in 0..8 {
                let square = rank * 8 + file;
                match self.get_piece(square) {
                    Some(piece) => write!(f, "{} ", piece.to_char())?,
                    None => write!(f, ". ")?,
                }
            }
            writeln!(f, "{}", rank + 1)?;
        }
        
        writeln!(f, "  a b c d e f g h")?;
        writeln!(f)?;
        write!(f, "{} to move", 
            if self.get_turn() == Color::White { "White" } else { "Black" })
    }
}