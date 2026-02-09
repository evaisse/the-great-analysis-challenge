use crate::types::*;
use crate::zobrist;
use crate::draw_detection;
use std::fmt;

pub struct Board {
    state: GameState,
}

impl Board {
    pub fn new() -> Self {
        let mut state = GameState::new();
        state.zobrist_hash = zobrist::get_keys().compute_hash(&state);
        Self { state }
    }

    pub fn reset(&mut self) {
        self.state = GameState::new();
        self.state.zobrist_hash = zobrist::get_keys().compute_hash(&self.state);
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

    pub fn is_draw(&self) -> bool {
        draw_detection::is_draw_by_repetition(&self.state) || 
        draw_detection::is_draw_by_fifty_moves(&self.state)
    }

    pub fn get_hash(&self) -> u64 {
        self.state.zobrist_hash
    }

    pub fn get_draw_info(&self) -> String {
        format!("Repetition: {}, 50-move clock: {}", 
            draw_detection::is_draw_by_repetition(&self.state),
            self.state.halfmove_clock)
    }

    pub fn make_move(&mut self, chess_move: &Move) {
        let keys = zobrist::get_keys();
        let piece = self.get_piece(chess_move.from).expect("No piece at source square");
        
        // Save current state for undo
        self.state.irreversible_history.push(IrreversibleState {
            castling_rights: self.state.castling_rights,
            en_passant_target: self.state.en_passant_target,
            halfmove_clock: self.state.halfmove_clock,
            zobrist_hash: self.state.zobrist_hash,
        });
        self.state.position_history.push(self.state.zobrist_hash);

        let mut hash = self.state.zobrist_hash;

        // 1. Remove moving piece from source
        hash ^= keys.pieces[zobrist::piece_to_index(piece)][chess_move.from];

        // 2. Handle capture
        if let Some(captured_type) = chess_move.captured {
            let captured_color = piece.color.opposite();
            let captured_piece = Piece::new(captured_type, captured_color);
            if chess_move.is_en_passant {
                let captured_sq = if piece.color == Color::White {
                    chess_move.to - 8
                } else {
                    chess_move.to + 8
                };
                hash ^= keys.pieces[zobrist::piece_to_index(captured_piece)][captured_sq];
                self.set_piece(captured_sq, None);
            } else {
                hash ^= keys.pieces[zobrist::piece_to_index(captured_piece)][chess_move.to];
                // Piece at destination will be overwritten below
            }
            self.state.halfmove_clock = 0;
        } else if piece.piece_type == PieceType::Pawn {
            self.state.halfmove_clock = 0;
        } else {
            self.state.halfmove_clock += 1;
        }

        // 3. Place piece at destination (handling promotion)
        if let Some(promotion) = chess_move.promotion {
            let promo_piece = Piece::new(promotion, piece.color);
            hash ^= keys.pieces[zobrist::piece_to_index(promo_piece)][chess_move.to];
            self.set_piece(chess_move.to, Some(promo_piece));
        } else {
            hash ^= keys.pieces[zobrist::piece_to_index(piece)][chess_move.to];
            self.set_piece(chess_move.to, Some(piece));
        }
        self.set_piece(chess_move.from, None);

        // 4. Handle castling rook
        if chess_move.is_castling {
            let rank = if piece.color == Color::White { 0 } else { 7 };
            let (rook_from, rook_to) = if chess_move.to == rank * 8 + 6 {
                (rank * 8 + 7, rank * 8 + 5)
            } else {
                (rank * 8, rank * 8 + 3)
            };
            if let Some(rook) = self.get_piece(rook_from) {
                hash ^= keys.pieces[zobrist::piece_to_index(rook)][rook_from];
                hash ^= keys.pieces[zobrist::piece_to_index(rook)][rook_to];
                self.set_piece(rook_to, Some(rook));
                self.set_piece(rook_from, None);
            }
        }

        // 5. Update castling rights in hash
        if self.state.castling_rights.white_kingside { hash ^= keys.castling[0]; }
        if self.state.castling_rights.white_queenside { hash ^= keys.castling[1]; }
        if self.state.castling_rights.black_kingside { hash ^= keys.castling[2]; }
        if self.state.castling_rights.black_queenside { hash ^= keys.castling[3]; }

        if piece.piece_type == PieceType::King {
            if piece.color == Color::White {
                self.state.castling_rights.white_kingside = false;
                self.state.castling_rights.white_queenside = false;
            } else {
                self.state.castling_rights.black_kingside = false;
                self.state.castling_rights.black_queenside = false;
            }
        }
        
        // Handle rook moves/captures affecting castling rights
        if chess_move.from == 0 || chess_move.to == 0 { self.state.castling_rights.white_queenside = false; }
        if chess_move.from == 7 || chess_move.to == 7 { self.state.castling_rights.white_kingside = false; }
        if chess_move.from == 56 || chess_move.to == 56 { self.state.castling_rights.black_queenside = false; }
        if chess_move.from == 63 || chess_move.to == 63 { self.state.castling_rights.black_kingside = false; }

        if self.state.castling_rights.white_kingside { hash ^= keys.castling[0]; }
        if self.state.castling_rights.white_queenside { hash ^= keys.castling[1]; }
        if self.state.castling_rights.black_kingside { hash ^= keys.castling[2]; }
        if self.state.castling_rights.black_queenside { hash ^= keys.castling[3]; }

        // 6. Update en passant target in hash
        if let Some(sq) = self.state.en_passant_target {
            hash ^= keys.en_passant[sq % 8];
        }
        
        if piece.piece_type == PieceType::Pawn && (chess_move.to as i32 - chess_move.from as i32).abs() == 16 {
            let en_passant_square = (chess_move.from + chess_move.to) / 2;
            self.state.en_passant_target = Some(en_passant_square);
            hash ^= keys.en_passant[en_passant_square % 8];
        } else {
            self.state.en_passant_target = None;
        }

        // 7. Update side to move and fullmove
        hash ^= keys.side_to_move;
        self.state.turn = piece.color.opposite();
        
        if piece.color == Color::Black {
            self.state.fullmove_number += 1;
        }

        self.state.zobrist_hash = hash;
        self.state.move_history.push(chess_move.clone());
    }

    pub fn undo_move(&mut self) -> Option<Move> {
        let chess_move = self.state.move_history.pop()?;
        let old_state = self.state.irreversible_history.pop().expect("No irreversible history");
        self.state.position_history.pop();

        // Get the piece that was moved
        let moved_piece = self.get_piece(chess_move.to).expect("No piece at destination");
        
        // Restore irreversible state
        self.state.castling_rights = old_state.castling_rights;
        self.state.en_passant_target = old_state.en_passant_target;
        self.state.halfmove_clock = old_state.halfmove_clock;
        self.state.zobrist_hash = old_state.zobrist_hash;

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
            let captured_piece = Piece::new(captured, captured_color);
            if chess_move.is_en_passant {
                let captured_pawn_square = if moved_piece.color == Color::White {
                    chess_move.to - 8
                } else {
                    chess_move.to + 8
                };
                self.set_piece(captured_pawn_square, Some(captured_piece));
                self.set_piece(chess_move.to, None);
            } else {
                self.set_piece(chess_move.to, Some(captured_piece));
            }
        } else {
            self.set_piece(chess_move.to, None);
        }

        // Handle castling rook
        if chess_move.is_castling {
            let rank = if moved_piece.color == Color::White { 0 } else { 7 };
            let (rook_from, rook_to) = if chess_move.to == rank * 8 + 6 {
                (rank * 8 + 5, rank * 8 + 7)
            } else {
                (rank * 8 + 3, rank * 8)
            };

            if let Some(rook) = self.get_piece(rook_from) {
                self.set_piece(rook_to, Some(rook));
                self.set_piece(rook_from, None);
            }
        }

        // Restore turn and fullmove number
        if moved_piece.color == Color::Black {
            self.state.fullmove_number -= 1;
        }
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