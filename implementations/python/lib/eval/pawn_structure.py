"""Pawn structure evaluation - passed pawns, doubled, isolated, etc."""

from typing import List, Tuple
from lib.board import Board
from lib.types import Color, PieceType

PASSED_PAWN_BONUS: List[int] = [0, 10, 20, 40, 60, 90, 120, 0]
DOUBLED_PAWN_PENALTY: int = -20
ISOLATED_PAWN_PENALTY: int = -15
BACKWARD_PAWN_PENALTY: int = -10
CONNECTED_PAWN_BONUS: int = 5
PAWN_CHAIN_BONUS: int = 10


def evaluate(board: Board) -> int:
    """Evaluate pawn structure for both sides."""
    score = 0
    
    score += evaluate_color(board, Color.WHITE)
    score -= evaluate_color(board, Color.BLACK)
    
    return score


def evaluate_color(board: Board, color: Color) -> int:
    """Evaluate pawn structure for one color."""
    score = 0
    pawn_files = [0] * 8
    pawn_positions: List[Tuple[int, int, int]] = []
    
    for square in range(64):
        row = square // 8
        col = square % 8
        piece = board.get_piece(row, col)
        
        if piece and piece.color == color and piece.type == PieceType.PAWN:
            pawn_files[col] += 1
            pawn_positions.append((square, row, col))
    
    for square, rank, file in pawn_positions:
        if pawn_files[file] > 1:
            score += DOUBLED_PAWN_PENALTY
        
        if is_isolated(file, pawn_files):
            score += ISOLATED_PAWN_PENALTY
        
        if is_passed(board, square, rank, file, color):
            bonus_rank = rank if color == Color.WHITE else 7 - rank
            score += PASSED_PAWN_BONUS[bonus_rank]
        
        if is_connected(board, square, file, color):
            score += CONNECTED_PAWN_BONUS
        
        if is_in_chain(board, square, rank, file, color):
            score += PAWN_CHAIN_BONUS
        
        if is_backward(board, square, rank, file, color, pawn_files):
            score += BACKWARD_PAWN_PENALTY
    
    return score


def is_isolated(file: int, pawn_files: List[int]) -> bool:
    """Check if pawn is isolated."""
    left_file = pawn_files[file - 1] if file > 0 else 0
    right_file = pawn_files[file + 1] if file < 7 else 0
    return left_file == 0 and right_file == 0


def is_passed(board: Board, square: int, rank: int, file: int, color: Color) -> bool:
    """Check if pawn is passed."""
    if color == Color.WHITE:
        start_rank = rank + 1
        end_rank = 8
    else:
        start_rank = 0
        end_rank = rank
    
    for check_file in range(max(0, file - 1), min(8, file + 2)):
        for check_rank in range(start_rank, end_rank):
            check_piece = board.get_piece(check_rank, check_file)
            if check_piece and check_piece.type == PieceType.PAWN and check_piece.color != color:
                return False
    
    return True


def is_connected(board: Board, square: int, file: int, color: Color) -> bool:
    """Check if pawn is connected (adjacent pawn on same rank)."""
    rank = square // 8
    
    for adjacent_file in [file - 1, file + 1]:
        if 0 <= adjacent_file < 8:
            adjacent_piece = board.get_piece(rank, adjacent_file)
            if adjacent_piece and adjacent_piece.color == color and adjacent_piece.type == PieceType.PAWN:
                return True
    
    return False


def is_in_chain(board: Board, square: int, rank: int, file: int, color: Color) -> bool:
    """Check if pawn is in a chain (protected by pawn behind)."""
    behind_rank = rank - 1 if color == Color.WHITE else rank + 1
    
    if not (0 <= behind_rank < 8):
        return False
    
    for adjacent_file in [file - 1, file + 1]:
        if 0 <= adjacent_file < 8:
            check_piece = board.get_piece(behind_rank, adjacent_file)
            if check_piece and check_piece.color == color and check_piece.type == PieceType.PAWN:
                return True
    
    return False


def is_backward(board: Board, square: int, rank: int, file: int, color: Color, pawn_files: List[int]) -> bool:
    """Check if pawn is backward."""
    left_file = file - 1
    right_file = file + 1
    
    for adjacent_file in [left_file, right_file]:
        if 0 <= adjacent_file < 8 and pawn_files[adjacent_file] > 0:
            for check_square in range(64):
                check_row = check_square // 8
                check_col = check_square % 8
                check_piece = board.get_piece(check_row, check_col)
                
                if check_piece and check_piece.color == color and check_piece.type == PieceType.PAWN:
                    if check_col == adjacent_file:
                        is_ahead = check_row > rank if color == Color.WHITE else check_row < rank
                        if is_ahead:
                            return False
    
    return False
