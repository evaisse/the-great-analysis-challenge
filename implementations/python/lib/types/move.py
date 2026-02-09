"""
Type-safe Move representation with validation states using Protocol and TypeGuard.

Uses Protocol to distinguish between Legal and Unchecked moves at the type level,
allowing the type checker to enforce that only validated moves are applied to the board.
"""

from typing import Protocol, TypeGuard, Generic, TypeVar, Optional
from dataclasses import dataclass, field
from lib.types.square import Square
from lib.types.piece import PieceType, Piece

# Validation state protocols
class MoveValidation(Protocol):
    """Base protocol for move validation states."""
    pass


class Legal(MoveValidation):
    """
    Marker protocol indicating a move has been validated as legal.
    
    Moves with this validation state have been checked against:
    - Piece movement rules
    - Board boundaries
    - Check detection
    - Special move conditions (castling, en passant)
    """
    pass


class Unchecked(MoveValidation):
    """
    Marker protocol indicating a move has not been validated.
    
    Moves in this state may be:
    - Parsed from user input
    - Generated as pseudo-legal moves
    - Invalid or illegal
    """
    pass


# Type variable for validation state
V = TypeVar('V', bound=MoveValidation, covariant=True)


@dataclass(frozen=True)
class Move(Generic[V]):
    """
    Immutable chess move with generic validation state.
    
    The validation state is tracked at the type level, allowing the type checker
    to enforce that only Legal moves are applied to the board.
    
    Type parameters:
        V: Validation state (Legal or Unchecked)
    """
    from_square: Square
    to_square: Square
    promotion: Optional[PieceType] = None
    
    # Metadata fields (not part of move identity)
    captured_piece: Optional[Piece] = field(default=None, compare=False)
    is_castling: bool = field(default=False, compare=False)
    is_en_passant: bool = field(default=False, compare=False)
    en_passant_target: Optional[Square] = field(default=None, compare=False)
    
    def to_algebraic(self) -> str:
        """
        Convert move to algebraic notation.
        
        Returns:
            Algebraic notation string (e.g., "e2e4", "e7e8Q")
        """
        from lib.types.square import square_to_algebraic
        
        result = square_to_algebraic(self.from_square) + square_to_algebraic(self.to_square)
        
        if self.promotion:
            result += self.promotion.value
        
        return result
    
    def with_promotion(self, promotion: PieceType) -> 'Move[V]':
        """Return a new move with the specified promotion piece."""
        return Move(
            from_square=self.from_square,
            to_square=self.to_square,
            promotion=promotion,
            captured_piece=self.captured_piece,
            is_castling=self.is_castling,
            is_en_passant=self.is_en_passant,
            en_passant_target=self.en_passant_target
        )
    
    def with_metadata(
        self,
        captured_piece: Optional[Piece] = None,
        is_castling: bool = False,
        is_en_passant: bool = False,
        en_passant_target: Optional[Square] = None
    ) -> 'Move[V]':
        """Return a new move with updated metadata fields."""
        return Move(
            from_square=self.from_square,
            to_square=self.to_square,
            promotion=self.promotion,
            captured_piece=captured_piece,
            is_castling=is_castling,
            is_en_passant=is_en_passant,
            en_passant_target=en_passant_target
        )


def make_unchecked_move(from_square: Square, to_square: Square, 
                       promotion: Optional[PieceType] = None) -> Move[Unchecked]:
    """
    Create an unchecked move.
    
    Args:
        from_square: Origin square
        to_square: Destination square
        promotion: Optional promotion piece type
        
    Returns:
        An unchecked Move that must be validated before application
    """
    return Move[Unchecked](from_square=from_square, to_square=to_square, promotion=promotion)


def make_legal_move(from_square: Square, to_square: Square,
                   promotion: Optional[PieceType] = None,
                   captured_piece: Optional[Piece] = None,
                   is_castling: bool = False,
                   is_en_passant: bool = False,
                   en_passant_target: Optional[Square] = None) -> Move[Legal]:
    """
    Create a legal move with full metadata.
    
    This should only be called by move generation/validation code that has
    verified the move is legal.
    
    Args:
        from_square: Origin square
        to_square: Destination square
        promotion: Optional promotion piece type
        captured_piece: Piece captured by this move (if any)
        is_castling: Whether this is a castling move
        is_en_passant: Whether this is an en passant capture
        en_passant_target: Target square for en passant (if applicable)
        
    Returns:
        A Legal Move that can be applied to the board
    """
    return Move[Legal](
        from_square=from_square,
        to_square=to_square,
        promotion=promotion,
        captured_piece=captured_piece,
        is_castling=is_castling,
        is_en_passant=is_en_passant,
        en_passant_target=en_passant_target
    )


def parse_algebraic_move(notation: str) -> Optional[Move[Unchecked]]:
    """
    Parse algebraic notation into an unchecked move.
    
    Args:
        notation: Algebraic move notation (e.g., "e2e4", "e7e8Q")
        
    Returns:
        An unchecked Move if parsing succeeds, None otherwise
        
    Examples:
        >>> move = parse_algebraic_move("e2e4")
        >>> move = parse_algebraic_move("a7a8Q")
    """
    from lib.types.square import make_square_from_algebraic
    
    if not notation or len(notation) < 4:
        return None
    
    from_square = make_square_from_algebraic(notation[0:2])
    to_square = make_square_from_algebraic(notation[2:4])
    
    if from_square is None or to_square is None:
        return None
    
    # Parse promotion
    promotion = None
    if len(notation) > 4:
        try:
            promotion = PieceType.from_char(notation[4])
        except ValueError:
            return None
    
    return make_unchecked_move(from_square, to_square, promotion)


# TypeGuard for move validation
def is_legal_move(move: Move[Unchecked]) -> TypeGuard[Move[Legal]]:
    """
    Type guard that narrows Move[Unchecked] to Move[Legal].
    
    This is a type-level assertion and should only be used in validation
    code that has actually verified the move is legal.
    
    Args:
        move: An unchecked move
        
    Returns:
        Always True (this is a type guard, not runtime validation)
    """
    # This is a type guard - it tells the type checker that after this
    # function returns True, the move should be treated as Legal.
    # The actual validation logic lives elsewhere.
    return True


def cast_to_legal_move(move: Move[Unchecked]) -> Move[Legal]:
    """
    Cast an unchecked move to a legal move.
    
    This should only be called after actual validation has occurred.
    It's a utility for converting the validation state at the type level.
    
    Args:
        move: An unchecked move that has been validated
        
    Returns:
        The same move with Legal validation state
    """
    return Move[Legal](
        from_square=move.from_square,
        to_square=move.to_square,
        promotion=move.promotion,
        captured_piece=move.captured_piece,
        is_castling=move.is_castling,
        is_en_passant=move.is_en_passant,
        en_passant_target=move.en_passant_target
    )
