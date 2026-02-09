use std::fmt;

/// Chess piece colors
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Color {
    White,
    Black,
}

impl Color {
    /// Get the opposite color
    pub const fn opposite(self) -> Color {
        match self {
            Color::White => Color::Black,
            Color::Black => Color::White,
        }
    }

    /// Returns true if this is White
    pub const fn is_white(self) -> bool {
        matches!(self, Color::White)
    }

    /// Returns true if this is Black
    pub const fn is_black(self) -> bool {
        matches!(self, Color::Black)
    }
}

impl fmt::Display for Color {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            Color::White => write!(f, "White"),
            Color::Black => write!(f, "Black"),
        }
    }
}

/// Chess piece types
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum PieceType {
    King,
    Queen,
    Rook,
    Bishop,
    Knight,
    Pawn,
}

impl PieceType {
    /// Parse a piece type from a character (case-insensitive)
    pub fn from_char(ch: char) -> Option<PieceType> {
        match ch.to_ascii_uppercase() {
            'K' => Some(PieceType::King),
            'Q' => Some(PieceType::Queen),
            'R' => Some(PieceType::Rook),
            'B' => Some(PieceType::Bishop),
            'N' => Some(PieceType::Knight),
            'P' => Some(PieceType::Pawn),
            _ => None,
        }
    }

    /// Get the standard piece value in centipawns
    pub const fn value(self) -> i32 {
        match self {
            PieceType::Pawn => 100,
            PieceType::Knight => 320,
            PieceType::Bishop => 330,
            PieceType::Rook => 500,
            PieceType::Queen => 900,
            PieceType::King => 20000,
        }
    }

    /// Get the character representation (uppercase)
    pub const fn to_char(self) -> char {
        match self {
            PieceType::King => 'K',
            PieceType::Queen => 'Q',
            PieceType::Rook => 'R',
            PieceType::Bishop => 'B',
            PieceType::Knight => 'N',
            PieceType::Pawn => 'P',
        }
    }
}

impl fmt::Display for PieceType {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}", self.to_char())
    }
}

/// A chess piece with both type and color
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct Piece {
    pub piece_type: PieceType,
    pub color: Color,
}

impl Piece {
    /// Create a new piece
    pub const fn new(piece_type: PieceType, color: Color) -> Self {
        Self { piece_type, color }
    }

    /// Convert piece to character (uppercase for White, lowercase for Black)
    pub fn to_char(self) -> char {
        let ch = self.piece_type.to_char();
        if self.color == Color::White {
            ch
        } else {
            ch.to_ascii_lowercase()
        }
    }

    /// Parse a piece from a character
    pub fn from_char(ch: char) -> Option<Piece> {
        let piece_type = PieceType::from_char(ch)?;
        let color = if ch.is_ascii_uppercase() {
            Color::White
        } else {
            Color::Black
        };
        Some(Piece::new(piece_type, color))
    }

    /// Get the piece value
    pub const fn value(self) -> i32 {
        self.piece_type.value()
    }
}

impl fmt::Display for Piece {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}", self.to_char())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_color_opposite() {
        assert_eq!(Color::White.opposite(), Color::Black);
        assert_eq!(Color::Black.opposite(), Color::White);
    }

    #[test]
    fn test_piece_type_from_char() {
        assert_eq!(PieceType::from_char('K'), Some(PieceType::King));
        assert_eq!(PieceType::from_char('k'), Some(PieceType::King));
    }

    #[test]
    fn test_piece_to_char() {
        let white_king = Piece::new(PieceType::King, Color::White);
        assert_eq!(white_king.to_char(), 'K');

        let black_king = Piece::new(PieceType::King, Color::Black);
        assert_eq!(black_king.to_char(), 'k');
    }
}
