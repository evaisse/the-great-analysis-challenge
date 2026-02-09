"""
Type-safe Rank and File types using Literal for compile-time validation.

Rank and File are restricted to values 0-7, representing the 8 ranks and files
of a chess board.
"""

from typing import Literal, get_args

# Literal types for type-safe rank and file values
Rank = Literal[0, 1, 2, 3, 4, 5, 6, 7]
File = Literal[0, 1, 2, 3, 4, 5, 6, 7]

# Constants for ranks (more readable than raw numbers)
RANK_1: Rank = 0
RANK_2: Rank = 1
RANK_3: Rank = 2
RANK_4: Rank = 3
RANK_5: Rank = 4
RANK_6: Rank = 5
RANK_7: Rank = 6
RANK_8: Rank = 7

# Constants for files (more readable than raw numbers)
FILE_A: File = 0
FILE_B: File = 1
FILE_C: File = 2
FILE_D: File = 3
FILE_E: File = 4
FILE_F: File = 5
FILE_G: File = 6
FILE_H: File = 7


def is_valid_rank(value: int) -> bool:
    """
    Check if a value is a valid rank (0-7).
    
    Args:
        value: Integer to check
        
    Returns:
        True if value is 0-7, False otherwise
    """
    return 0 <= value <= 7


def is_valid_file(value: int) -> bool:
    """
    Check if a value is a valid file (0-7).
    
    Args:
        value: Integer to check
        
    Returns:
        True if value is 0-7, False otherwise
    """
    return 0 <= value <= 7


def rank_to_string(rank: Rank) -> str:
    """
    Convert rank to string notation (1-8).
    
    Args:
        rank: Rank value (0-7)
        
    Returns:
        String representation ("1"-"8")
    """
    return str(rank + 1)


def file_to_string(file: File) -> str:
    """
    Convert file to string notation (a-h).
    
    Args:
        file: File value (0-7)
        
    Returns:
        String representation ("a"-"h")
    """
    return chr(ord('a') + file)


def string_to_rank(s: str) -> Rank | None:
    """
    Parse rank from string notation.
    
    Args:
        s: String representation ("1"-"8")
        
    Returns:
        Rank value (0-7) if valid, None otherwise
    """
    try:
        value = int(s) - 1
        if is_valid_rank(value):
            return value  # type: ignore
    except ValueError:
        pass
    return None


def string_to_file(s: str) -> File | None:
    """
    Parse file from string notation.
    
    Args:
        s: String representation ("a"-"h")
        
    Returns:
        File value (0-7) if valid, None otherwise
    """
    if len(s) == 1:
        value = ord(s.lower()) - ord('a')
        if is_valid_file(value):
            return value  # type: ignore
    return None


# Helper to get all valid rank values at runtime
def all_ranks() -> tuple[Rank, ...]:
    """Return all valid rank values."""
    return (0, 1, 2, 3, 4, 5, 6, 7)


# Helper to get all valid file values at runtime
def all_files() -> tuple[File, ...]:
    """Return all valid file values."""
    return (0, 1, 2, 3, 4, 5, 6, 7)
