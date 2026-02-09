"""Mobility evaluation - rewards pieces with more squares to move to."""

from typing import List, Tuple, Optional
from lib.board import Board
from lib.types import Color, PieceType

KNIGHT_MOBILITY: List[int] = [-15, -5, 0, 5, 10, 15, 20, 22, 24]
BISHOP_MOBILITY: List[int] = [-20, -10, 0, 5, 10, 15, 18, 21, 24, 26, 28, 30, 32, 34]
ROOK_MOBILITY: List[int] = [-15, -8, 0, 3, 6, 9, 12, 14, 16, 18, 20, 22, 24, 26, 28]
QUEEN_MOBILITY: List[int] = [
    -10, -5, 0, 2, 4, 6, 8, 10, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 22, 23, 23, 24, 24, 25, 25, 26, 26
]


def evaluate(board: Board) -> int:
    """Evaluate mobility score for both sides."""
    score = 0
    
    for square in range(64):
        row = square // 8
        col = square % 8
        piece = board.get_piece(row, col)
        
        if piece:
            mobility = 0
            
            if piece.type == PieceType.KNIGHT:
                mobility = count_knight_mobility(board, square, piece.color)
            elif piece.type == PieceType.BISHOP:
                mobility = count_bishop_mobility(board, square, piece.color)
            elif piece.type == PieceType.ROOK:
                mobility = count_rook_mobility(board, square, piece.color)
            elif piece.type == PieceType.QUEEN:
                mobility = count_queen_mobility(board, square, piece.color)
            else:
                continue
            
            bonus = get_mobility_bonus(piece.type, mobility)
            score += bonus if piece.color == Color.WHITE else -bonus
    
    return score


def count_knight_mobility(board: Board, square: int, color: Color) -> int:
    """Count knight mobility."""
    offsets: List[Tuple[int, int]] = [
        (-2, -1), (-2, 1), (-1, -2), (-1, 2),
        (1, -2), (1, 2), (2, -1), (2, 1),
    ]
    
    rank = square // 8
    file = square % 8
    count = 0
    
    for dr, df in offsets:
        new_rank = rank + dr
        new_file = file + df
        
        if 0 <= new_rank < 8 and 0 <= new_file < 8:
            target_piece = board.get_piece(new_rank, new_file)
            if target_piece is None or target_piece.color != color:
                count += 1
    
    return count


def count_bishop_mobility(board: Board, square: int, color: Color) -> int:
    """Count bishop mobility."""
    return count_sliding_mobility(board, square, color, [(1, 1), (1, -1), (-1, 1), (-1, -1)])


def count_rook_mobility(board: Board, square: int, color: Color) -> int:
    """Count rook mobility."""
    return count_sliding_mobility(board, square, color, [(0, 1), (0, -1), (1, 0), (-1, 0)])


def count_queen_mobility(board: Board, square: int, color: Color) -> int:
    """Count queen mobility."""
    return count_sliding_mobility(board, square, color, [
        (0, 1), (0, -1), (1, 0), (-1, 0),
        (1, 1), (1, -1), (-1, 1), (-1, -1),
    ])


def count_sliding_mobility(board: Board, square: int, color: Color, directions: List[Tuple[int, int]]) -> int:
    """Count mobility for sliding pieces."""
    rank = square // 8
    file = square % 8
    count = 0
    
    for dr, df in directions:
        current_rank = rank + dr
        current_file = file + df
        
        while 0 <= current_rank < 8 and 0 <= current_file < 8:
            target_piece = board.get_piece(current_rank, current_file)
            
            if target_piece:
                if target_piece.color != color:
                    count += 1
                break
            else:
                count += 1
            
            current_rank += dr
            current_file += df
    
    return count


def get_mobility_bonus(piece_type: PieceType, mobility: int) -> int:
    """Get mobility bonus for a piece type."""
    if piece_type == PieceType.KNIGHT:
        return KNIGHT_MOBILITY[min(mobility, 8)]
    elif piece_type == PieceType.BISHOP:
        return BISHOP_MOBILITY[min(mobility, 13)]
    elif piece_type == PieceType.ROOK:
        return ROOK_MOBILITY[min(mobility, 14)]
    elif piece_type == PieceType.QUEEN:
        return QUEEN_MOBILITY[min(mobility, 27)]
    return 0
