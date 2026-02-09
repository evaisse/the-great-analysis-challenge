"""Positional evaluation - bishop pair, rooks on open files, outposts."""

from typing import Tuple
from lib.board import Board
from lib.types import Color, PieceType

BISHOP_PAIR_BONUS: int = 30
ROOK_OPEN_FILE_BONUS: int = 25
ROOK_SEMI_OPEN_FILE_BONUS: int = 15
ROOK_SEVENTH_RANK_BONUS: int = 20
KNIGHT_OUTPOST_BONUS: int = 20


def evaluate(board: Board) -> int:
    """Evaluate positional factors for both sides."""
    score = 0
    
    score += evaluate_color(board, Color.WHITE)
    score -= evaluate_color(board, Color.BLACK)
    
    return score


def evaluate_color(board: Board, color: Color) -> int:
    """Evaluate positional factors for one color."""
    score = 0
    
    if has_bishop_pair(board, color):
        score += BISHOP_PAIR_BONUS
    
    for square in range(64):
        row = square // 8
        col = square % 8
        piece = board.get_piece(row, col)
        
        if piece and piece.color == color:
            if piece.type == PieceType.ROOK:
                score += evaluate_rook(board, square, color)
            elif piece.type == PieceType.KNIGHT:
                score += evaluate_knight(board, square, color)
    
    return score


def has_bishop_pair(board: Board, color: Color) -> bool:
    """Check if player has bishop pair."""
    bishop_count = 0
    
    for square in range(64):
        row = square // 8
        col = square % 8
        piece = board.get_piece(row, col)
        
        if piece and piece.color == color and piece.type == PieceType.BISHOP:
            bishop_count += 1
    
    return bishop_count >= 2


def evaluate_rook(board: Board, square: int, color: Color) -> int:
    """Evaluate rook position."""
    file = square % 8
    rank = square // 8
    bonus = 0
    
    own_pawns, enemy_pawns = count_pawns_on_file(board, file, color)
    
    if own_pawns == 0 and enemy_pawns == 0:
        bonus += ROOK_OPEN_FILE_BONUS
    elif own_pawns == 0:
        bonus += ROOK_SEMI_OPEN_FILE_BONUS
    
    seventh_rank = 6 if color == Color.WHITE else 1
    if rank == seventh_rank:
        bonus += ROOK_SEVENTH_RANK_BONUS
    
    return bonus


def evaluate_knight(board: Board, square: int, color: Color) -> int:
    """Evaluate knight position."""
    if is_outpost(board, square, color):
        return KNIGHT_OUTPOST_BONUS
    return 0


def is_outpost(board: Board, square: int, color: Color) -> bool:
    """Check if knight is on an outpost."""
    file = square % 8
    rank = square // 8
    
    if not is_protected_by_pawn(board, square, color):
        return False
    
    if can_be_attacked_by_enemy_pawn(board, square, file, rank, color):
        return False
    
    return True


def is_protected_by_pawn(board: Board, square: int, color: Color) -> bool:
    """Check if square is protected by own pawn."""
    file = square % 8
    rank = square // 8
    
    behind_rank = rank - 1 if color == Color.WHITE else rank + 1
    
    if not (0 <= behind_rank < 8):
        return False
    
    for adjacent_file in [file - 1, file + 1]:
        if 0 <= adjacent_file < 8:
            piece = board.get_piece(behind_rank, adjacent_file)
            if piece and piece.color == color and piece.type == PieceType.PAWN:
                return True
    
    return False


def can_be_attacked_by_enemy_pawn(board: Board, square: int, file: int, rank: int, color: Color) -> bool:
    """Check if square can be attacked by enemy pawn."""
    if color == Color.WHITE:
        ahead_ranks = range(rank + 1, 8)
    else:
        ahead_ranks = range(0, rank)
    
    for check_rank in ahead_ranks:
        for adjacent_file in [file - 1, file + 1]:
            if 0 <= adjacent_file < 8:
                piece = board.get_piece(check_rank, adjacent_file)
                if piece and piece.color != color and piece.type == PieceType.PAWN:
                    return True
    
    return False


def count_pawns_on_file(board: Board, file: int, color: Color) -> Tuple[int, int]:
    """Count own and enemy pawns on a file."""
    own_pawns = 0
    enemy_pawns = 0
    
    for rank in range(8):
        piece = board.get_piece(rank, file)
        if piece and piece.type == PieceType.PAWN:
            if piece.color == color:
                own_pawns += 1
            else:
                enemy_pawns += 1
    
    return own_pawns, enemy_pawns
