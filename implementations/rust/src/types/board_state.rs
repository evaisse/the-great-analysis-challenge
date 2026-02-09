use std::marker::PhantomData;
use super::piece::{Piece, Color};
use super::square::TypedSquare;
pub use super::move_type::{Move, Legal};
use super::castling::CastlingRights;

/// Marker type for white to move
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct WhiteToMove;

/// Marker type for black to move
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct BlackToMove;

/// Type-safe board state that tracks whose turn it is at the type level
#[derive(Debug, Clone)]
pub struct BoardState<Turn> {
    pub board: [Option<Piece>; 64],
    pub castling_rights: CastlingRights,
    pub en_passant_target: Option<TypedSquare>,
    pub halfmove_clock: u32,
    pub fullmove_number: u32,
    pub move_history: Vec<Move<Legal>>,
    _turn: PhantomData<Turn>,
}

impl BoardState<WhiteToMove> {
    /// Create a new board in the starting position (White to move)
    pub fn new() -> Self {
        let mut board = [None; 64];
        
        // White pieces
        board[0] = Some(Piece::new(super::piece::PieceType::Rook, Color::White));
        board[1] = Some(Piece::new(super::piece::PieceType::Knight, Color::White));
        board[2] = Some(Piece::new(super::piece::PieceType::Bishop, Color::White));
        board[3] = Some(Piece::new(super::piece::PieceType::Queen, Color::White));
        board[4] = Some(Piece::new(super::piece::PieceType::King, Color::White));
        board[5] = Some(Piece::new(super::piece::PieceType::Bishop, Color::White));
        board[6] = Some(Piece::new(super::piece::PieceType::Knight, Color::White));
        board[7] = Some(Piece::new(super::piece::PieceType::Rook, Color::White));
        
        for i in 8..16 {
            board[i] = Some(Piece::new(super::piece::PieceType::Pawn, Color::White));
        }
        
        // Black pieces
        for i in 48..56 {
            board[i] = Some(Piece::new(super::piece::PieceType::Pawn, Color::Black));
        }
        
        board[56] = Some(Piece::new(super::piece::PieceType::Rook, Color::Black));
        board[57] = Some(Piece::new(super::piece::PieceType::Knight, Color::Black));
        board[58] = Some(Piece::new(super::piece::PieceType::Bishop, Color::Black));
        board[59] = Some(Piece::new(super::piece::PieceType::Queen, Color::Black));
        board[60] = Some(Piece::new(super::piece::PieceType::King, Color::Black));
        board[61] = Some(Piece::new(super::piece::PieceType::Bishop, Color::Black));
        board[62] = Some(Piece::new(super::piece::PieceType::Knight, Color::Black));
        board[63] = Some(Piece::new(super::piece::PieceType::Rook, Color::Black));

        Self {
            board,
            castling_rights: CastlingRights::new(),
            en_passant_target: None,
            halfmove_clock: 0,
            fullmove_number: 1,
            move_history: Vec::new(),
            _turn: PhantomData,
        }
    }

    /// Transition to Black's turn (consumes self)
    pub fn transition_to_black(self) -> BoardState<BlackToMove> {
        BoardState {
            board: self.board,
            castling_rights: self.castling_rights,
            en_passant_target: self.en_passant_target,
            halfmove_clock: self.halfmove_clock,
            fullmove_number: self.fullmove_number,
            move_history: self.move_history,
            _turn: PhantomData,
        }
    }
}

impl BoardState<BlackToMove> {
    /// Transition to White's turn (consumes self)
    pub fn transition_to_white(self) -> BoardState<WhiteToMove> {
        BoardState {
            board: self.board,
            castling_rights: self.castling_rights,
            en_passant_target: self.en_passant_target,
            halfmove_clock: self.halfmove_clock,
            fullmove_number: self.fullmove_number + 1,
            move_history: self.move_history,
            _turn: PhantomData,
        }
    }
}

impl<Turn> BoardState<Turn> {
    /// Get a piece at a square
    pub fn get_piece(&self, square: TypedSquare) -> Option<Piece> {
        self.board[square.as_usize()]
    }

    /// Set a piece at a square
    pub fn set_piece(&mut self, square: TypedSquare, piece: Option<Piece>) {
        self.board[square.as_usize()] = piece;
    }

    /// Get castling rights
    pub fn castling_rights(&self) -> CastlingRights {
        self.castling_rights
    }

    /// Get en passant target
    pub fn en_passant_target(&self) -> Option<TypedSquare> {
        self.en_passant_target
    }
}

impl Default for BoardState<WhiteToMove> {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_new_board() {
        let board = BoardState::<WhiteToMove>::new();
        let e1 = TypedSquare::try_from(4u8).unwrap();
        let piece = board.get_piece(e1);
        assert!(piece.is_some());
        assert_eq!(piece.unwrap().color, Color::White);
    }

    #[test]
    fn test_transition() {
        let white_board = BoardState::<WhiteToMove>::new();
        let black_board = white_board.transition_to_black();
        let white_board2 = black_board.transition_to_white();
        assert_eq!(white_board2.fullmove_number, 2);
    }
}
