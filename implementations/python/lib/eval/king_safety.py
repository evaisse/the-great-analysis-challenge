"""King safety evaluation - pawn shield, open files, attackers."""

from typing import Optional, Tuple
from lib.board import Board
from lib.types import Color, PieceType

PAWN_SHIELD_BONUS: int = 20
OPEN_FILE_PENALTY: int = -30
SEMI_OPEN_FILE_PENALTY: int = -15
ATTACKER_WEIGHT: int = 10


def evaluate(board: Board) -> int:
    """Evaluate king safety for both sides."""
    score = 0
    
    score += evaluate_king_safety(board, Color.WHITE)
    score -= evaluate_king_safety(board, Color.BLACK)
    
    return score


def evaluate_king_safety(board: Board, color: Color) -> int:
    """Evaluate king safety for one color."""
    king_square = find_king(board, color)
    if king_square is None:
        return 0
    
    score = 0
    
    score += evaluate_pawn_shield(board, king_square, color)
    score += evaluate_open_files(board, king_square, color)
    score -= evaluate_attackers(board, king_square, color)
    
    return score


def find_king(board: Board, color: Color) -> Optional[int]:
    """Find king square."""
    for square in range(64):
        row = square // 8
        col = square % 8
        piece = board.get_piece(row, col)
        
        if piece and piece.color == color and piece.type == PieceType.KING:
            return square
    
    return None


def evaluate_pawn_shield(board: Board, king_square: int, color: Color) -> int:
    """Evaluate pawn shield around king."""
    king_file = king_square % 8
    king_rank = king_square // 8
    shield_count = 0
    
    if color == Color.WHITE:
        shield_ranks = [king_rank + 1, king_rank + 2]
    else:
        shield_ranks = [king_rank - 1, king_rank - 2]
    
    for file in range(max(0, king_file - 1), min(8, king_file + 2)):
        for rank in shield_ranks:
            if 0 <= rank < 8:
                piece = board.get_piece(rank, file)
                if piece and piece.color == color and piece.type == PieceType.PAWN:
                    shield_count += 1
    
    return shield_count * PAWN_SHIELD_BONUS


def evaluate_open_files(board: Board, king_square: int, color: Color) -> int:
    """Evaluate open files around king."""
    king_file = king_square % 8
    penalty = 0
    
    for file in range(max(0, king_file - 1), min(8, king_file + 2)):
        own_pawns, enemy_pawns = count_pawns_on_file(board, file, color)
        
        if own_pawns == 0 and enemy_pawns == 0:
            penalty += OPEN_FILE_PENALTY
        elif own_pawns == 0:
            penalty += SEMI_OPEN_FILE_PENALTY
    
    return penalty


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


def evaluate_attackers(board: Board, king_square: int, color: Color) -> int:
    """Count enemy pieces attacking squares around king."""
    king_file = king_square % 8
    king_rank = king_square // 8
    attacker_count = 0
    
    adjacent_squares = [
        (-1, -1), (-1, 0), (-1, 1),
        (0, -1),           (0, 1),
        (1, -1),  (1, 0),  (1, 1),
    ]
    
    for dr, df in adjacent_squares:
        new_rank = king_rank + dr
        new_file = king_file + df
        
        if 0 <= new_rank < 8 and 0 <= new_file < 8:
            if is_attacked_by_enemy(board, new_rank, new_file, color):
                attacker_count += 1
    
    return attacker_count * ATTACKER_WEIGHT


def is_attacked_by_enemy(board: Board, row: int, col: int, color: Color) -> bool:
    """Check if square is attacked by enemy."""
    for attacker_square in range(64):
        attacker_row = attacker_square // 8
        attacker_col = attacker_square % 8
        piece = board.get_piece(attacker_row, attacker_col)
        
        if piece and piece.color != color:
            if can_attack(board, attacker_row, attacker_col, row, col, piece.type, piece.color):
                return True
    
    return False


def can_attack(board: Board, from_row: int, from_col: int, to_row: int, to_col: int, 
               piece_type: PieceType, color: Color) -> bool:
    """Check if piece can attack target square."""
    rank_diff = abs(to_row - from_row)
    file_diff = abs(to_col - from_col)
    
    if piece_type == PieceType.PAWN:
        forward = 1 if color == Color.WHITE else -1
        return to_row - from_row == forward and file_diff == 1
    elif piece_type == PieceType.KNIGHT:
        return (rank_diff == 2 and file_diff == 1) or (rank_diff == 1 and file_diff == 2)
    elif piece_type == PieceType.KING:
        return rank_diff <= 1 and file_diff <= 1
    
    return False
