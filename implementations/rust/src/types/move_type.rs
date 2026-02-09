use std::marker::PhantomData;
use super::square::TypedSquare;
use super::piece::PieceType;

/// Marker type for unchecked moves (parsed but not validated)
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Unchecked;

/// Marker type for legal moves (validated and ready to apply)
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Legal;

/// Type-safe chess move with validation state
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Move<T> {
    pub from: TypedSquare,
    pub to: TypedSquare,
    pub piece: PieceType,
    pub captured: Option<PieceType>,
    pub promotion: Option<PieceType>,
    pub is_castling: bool,
    pub is_en_passant: bool,
    _marker: PhantomData<T>,
}

impl<T> Move<T> {
    /// Get the from square
    pub fn from(&self) -> TypedSquare {
        self.from
    }

    /// Get the to square
    pub fn to(&self) -> TypedSquare {
        self.to
    }

    /// Get the piece being moved
    pub fn piece(&self) -> PieceType {
        self.piece
    }

    /// Get the captured piece, if any
    pub fn captured(&self) -> Option<PieceType> {
        self.captured
    }

    /// Get the promotion piece, if any
    pub fn promotion(&self) -> Option<PieceType> {
        self.promotion
    }

    /// Check if this is a castling move
    pub fn is_castling(&self) -> bool {
        self.is_castling
    }

    /// Check if this is an en passant capture
    pub fn is_en_passant(&self) -> bool {
        self.is_en_passant
    }
}

impl Move<Unchecked> {
    /// Create a new unchecked move
    pub fn new_unchecked(from: TypedSquare, to: TypedSquare, piece: PieceType) -> Self {
        Self {
            from,
            to,
            piece,
            captured: None,
            promotion: None,
            is_castling: false,
            is_en_passant: false,
            _marker: PhantomData,
        }
    }

    /// Add a capture to this move
    pub fn with_capture(mut self, captured: PieceType) -> Self {
        self.captured = Some(captured);
        self
    }

    /// Add a promotion to this move
    pub fn with_promotion(mut self, promotion: PieceType) -> Self {
        self.promotion = Some(promotion);
        self
    }

    /// Mark this move as castling
    pub fn with_castling(mut self) -> Self {
        self.is_castling = true;
        self
    }

    /// Mark this move as en passant
    pub fn with_en_passant(mut self) -> Self {
        self.is_en_passant = true;
        self
    }

    /// Convert to a legal move (should only be done after validation)
    pub(crate) fn to_legal(self) -> Move<Legal> {
        Move {
            from: self.from,
            to: self.to,
            piece: self.piece,
            captured: self.captured,
            promotion: self.promotion,
            is_castling: self.is_castling,
            is_en_passant: self.is_en_passant,
            _marker: PhantomData,
        }
    }
}

impl Move<Legal> {
    /// Create a new legal move (internal use only, should be created via validation)
    pub(crate) fn new_legal(from: TypedSquare, to: TypedSquare, piece: PieceType) -> Self {
        Self {
            from,
            to,
            piece,
            captured: None,
            promotion: None,
            is_castling: false,
            is_en_passant: false,
            _marker: PhantomData,
        }
    }

    /// Add a capture to this move
    pub(crate) fn with_capture(mut self, captured: PieceType) -> Self {
        self.captured = Some(captured);
        self
    }

    /// Add a promotion to this move
    pub(crate) fn with_promotion(mut self, promotion: PieceType) -> Self {
        self.promotion = Some(promotion);
        self
    }

    /// Mark this move as castling
    pub(crate) fn with_castling(mut self) -> Self {
        self.is_castling = true;
        self
    }

    /// Mark this move as en passant
    pub(crate) fn with_en_passant(mut self) -> Self {
        self.is_en_passant = true;
        self
    }
}

// For compatibility with existing code, we need a concrete Move type
// This is the "unchecked" version used in existing code
pub type MoveUnchecked = Move<Unchecked>;
pub type MoveLegal = Move<Legal>;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_move_creation() {
        let from = TypedSquare::try_from(12u8).unwrap();
        let to = TypedSquare::try_from(28u8).unwrap();
        let mv = Move::new_unchecked(from, to, PieceType::Pawn);
        assert_eq!(mv.from(), from);
        assert_eq!(mv.to(), to);
    }

    #[test]
    fn test_move_with_capture() {
        let from = TypedSquare::try_from(12u8).unwrap();
        let to = TypedSquare::try_from(28u8).unwrap();
        let mv = Move::new_unchecked(from, to, PieceType::Pawn)
            .with_capture(PieceType::Knight);
        assert_eq!(mv.captured(), Some(PieceType::Knight));
    }
}
