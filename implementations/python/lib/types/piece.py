"""
Type-safe Color, PieceType, and Piece representations using Literal types.

Uses Literal types for fixed value sets to provide better type checking.
"""

from typing import Literal
from dataclasses import dataclass
from enum import Enum

# Type-safe color using Literal
ColorLiteral = Literal["white", "black"]


class Color(Enum):
    """Chess piece colors with type-safe values."""
    WHITE = "white"
    BLACK = "black"
    
    def opposite(self) -> 'Color':
        """Return the opposite color."""
        return Color.BLACK if self == Color.WHITE else Color.WHITE
    
    def to_literal(self) -> ColorLiteral:
        """Convert to Literal type for type checking."""
        return self.value


class PieceType(Enum):
    """Chess piece types with single-character values."""
    PAWN = 'P'
    KNIGHT = 'N'
    BISHOP = 'B'
    ROOK = 'R'
    QUEEN = 'Q'
    KING = 'K'
    
    @classmethod
    def from_char(cls, char: str) -> 'PieceType':
        """
        Parse piece type from character.
        
        Args:
            char: Single character (P/N/B/R/Q/K, case-insensitive)
            
        Returns:
            Corresponding PieceType
            
        Raises:
            ValueError: If character is invalid
        """
        upper_char = char.upper()
        for piece_type in cls:
            if piece_type.value == upper_char:
                return piece_type
        raise ValueError(f"Invalid piece character: {char}")
    
    def is_sliding(self) -> bool:
        """Check if this piece type moves by sliding (bishop, rook, queen)."""
        return self in (PieceType.BISHOP, PieceType.ROOK, PieceType.QUEEN)
    
    def material_value(self) -> int:
        """
        Get the standard material value of this piece type.
        
        Returns:
            Material value (pawn=100, knight=320, bishop=330, rook=500, queen=900, king=0)
        """
        values = {
            PieceType.PAWN: 100,
            PieceType.KNIGHT: 320,
            PieceType.BISHOP: 330,
            PieceType.ROOK: 500,
            PieceType.QUEEN: 900,
            PieceType.KING: 0,  # King has no material value (game ends if captured)
        }
        return values[self]


@dataclass(frozen=True)
class Piece:
    """
    Immutable representation of a chess piece.
    
    Using frozen dataclass for immutability, which helps type checkers
    reason about piece state more reliably.
    """
    piece_type: PieceType
    color: Color
    
    def __str__(self) -> str:
        """Return the piece symbol (uppercase=white, lowercase=black)."""
        symbol = self.piece_type.value
        return symbol if self.color == Color.WHITE else symbol.lower()
    
    def is_white(self) -> bool:
        """Check if piece is white."""
        return self.color == Color.WHITE
    
    def is_black(self) -> bool:
        """Check if piece is black."""
        return self.color == Color.BLACK
    
    def material_value(self) -> int:
        """Get the material value of this piece."""
        return self.piece_type.material_value()
    
    @classmethod
    def from_char(cls, char: str) -> 'Piece':
        """
        Parse piece from character.
        
        Args:
            char: Single character (uppercase=white, lowercase=black)
            
        Returns:
            Corresponding Piece
            
        Examples:
            >>> Piece.from_char('P')  # White pawn
            >>> Piece.from_char('k')  # Black king
        """
        color = Color.WHITE if char.isupper() else Color.BLACK
        piece_type = PieceType.from_char(char)
        return cls(piece_type, color)


# Predefined piece constants for convenience
WHITE_PAWN = Piece(PieceType.PAWN, Color.WHITE)
WHITE_KNIGHT = Piece(PieceType.KNIGHT, Color.WHITE)
WHITE_BISHOP = Piece(PieceType.BISHOP, Color.WHITE)
WHITE_ROOK = Piece(PieceType.ROOK, Color.WHITE)
WHITE_QUEEN = Piece(PieceType.QUEEN, Color.WHITE)
WHITE_KING = Piece(PieceType.KING, Color.WHITE)

BLACK_PAWN = Piece(PieceType.PAWN, Color.BLACK)
BLACK_KNIGHT = Piece(PieceType.KNIGHT, Color.BLACK)
BLACK_BISHOP = Piece(PieceType.BISHOP, Color.BLACK)
BLACK_ROOK = Piece(PieceType.ROOK, Color.BLACK)
BLACK_QUEEN = Piece(PieceType.QUEEN, Color.BLACK)
BLACK_KING = Piece(PieceType.KING, Color.BLACK)
