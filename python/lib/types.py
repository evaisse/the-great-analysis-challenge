"""
Type definitions for the chess engine.
"""

from typing import Optional, List, Tuple
from dataclasses import dataclass
from enum import Enum


class PieceType(Enum):
    """Chess piece types."""
    PAWN = 'P'
    KNIGHT = 'N'
    BISHOP = 'B'
    ROOK = 'R'
    QUEEN = 'Q'
    KING = 'K'


class Color(Enum):
    """Chess piece colors."""
    WHITE = 'white'
    BLACK = 'black'


@dataclass
class Piece:
    """Represents a chess piece."""
    type: PieceType
    color: Color
    
    def __str__(self) -> str:
        """Return the piece symbol."""
        symbol = self.type.value
        return symbol if self.color == Color.WHITE else symbol.lower()
    
    def is_white(self) -> bool:
        """Check if piece is white."""
        return self.color == Color.WHITE
    
    def is_black(self) -> bool:
        """Check if piece is black."""
        return self.color == Color.BLACK


@dataclass
class Move:
    """Represents a chess move."""
    from_row: int
    from_col: int
    to_row: int
    to_col: int
    promotion: Optional[PieceType] = None
    captured_piece: Optional[Piece] = None
    is_castling: bool = False
    is_en_passant: bool = False
    en_passant_target: Optional[Tuple[int, int]] = None
    
    @classmethod
    def from_algebraic(cls, move_str: str) -> Optional['Move']:
        """Parse algebraic notation into a Move object."""
        if not move_str or len(move_str) < 4:
            return None
        
        try:
            # Parse from square
            from_file = move_str[0].lower()
            from_rank = move_str[1]
            from_col = ord(from_file) - ord('a')
            from_row = int(from_rank) - 1
            
            # Parse to square
            to_file = move_str[2].lower()
            to_rank = move_str[3]
            to_col = ord(to_file) - ord('a')
            to_row = int(to_rank) - 1
            
            # Check bounds
            if not (0 <= from_row <= 7 and 0 <= from_col <= 7 and
                    0 <= to_row <= 7 and 0 <= to_col <= 7):
                return None
            
            # Parse promotion
            promotion = None
            if len(move_str) > 4:
                promo_char = move_str[4].upper()
                if promo_char in 'QRBN':
                    promotion = PieceType(promo_char)
            
            return cls(from_row, from_col, to_row, to_col, promotion)
            
        except (ValueError, IndexError):
            return None
    
    def to_algebraic(self) -> str:
        """Convert move to algebraic notation."""
        from_file = chr(ord('a') + self.from_col)
        from_rank = str(self.from_row + 1)
        to_file = chr(ord('a') + self.to_col)
        to_rank = str(self.to_row + 1)
        
        result = from_file + from_rank + to_file + to_rank
        
        if self.promotion:
            result += self.promotion.value
        
        return result
    
    def __eq__(self, other) -> bool:
        """Check move equality."""
        if not isinstance(other, Move):
            return False
        return (self.from_row == other.from_row and
                self.from_col == other.from_col and
                self.to_row == other.to_row and
                self.to_col == other.to_col and
                self.promotion == other.promotion)
    
    def __hash__(self) -> int:
        """Hash for move comparison."""
        return hash((self.from_row, self.from_col, self.to_row, self.to_col, self.promotion))


@dataclass
class CastlingRights:
    """Tracks castling availability."""
    white_kingside: bool = True
    white_queenside: bool = True
    black_kingside: bool = True
    black_queenside: bool = True
    
    def copy(self) -> 'CastlingRights':
        """Create a copy of castling rights."""
        return CastlingRights(
            self.white_kingside,
            self.white_queenside,
            self.black_kingside,
            self.black_queenside
        )
    
    def to_fen(self) -> str:
        """Convert to FEN castling string."""
        result = ""
        if self.white_kingside:
            result += "K"
        if self.white_queenside:
            result += "Q"
        if self.black_kingside:
            result += "k"
        if self.black_queenside:
            result += "q"
        return result if result else "-"


@dataclass
class GameState:
    """Represents complete game state for undo functionality."""
    castling_rights: CastlingRights
    en_passant_target: Optional[Tuple[int, int]]
    halfmove_clock: int
    fullmove_number: int
    captured_piece: Optional[Piece] = None