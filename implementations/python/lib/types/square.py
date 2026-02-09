"""
Type-safe Square representation using NewType with validation.

Square is a NewType wrapper around int that guarantees values 0-63,
representing the 64 squares of a chess board.
"""

from typing import NewType, Optional

# NewType for type-safe square representation
# Values 0-63 map to a1-h8 (row-major: 0=a1, 1=b1, ..., 63=h8)
Square = NewType('Square', int)

# Type aliases for clarity
Rank = int  # 0-7 (rank 1-8)
File = int  # 0-7 (file a-h)


def make_square(value: int) -> Square:
    """
    Create a validated Square from an integer.
    
    Args:
        value: Integer between 0 and 63 (inclusive)
        
    Returns:
        A validated Square
        
    Raises:
        ValueError: If value is outside valid range
        
    Examples:
        >>> sq = make_square(0)   # a1
        >>> sq = make_square(63)  # h8
        >>> sq = make_square(28)  # e4
    """
    if not 0 <= value < 64:
        raise ValueError(f"Square must be 0-63, got {value}")
    return Square(value)


def make_square_from_coords(row: int, col: int) -> Square:
    """
    Create a Square from row/column coordinates.
    
    Args:
        row: Rank index (0-7)
        col: File index (0-7)
        
    Returns:
        A validated Square
        
    Raises:
        ValueError: If coordinates are invalid
        
    Examples:
        >>> sq = make_square_from_coords(0, 0)  # a1
        >>> sq = make_square_from_coords(3, 4)  # e4
    """
    if not (0 <= row < 8 and 0 <= col < 8):
        raise ValueError(f"Invalid coordinates: row={row}, col={col}")
    return Square(row * 8 + col)


def make_square_from_algebraic(notation: str) -> Optional[Square]:
    """
    Parse algebraic notation into a Square.
    
    Args:
        notation: Algebraic square notation (e.g., "e4", "a1")
        
    Returns:
        A Square if parsing succeeds, None otherwise
        
    Examples:
        >>> sq = make_square_from_algebraic("e4")
        >>> sq = make_square_from_algebraic("a1")
    """
    if not notation or len(notation) != 2:
        return None
    
    try:
        file_char = notation[0].lower()
        rank_char = notation[1]
        
        col = ord(file_char) - ord('a')
        row = int(rank_char) - 1
        
        if 0 <= row < 8 and 0 <= col < 8:
            return make_square_from_coords(row, col)
    except (ValueError, IndexError):
        pass
    
    return None


def square_to_coords(square: Square) -> tuple[int, int]:
    """
    Convert Square to (row, col) coordinates.
    
    Args:
        square: A validated Square
        
    Returns:
        Tuple of (row, col) where both are 0-7
        
    Examples:
        >>> square_to_coords(make_square(0))   # (0, 0) = a1
        >>> square_to_coords(make_square(28))  # (3, 4) = e4
    """
    value = int(square)
    return (value // 8, value % 8)


def square_to_algebraic(square: Square) -> str:
    """
    Convert Square to algebraic notation.
    
    Args:
        square: A validated Square
        
    Returns:
        Algebraic notation string (e.g., "e4")
        
    Examples:
        >>> square_to_algebraic(make_square(0))   # "a1"
        >>> square_to_algebraic(make_square(28))  # "e4"
    """
    row, col = square_to_coords(square)
    file_char = chr(ord('a') + col)
    rank_char = str(row + 1)
    return file_char + rank_char


def square_rank(square: Square) -> Rank:
    """
    Get the rank (row) of a Square.
    
    Args:
        square: A validated Square
        
    Returns:
        Rank index (0-7)
    """
    return int(square) // 8


def square_file(square: Square) -> File:
    """
    Get the file (column) of a Square.
    
    Args:
        square: A validated Square
        
    Returns:
        File index (0-7)
    """
    return int(square) % 8


def square_offset(square: Square, rank_delta: int, file_delta: int) -> Optional[Square]:
    """
    Apply an offset to a Square, returning None if the result is off-board.
    
    Args:
        square: A validated Square
        rank_delta: Number of ranks to move (can be negative)
        file_delta: Number of files to move (can be negative)
        
    Returns:
        A new Square if the result is valid, None otherwise
        
    Examples:
        >>> sq = make_square(0)  # a1
        >>> square_offset(sq, 1, 1)  # b2
        >>> square_offset(sq, -1, 0)  # None (off board)
    """
    row, col = square_to_coords(square)
    new_row = row + rank_delta
    new_col = col + file_delta
    
    if 0 <= new_row < 8 and 0 <= new_col < 8:
        return make_square_from_coords(new_row, new_col)
    return None


def square_distance(sq1: Square, sq2: Square) -> int:
    """
    Calculate the Chebyshev distance (king distance) between two squares.
    
    Args:
        sq1: First square
        sq2: Second square
        
    Returns:
        Maximum of absolute rank and file differences
    """
    row1, col1 = square_to_coords(sq1)
    row2, col2 = square_to_coords(sq2)
    return max(abs(row1 - row2), abs(col1 - col2))
