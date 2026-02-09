"""
Type-safe CastlingRights representation using dataclass.

Provides an immutable representation of castling rights for both colors.
"""

from dataclasses import dataclass
from typing import Optional


@dataclass(frozen=True)
class CastlingRights:
    """
    Immutable representation of castling rights.
    
    Using frozen dataclass ensures immutability, which helps type checkers
    reason about state changes more reliably.
    """
    white_kingside: bool = True
    white_queenside: bool = True
    black_kingside: bool = True
    black_queenside: bool = True
    
    def with_white_kingside(self, value: bool) -> 'CastlingRights':
        """Return a new CastlingRights with white kingside right modified."""
        return CastlingRights(
            white_kingside=value,
            white_queenside=self.white_queenside,
            black_kingside=self.black_kingside,
            black_queenside=self.black_queenside
        )
    
    def with_white_queenside(self, value: bool) -> 'CastlingRights':
        """Return a new CastlingRights with white queenside right modified."""
        return CastlingRights(
            white_kingside=self.white_kingside,
            white_queenside=value,
            black_kingside=self.black_kingside,
            black_queenside=self.black_queenside
        )
    
    def with_black_kingside(self, value: bool) -> 'CastlingRights':
        """Return a new CastlingRights with black kingside right modified."""
        return CastlingRights(
            white_kingside=self.white_kingside,
            white_queenside=self.white_queenside,
            black_kingside=value,
            black_queenside=self.black_queenside
        )
    
    def with_black_queenside(self, value: bool) -> 'CastlingRights':
        """Return a new CastlingRights with black queenside right modified."""
        return CastlingRights(
            white_kingside=self.white_kingside,
            white_queenside=self.white_queenside,
            black_kingside=self.black_kingside,
            black_queenside=value
        )
    
    def without_white_castling(self) -> 'CastlingRights':
        """Return a new CastlingRights with all white castling rights removed."""
        return CastlingRights(
            white_kingside=False,
            white_queenside=False,
            black_kingside=self.black_kingside,
            black_queenside=self.black_queenside
        )
    
    def without_black_castling(self) -> 'CastlingRights':
        """Return a new CastlingRights with all black castling rights removed."""
        return CastlingRights(
            white_kingside=self.white_kingside,
            white_queenside=self.white_queenside,
            black_kingside=False,
            black_queenside=False
        )
    
    def to_fen(self) -> str:
        """
        Convert to FEN castling string.
        
        Returns:
            FEN castling rights string (e.g., "KQkq", "Kq", "-")
        """
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
    
    @classmethod
    def from_fen(cls, fen_string: str) -> 'CastlingRights':
        """
        Parse castling rights from FEN string.
        
        Args:
            fen_string: FEN castling rights string (e.g., "KQkq", "Kq", "-")
            
        Returns:
            CastlingRights object
        """
        if fen_string == "-":
            return cls(False, False, False, False)
        
        return cls(
            white_kingside='K' in fen_string,
            white_queenside='Q' in fen_string,
            black_kingside='k' in fen_string,
            black_queenside='q' in fen_string
        )
    
    def has_any_rights(self) -> bool:
        """Check if any castling rights remain."""
        return (self.white_kingside or self.white_queenside or
                self.black_kingside or self.black_queenside)
    
    def has_white_rights(self) -> bool:
        """Check if white has any castling rights."""
        return self.white_kingside or self.white_queenside
    
    def has_black_rights(self) -> bool:
        """Check if black has any castling rights."""
        return self.black_kingside or self.black_queenside


# Predefined constants for common castling rights states
CASTLING_ALL = CastlingRights(True, True, True, True)
CASTLING_NONE = CastlingRights(False, False, False, False)
CASTLING_WHITE_ONLY = CastlingRights(True, True, False, False)
CASTLING_BLACK_ONLY = CastlingRights(False, False, True, True)
