"""
Type-safe board state representation with state transitions.

Uses Protocol and Generic types to encode whose turn it is at the type level,
allowing the type checker to verify proper alternation of moves.
"""

from typing import Protocol, Generic, TypeVar
from lib.types.piece import Color


class GameState(Protocol):
    """
    Base protocol for game state.
    
    The game state encodes whose turn it is to move at the type level.
    """
    @property
    def color_to_move(self) -> Color:
        """The color that should move in this state."""
        ...


class WhiteToMove(GameState):
    """State indicating it is White's turn to move."""
    
    @property
    def color_to_move(self) -> Color:
        return Color.WHITE


class BlackToMove(GameState):
    """State indicating it is Black's turn to move."""
    
    @property
    def color_to_move(self) -> Color:
        return Color.BLACK


# Type variable for game state
S = TypeVar('S', bound=GameState, covariant=True)


# Runtime instances for state tracking
_WHITE_TO_MOVE = WhiteToMove()
_BLACK_TO_MOVE = BlackToMove()


def white_to_move_state() -> WhiteToMove:
    """Get the WhiteToMove state instance."""
    return _WHITE_TO_MOVE


def black_to_move_state() -> BlackToMove:
    """Get the BlackToMove state instance."""
    return _BLACK_TO_MOVE


def state_from_color(color: Color) -> GameState:
    """
    Get the game state for the given color.
    
    Args:
        color: The color to move
        
    Returns:
        Corresponding GameState (WhiteToMove or BlackToMove)
    """
    return _WHITE_TO_MOVE if color == Color.WHITE else _BLACK_TO_MOVE


def opposite_state(state: GameState) -> GameState:
    """
    Get the opposite game state.
    
    Args:
        state: Current game state
        
    Returns:
        The opposite state (White -> Black, Black -> White)
    """
    if isinstance(state, WhiteToMove):
        return _BLACK_TO_MOVE
    return _WHITE_TO_MOVE


# Helper type for state transitions
def next_state_for_color(color: Color) -> GameState:
    """
    Get the next state after the given color moves.
    
    Args:
        color: The color that just moved
        
    Returns:
        The state for the opposite color to move
    """
    return _BLACK_TO_MOVE if color == Color.WHITE else _WHITE_TO_MOVE
