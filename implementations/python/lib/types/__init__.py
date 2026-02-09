"""
Type-safe chess types package.

This package provides advanced type-safe abstractions for chess concepts:
- Square: NewType with validation (0-63 values only)
- Move[Legal] vs Move[Unchecked]: Protocol-based validation states
- Board state protocols: WhiteToMove vs BlackToMove
- Immutable pieces and castling rights
- Literal types for Rank and File

All types are designed to catch errors at the type-checking stage (mypy/pyright)
rather than at runtime.
"""

# Square types and utilities
from lib.types.square import (
    Square,
    Rank,
    File,
    make_square,
    make_square_from_coords,
    make_square_from_algebraic,
    square_to_coords,
    square_to_algebraic,
    square_rank,
    square_file,
    square_offset,
    square_distance,
)

# Piece types
from lib.types.piece import (
    Color,
    ColorLiteral,
    PieceType,
    Piece,
    WHITE_PAWN,
    WHITE_KNIGHT,
    WHITE_BISHOP,
    WHITE_ROOK,
    WHITE_QUEEN,
    WHITE_KING,
    BLACK_PAWN,
    BLACK_KNIGHT,
    BLACK_BISHOP,
    BLACK_ROOK,
    BLACK_QUEEN,
    BLACK_KING,
)

# Rank and File types
from lib.types.rank_file import (
    Rank as RankLiteral,
    File as FileLiteral,
    RANK_1, RANK_2, RANK_3, RANK_4, RANK_5, RANK_6, RANK_7, RANK_8,
    FILE_A, FILE_B, FILE_C, FILE_D, FILE_E, FILE_F, FILE_G, FILE_H,
    is_valid_rank,
    is_valid_file,
    rank_to_string,
    file_to_string,
    string_to_rank,
    string_to_file,
    all_ranks,
    all_files,
)

# Castling rights
from lib.types.castling import (
    CastlingRights,
    CASTLING_ALL,
    CASTLING_NONE,
    CASTLING_WHITE_ONLY,
    CASTLING_BLACK_ONLY,
)

# Move types with validation states
from lib.types.move import (
    Move,
    MoveValidation,
    Legal,
    Unchecked,
    make_unchecked_move,
    make_legal_move,
    parse_algebraic_move,
    is_legal_move,
    cast_to_legal_move,
)

# Board state protocols
from lib.types.board_state import (
    GameState,
    WhiteToMove,
    BlackToMove,
    white_to_move_state,
    black_to_move_state,
    state_from_color,
    opposite_state,
    next_state_for_color,
)

__all__ = [
    # Square
    'Square',
    'Rank',
    'File',
    'make_square',
    'make_square_from_coords',
    'make_square_from_algebraic',
    'square_to_coords',
    'square_to_algebraic',
    'square_rank',
    'square_file',
    'square_offset',
    'square_distance',
    
    # Piece
    'Color',
    'ColorLiteral',
    'PieceType',
    'Piece',
    'WHITE_PAWN',
    'WHITE_KNIGHT',
    'WHITE_BISHOP',
    'WHITE_ROOK',
    'WHITE_QUEEN',
    'WHITE_KING',
    'BLACK_PAWN',
    'BLACK_KNIGHT',
    'BLACK_BISHOP',
    'BLACK_ROOK',
    'BLACK_QUEEN',
    'BLACK_KING',
    
    # Rank and File
    'RankLiteral',
    'FileLiteral',
    'RANK_1', 'RANK_2', 'RANK_3', 'RANK_4', 'RANK_5', 'RANK_6', 'RANK_7', 'RANK_8',
    'FILE_A', 'FILE_B', 'FILE_C', 'FILE_D', 'FILE_E', 'FILE_F', 'FILE_G', 'FILE_H',
    'is_valid_rank',
    'is_valid_file',
    'rank_to_string',
    'file_to_string',
    'string_to_rank',
    'string_to_file',
    'all_ranks',
    'all_files',
    
    # Castling
    'CastlingRights',
    'CASTLING_ALL',
    'CASTLING_NONE',
    'CASTLING_WHITE_ONLY',
    'CASTLING_BLACK_ONLY',
    
    # Move
    'Move',
    'MoveValidation',
    'Legal',
    'Unchecked',
    'make_unchecked_move',
    'make_legal_move',
    'parse_algebraic_move',
    'is_legal_move',
    'cast_to_legal_move',
    
    # Board state
    'GameState',
    'WhiteToMove',
    'BlackToMove',
    'white_to_move_state',
    'black_to_move_state',
    'state_from_color',
    'opposite_state',
    'next_state_for_color',
]
