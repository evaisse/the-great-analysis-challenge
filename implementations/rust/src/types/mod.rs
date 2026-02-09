// Type-safe chess types using Rust's advanced type system features
//
// This module implements PRD-04: Type-Safe Modeling
// - Newtype pattern for TypedSquare (guarantees 0-63)
// - Phantom types for TypedMove<Legal> vs TypedMove<Unchecked>
// - State machine for BoardState<WhiteToMove> vs BoardState<BlackToMove>
// - Type-safe piece, color, and castling types
//
// For backward compatibility, we also export legacy types that match the old API.
// New code should use the typed versions (TypedSquare, TypedMove, BoardState).

pub mod square;
pub mod piece;
pub mod move_type;
pub mod castling;
pub mod board_state;

// Re-export types for convenience
pub use square::TypedSquare;
pub use piece::{Color, PieceType, Piece};
pub use move_type::{Move as TypedMove, Unchecked, Legal};
pub use castling::CastlingRights;
pub use board_state::{BoardState, WhiteToMove};

// ============================================================================
// LEGACY COMPATIBILITY LAYER
// ============================================================================
// The old implementation used usize for Square and a simple Move struct.
// We maintain these for backward compatibility.

/// Legacy Square type (just a usize). Use TypedSquare for new code.
pub type Square = usize;

/// Legacy move structure for compatibility
/// New code should use TypedMove<Unchecked> or TypedMove<Legal>
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LegacyMove {
    pub from: Square,
    pub to: Square,
    pub piece: PieceType,
    pub captured: Option<PieceType>,
    pub promotion: Option<PieceType>,
    pub is_castling: bool,
    pub is_en_passant: bool,
}

impl LegacyMove {
    pub fn new(from: Square, to: Square, piece: PieceType) -> Self {
        Self {
            from,
            to,
            piece,
            captured: None,
            promotion: None,
            is_castling: false,
            is_en_passant: false,
        }
    }

    pub fn with_capture(mut self, captured: PieceType) -> Self {
        self.captured = Some(captured);
        self
    }

    pub fn with_promotion(mut self, promotion: PieceType) -> Self {
        self.promotion = Some(promotion);
        self
    }

    pub fn with_castling(mut self) -> Self {
        self.is_castling = true;
        self
    }

    pub fn with_en_passant(mut self) -> Self {
        self.is_en_passant = true;
        self
    }

    /// Convert to typed unchecked move
    pub fn to_unchecked(self) -> TypedMove<Unchecked> {
        let from = TypedSquare::try_from(self.from as u8).unwrap_or(TypedSquare::new(0));
        let to = TypedSquare::try_from(self.to as u8).unwrap_or(TypedSquare::new(0));
        let mut mv = TypedMove::new_unchecked(from, to, self.piece);
        if let Some(cap) = self.captured {
            mv = mv.with_capture(cap);
        }
        if let Some(prom) = self.promotion {
            mv = mv.with_promotion(prom);
        }
        if self.is_castling {
            mv = mv.with_castling();
        }
        if self.is_en_passant {
            mv = mv.with_en_passant();
        }
        mv
    }
}

impl From<TypedMove<Unchecked>> for LegacyMove {
    fn from(mv: TypedMove<Unchecked>) -> Self {
        Self {
            from: mv.from.as_usize(),
            to: mv.to.as_usize(),
            piece: mv.piece,
            captured: mv.captured,
            promotion: mv.promotion,
            is_castling: mv.is_castling,
            is_en_passant: mv.is_en_passant,
        }
    }
}

impl From<TypedMove<Legal>> for LegacyMove {
    fn from(mv: TypedMove<Legal>) -> Self {
        Self {
            from: mv.from.as_usize(),
            to: mv.to.as_usize(),
            piece: mv.piece,
            captured: mv.captured,
            promotion: mv.promotion,
            is_castling: mv.is_castling,
            is_en_passant: mv.is_en_passant,
        }
    }
}

/// Legacy GameState structure for compatibility
#[derive(Debug, Clone)]
pub struct GameState {
    pub board: [Option<Piece>; 64],
    pub turn: Color,
    pub castling_rights: CastlingRights,
    pub en_passant_target: Option<Square>,
    pub halfmove_clock: u32,
    pub fullmove_number: u32,
    pub move_history: Vec<LegacyMove>,
}

impl GameState {
    pub fn new() -> Self {
        let state = BoardState::<WhiteToMove>::new();
        Self {
            board: state.board,
            turn: Color::White,
            castling_rights: state.castling_rights,
            en_passant_target: state.en_passant_target.map(|s| s.as_usize()),
            halfmove_clock: state.halfmove_clock,
            fullmove_number: state.fullmove_number,
            move_history: Vec::new(),
        }
    }
}

impl Default for GameState {
    fn default() -> Self {
        Self::new()
    }
}

// Helper functions for algebraic notation (legacy compatibility)
pub const FILES: [char; 8] = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
pub const RANKS: [char; 8] = ['1', '2', '3', '4', '5', '6', '7', '8'];

pub fn square_to_algebraic(square: Square) -> String {
    let file = square % 8;
    let rank = square / 8;
    format!("{}{}", FILES[file], RANKS[rank])
}

pub fn algebraic_to_square(algebraic: &str) -> Result<Square, String> {
    if algebraic.len() != 2 {
        return Err("Invalid algebraic notation".to_string());
    }
    
    let chars: Vec<char> = algebraic.chars().collect();
    let file = FILES.iter().position(|&f| f == chars[0])
        .ok_or("Invalid file")?;
    let rank = RANKS.iter().position(|&r| r == chars[1])
        .ok_or("Invalid rank")?;
    
    Ok(rank * 8 + file)
}

// Export Move as the main type (legacy compatibility)
pub type Move = LegacyMove;
