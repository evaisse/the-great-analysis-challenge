use std::fmt;
use std::ops::{Add, Sub, Div, Rem};

/// Type-safe square representation guaranteeing values 0-63
/// This is the new type-safe version (PRD-04). Use TypedSquare for new code.
/// For legacy compatibility, TypedSquare = usize is still available.
#[derive(Copy, Clone, Debug, PartialEq, Eq, Hash)]
pub struct TypedSquare(u8);

impl TypedSquare {
    /// Create a new TypedSquare from a u8 value (panics if out of bounds, use TryFrom for validation)
    pub const fn new(value: u8) -> Self {
        assert!(value < 64, "TypedSquare value must be 0-63");
        TypedSquare(value)
    }

    /// Get the underlying u8 value
    pub const fn value(self) -> u8 {
        self.0
    }

    /// Convert to usize for array indexing
    pub const fn as_usize(self) -> usize {
        self.0 as usize
    }

    /// Get the rank (0-7, where 0 is rank 1, 7 is rank 8)
    pub const fn rank(self) -> u8 {
        self.0 / 8
    }

    /// Get the file (0-7, where 0 is file a, 7 is file h)
    pub const fn file(self) -> u8 {
        self.0 % 8
    }

    /// Convert to algebraic notation (e.g., "e4")
    pub fn to_algebraic(self) -> String {
        const FILES: [char; 8] = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
        const RANKS: [char; 8] = ['1', '2', '3', '4', '5', '6', '7', '8'];
        format!("{}{}", FILES[self.file() as usize], RANKS[self.rank() as usize])
    }

    /// Parse from algebraic notation (e.g., "e4")
    pub fn from_algebraic(s: &str) -> Result<Self, &'static str> {
        if s.len() != 2 {
            return Err("Invalid algebraic notation length");
        }

        let chars: Vec<char> = s.chars().collect();
        let file = match chars[0] {
            'a'..='h' => chars[0] as u8 - b'a',
            _ => return Err("Invalid file"),
        };
        let rank = match chars[1] {
            '1'..='8' => chars[1] as u8 - b'1',
            _ => return Err("Invalid rank"),
        };

        Ok(TypedSquare(rank * 8 + file))
    }

    /// Create a square from rank and file (0-7 each)
    pub const fn from_rank_file(rank: u8, file: u8) -> Result<Self, &'static str> {
        if rank >= 8 || file >= 8 {
            return Err("Rank and file must be 0-7");
        }
        Ok(TypedSquare(rank * 8 + file))
    }

    /// Offset the square by a delta (can fail if out of bounds)
    pub fn offset(self, file_delta: i8, rank_delta: i8) -> Option<Self> {
        let file = self.file() as i8 + file_delta;
        let rank = self.rank() as i8 + rank_delta;
        
        if file < 0 || file >= 8 || rank < 0 || rank >= 8 {
            return None;
        }
        
        Some(TypedSquare((rank * 8 + file) as u8))
    }

    /// Distance between two squares (Chebyshev distance)
    pub fn distance(self, other: TypedSquare) -> u8 {
        let file_diff = (self.file() as i8 - other.file() as i8).abs();
        let rank_diff = (self.rank() as i8 - other.rank() as i8).abs();
        file_diff.max(rank_diff) as u8
    }
}

impl TryFrom<u8> for TypedSquare {
    type Error = &'static str;

    fn try_from(value: u8) -> Result<Self, Self::Error> {
        if value < 64 {
            Ok(TypedSquare(value))
        } else {
            Err("TypedSquare value must be 0-63")
        }
    }
}

impl From<TypedSquare> for u8 {
    fn from(square: TypedSquare) -> u8 {
        square.0
    }
}

impl From<TypedSquare> for usize {
    fn from(square: TypedSquare) -> usize {
        square.0 as usize
    }
}

impl From<usize> for TypedSquare {
    fn from(value: usize) -> Self {
        TypedSquare(value.min(63) as u8)
    }
}

// Allow comparing with literals like `rank * 8 + 6`
impl PartialEq<i32> for TypedSquare {
    fn eq(&self, other: &i32) -> bool {
        self.0 as i32 == *other
    }
}

// Allow creating squares from constant expressions
impl TypedSquare {
    /// Create a square from a u8 value at compile time
    pub const fn from_u8_unchecked(value: u8) -> Self {
        TypedSquare(value)
    }
}

impl fmt::Display for TypedSquare {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}", self.to_algebraic())
    }
}

// Arithmetic operations for TypedSquare
// Note: These use saturating arithmetic for backward compatibility with existing code
// that performs arithmetic on squares. In new code, prefer using offset() which returns Option.

impl Add<u8> for TypedSquare {
    type Output = Self;

    fn add(self, rhs: u8) -> Self::Output {
        // Saturate to maintain type invariant (0-63)
        TypedSquare(self.0.saturating_add(rhs).min(63))
    }
}

impl Sub<u8> for TypedSquare {
    type Output = Self;

    fn sub(self, rhs: u8) -> Self::Output {
        TypedSquare(self.0.saturating_sub(rhs))
    }
}

impl Add<i32> for TypedSquare {
    type Output = Self;

    fn add(self, rhs: i32) -> Self::Output {
        if rhs >= 0 {
            TypedSquare((self.0 as i32 + rhs).clamp(0, 63) as u8)
        } else {
            TypedSquare((self.0 as i32 + rhs).max(0) as u8)
        }
    }
}

impl Sub<i32> for TypedSquare {
    type Output = Self;

    fn sub(self, rhs: i32) -> Self::Output {
        if rhs >= 0 {
            TypedSquare((self.0 as i32 - rhs).max(0) as u8)
        } else {
            TypedSquare((self.0 as i32 - rhs).clamp(0, 63) as u8)
        }
    }
}

impl Div<u8> for TypedSquare {
    type Output = u8;

    fn div(self, rhs: u8) -> Self::Output {
        self.0 / rhs
    }
}

impl Rem<u8> for TypedSquare {
    type Output = u8;

    fn rem(self, rhs: u8) -> Self::Output {
        self.0 % rhs
    }
}

impl PartialEq<u8> for TypedSquare {
    fn eq(&self, other: &u8) -> bool {
        self.0 == *other
    }
}

impl PartialEq<usize> for TypedSquare {
    fn eq(&self, other: &usize) -> bool {
        self.0 as usize == *other
    }
}

// Constants for common squares
#[allow(dead_code)]
impl TypedSquare {
    pub const A1: TypedSquare = TypedSquare(0);
    pub const B1: TypedSquare = TypedSquare(1);
    pub const C1: TypedSquare = TypedSquare(2);
    pub const D1: TypedSquare = TypedSquare(3);
    pub const E1: TypedSquare = TypedSquare(4);
    pub const F1: TypedSquare = TypedSquare(5);
    pub const G1: TypedSquare = TypedSquare(6);
    pub const H1: TypedSquare = TypedSquare(7);
    
    pub const A8: TypedSquare = TypedSquare(56);
    pub const B8: TypedSquare = TypedSquare(57);
    pub const C8: TypedSquare = TypedSquare(58);
    pub const D8: TypedSquare = TypedSquare(59);
    pub const E8: TypedSquare = TypedSquare(60);
    pub const F8: TypedSquare = TypedSquare(61);
    pub const G8: TypedSquare = TypedSquare(62);
    pub const H8: TypedSquare = TypedSquare(63);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_square_creation() {
        let sq = TypedSquare::try_from(28u8).unwrap();
        assert_eq!(sq.value(), 28);
    }

    #[test]
    fn test_square_invalid() {
        assert!(TypedSquare::try_from(64u8).is_err());
    }

    #[test]
    fn test_rank_file() {
        let e4 = TypedSquare::try_from(28u8).unwrap();
        assert_eq!(e4.rank(), 3);
        assert_eq!(e4.file(), 4);
    }

    #[test]
    fn test_algebraic() {
        let e4 = TypedSquare::from_algebraic("e4").unwrap();
        assert_eq!(e4.value(), 28);
        assert_eq!(e4.to_algebraic(), "e4");
    }
}
