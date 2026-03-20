"""AI engine using iterative deepening + negamax + alpha-beta + TT."""

from dataclasses import dataclass
import time
from typing import Dict, Tuple, Optional, List
from lib.types import Move, Piece, PieceType, Color
from lib.board import Board
from lib.draw_detection import is_draw
from lib.move_generator import MoveGenerator

MATE_VALUE = 100000
INFINITY = 10**9


@dataclass
class TTEntry:
    depth: int
    score: int
    flag: str  # exact | lower | upper
    best_move: Optional[Move]


class AI:
    """Chess AI using minimax with alpha-beta pruning."""
    
    # Piece values for evaluation
    PIECE_VALUES = {
        PieceType.PAWN: 100,
        PieceType.KNIGHT: 320,
        PieceType.BISHOP: 330,
        PieceType.ROOK: 500,
        PieceType.QUEEN: 900,
        PieceType.KING: 20000
    }
    
    # Position bonus tables
    PAWN_TABLE = [
        [0,  0,  0,  0,  0,  0,  0,  0],
        [50, 50, 50, 50, 50, 50, 50, 50],
        [10, 10, 20, 30, 30, 20, 10, 10],
        [5,  5, 10, 25, 25, 10,  5,  5],
        [0,  0,  0, 20, 20,  0,  0,  0],
        [5, -5,-10,  0,  0,-10, -5,  5],
        [5, 10, 10,-20,-20, 10, 10,  5],
        [0,  0,  0,  0,  0,  0,  0,  0]
    ]
    
    KNIGHT_TABLE = [
        [-50,-40,-30,-30,-30,-30,-40,-50],
        [-40,-20,  0,  0,  0,  0,-20,-40],
        [-30,  0, 10, 15, 15, 10,  0,-30],
        [-30,  5, 15, 20, 20, 15,  5,-30],
        [-30,  0, 15, 20, 20, 15,  0,-30],
        [-30,  5, 10, 15, 15, 10,  5,-30],
        [-40,-20,  0,  5,  5,  0,-20,-40],
        [-50,-40,-30,-30,-30,-30,-40,-50]
    ]
    
    BISHOP_TABLE = [
        [-20,-10,-10,-10,-10,-10,-10,-20],
        [-10,  0,  0,  0,  0,  0,  0,-10],
        [-10,  0,  5, 10, 10,  5,  0,-10],
        [-10,  5,  5, 10, 10,  5,  5,-10],
        [-10,  0, 10, 10, 10, 10,  0,-10],
        [-10, 10, 10, 10, 10, 10, 10,-10],
        [-10,  5,  0,  0,  0,  0,  5,-10],
        [-20,-10,-10,-10,-10,-10,-10,-20]
    ]
    
    ROOK_TABLE = [
        [0,  0,  0,  0,  0,  0,  0,  0],
        [5, 10, 10, 10, 10, 10, 10,  5],
        [-5,  0,  0,  0,  0,  0,  0, -5],
        [-5,  0,  0,  0,  0,  0,  0, -5],
        [-5,  0,  0,  0,  0,  0,  0, -5],
        [-5,  0,  0,  0,  0,  0,  0, -5],
        [-5,  0,  0,  0,  0,  0,  0, -5],
        [0,  0,  0,  5,  5,  0,  0,  0]
    ]
    
    QUEEN_TABLE = [
        [-20,-10,-10, -5, -5,-10,-10,-20],
        [-10,  0,  0,  0,  0,  0,  0,-10],
        [-10,  0,  5,  5,  5,  5,  0,-10],
        [-5,  0,  5,  5,  5,  5,  0, -5],
        [0,  0,  5,  5,  5,  5,  0, -5],
        [-10,  5,  5,  5,  5,  5,  0,-10],
        [-10,  0,  5,  0,  0,  0,  0,-10],
        [-20,-10,-10, -5, -5,-10,-10,-20]
    ]
    
    KING_TABLE = [
        [-30,-40,-40,-50,-50,-40,-40,-30],
        [-30,-40,-40,-50,-50,-40,-40,-30],
        [-30,-40,-40,-50,-50,-40,-40,-30],
        [-30,-40,-40,-50,-50,-40,-40,-30],
        [-20,-30,-30,-40,-40,-30,-30,-20],
        [-10,-20,-20,-20,-20,-20,-20,-10],
        [20, 20,  0,  0,  0,  0, 20, 20],
        [20, 30, 10,  0,  0, 10, 30, 20]
    ]
    
    def __init__(self, board: Board, move_generator: MoveGenerator):
        self.board = board
        self.move_generator = move_generator
        self._tt: Dict[int, TTEntry] = {}
        self._deadline: Optional[float] = None
        self._timed_out = False
        self._stop_requested = False
        self._nodes_visited = 0
        self._eval_calls = 0
        self._tt_hits = 0
        self._tt_misses = 0
        self._beta_cutoffs = 0

    def get_best_move(self, depth: int) -> Tuple[Optional[Move], int]:
        """Backward-compatible API used by `ai <depth>` command."""
        best_move, best_score, _, _, _, _, _, _, _, _ = self.search(depth, 0)
        return best_move, best_score

    def request_stop(self) -> None:
        """Cooperative stop flag for ongoing search."""
        self._stop_requested = True

    def search(
        self,
        max_depth: int,
        movetime_ms: int,
    ) -> Tuple[Optional[Move], int, int, int, bool, int, int, int, int, int]:
        """Return (best_move, score, depth_reached, elapsed_ms, timed_out, nodes, eval_calls, tt_hits, tt_misses, beta_cutoffs)."""
        if max_depth < 1:
            max_depth = 1
        if max_depth > 5:
            max_depth = 5

        legal_moves = self.move_generator.generate_legal_moves()
        if not legal_moves:
            return None, 0, 0, 0, False, 0, 0, 0, 0, 0

        self._timed_out = False
        self._stop_requested = False
        self._nodes_visited = 0
        self._eval_calls = 0
        self._tt_hits = 0
        self._tt_misses = 0
        self._beta_cutoffs = 0
        start = time.monotonic()
        self._deadline = start + (movetime_ms / 1000.0) if movetime_ms > 0 else None

        best_move = legal_moves[0]
        best_score = self.evaluate_position()
        completed_depth = 0

        for depth in range(1, max_depth + 1):
            score, move, complete = self._search_root(depth)
            if not complete:
                break
            if move is not None:
                best_move = move
                best_score = score
                completed_depth = depth

        if completed_depth == 0:
            completed_depth = 1

        elapsed_ms = int((time.monotonic() - start) * 1000)
        return (
            best_move,
            int(best_score),
            completed_depth,
            elapsed_ms,
            self._timed_out,
            self._nodes_visited,
            self._eval_calls,
            self._tt_hits,
            self._tt_misses,
            self._beta_cutoffs,
        )

    def _search_root(self, depth: int) -> Tuple[int, Optional[Move], bool]:
        if self._time_exceeded():
            return 0, None, False
        self._nodes_visited += 1

        moves = self.move_generator.generate_legal_moves()
        if not moves:
            return 0, None, True

        entry = self._tt.get(self.board.zobrist_hash)
        if entry is not None:
            self._tt_hits += 1
        else:
            self._tt_misses += 1
        ordered_moves = self._order_moves(moves, entry.best_move if entry else None)

        alpha = -INFINITY
        beta = INFINITY
        best_score = -INFINITY
        best_move: Optional[Move] = ordered_moves[0]

        for move in ordered_moves:
            if self._time_exceeded():
                return 0, None, False
            self.board.make_move(move)
            score, _, ok = self._negamax(depth - 1, -beta, -alpha)
            self.board.undo_move(move)
            if not ok:
                return 0, None, False
            score = -score

            if score > best_score:
                best_score = score
                best_move = move
            if score > alpha:
                alpha = score

        return int(best_score), best_move, True

    def _negamax(self, depth: int, alpha: int, beta: int) -> Tuple[int, Optional[Move], bool]:
        if self._time_exceeded():
            return 0, None, False
        self._nodes_visited += 1

        if is_draw(self.board):
            return 0, None, True

        original_alpha = alpha
        key = self.board.zobrist_hash
        best_from_tt: Optional[Move] = None

        entry = self._tt.get(key)
        if entry and entry.depth >= depth:
            self._tt_hits += 1
            if entry.flag == 'exact':
                return entry.score, entry.best_move, True
            if entry.flag == 'lower':
                alpha = max(alpha, entry.score)
            elif entry.flag == 'upper':
                beta = min(beta, entry.score)
            if alpha >= beta:
                self._beta_cutoffs += 1
                return entry.score, entry.best_move, True
            best_from_tt = entry.best_move
        else:
            self._tt_misses += 1

        if depth == 0:
            return int(self.evaluate_position()), None, True

        moves = self.move_generator.generate_legal_moves()
        if not moves:
            if self.board.is_in_check(self.board.to_move):
                return -MATE_VALUE + depth, None, True
            return 0, None, True

        ordered = self._order_moves(moves, best_from_tt)
        best_score = -INFINITY
        best_move: Optional[Move] = ordered[0]

        for move in ordered:
            if self._time_exceeded():
                return 0, None, False
            self.board.make_move(move)
            score, _, ok = self._negamax(depth - 1, -beta, -alpha)
            self.board.undo_move(move)
            if not ok:
                return 0, None, False
            score = -score

            if score > best_score:
                best_score = score
                best_move = move
            if score > alpha:
                alpha = score
            if alpha >= beta:
                self._beta_cutoffs += 1
                break

        flag = 'exact'
        if best_score <= original_alpha:
            flag = 'upper'
        elif best_score >= beta:
            flag = 'lower'
        self._tt[key] = TTEntry(depth=depth, score=int(best_score), flag=flag, best_move=best_move)

        return int(best_score), best_move, True

    def _order_moves(self, moves: List[Move], tt_move: Optional[Move] = None) -> List[Move]:
        """Order moves for better alpha-beta pruning."""
        def move_score(move):
            score = 0

            if tt_move and move == tt_move:
                score += 100000
            
            # Prioritize captures
            target_piece = self.board.get_piece(move.to_row, move.to_col)
            if target_piece:
                score += self.PIECE_VALUES[target_piece.type]
            
            # Prioritize promotions
            if move.promotion:
                score += self.PIECE_VALUES[move.promotion]
            
            # Prioritize center moves
            center_bonus = 0
            if 3 <= move.to_row <= 4 and 3 <= move.to_col <= 4:
                center_bonus = 10
            score += center_bonus
            
            return score
        
        return sorted(moves, key=move_score, reverse=True)

    def _time_exceeded(self) -> bool:
        if self._stop_requested:
            self._timed_out = True
            return True
        if self._deadline is None:
            return False
        if time.monotonic() >= self._deadline:
            self._timed_out = True
            return True
        return False
    
    def evaluate_position(self) -> int:
        """Evaluate the current position."""
        self._eval_calls += 1
        score = 0
        
        for row in range(8):
            for col in range(8):
                piece = self.board.get_piece(row, col)
                if piece:
                    piece_value = self._evaluate_piece(piece, row, col)
                    
                    if piece.color == Color.WHITE:
                        score += piece_value
                    else:
                        score -= piece_value
        
        # Add positional bonuses
        score += self._evaluate_position_factors()
        
        return score
    
    def _evaluate_piece(self, piece: Piece, row: int, col: int) -> int:
        """Evaluate a single piece including positional bonus."""
        value = self.PIECE_VALUES[piece.type]
        
        # Position tables are for white, flip for black
        eval_row = row if piece.color == Color.WHITE else 7 - row
        
        if piece.type == PieceType.PAWN:
            value += self.PAWN_TABLE[eval_row][col]
        elif piece.type == PieceType.KNIGHT:
            value += self.KNIGHT_TABLE[eval_row][col]
        elif piece.type == PieceType.BISHOP:
            value += self.BISHOP_TABLE[eval_row][col]
        elif piece.type == PieceType.ROOK:
            value += self.ROOK_TABLE[eval_row][col]
        elif piece.type == PieceType.QUEEN:
            value += self.QUEEN_TABLE[eval_row][col]
        elif piece.type == PieceType.KING:
            value += self.KING_TABLE[eval_row][col]
        
        return value
    
    def _evaluate_position_factors(self) -> int:
        """Evaluate additional positional factors."""
        score = 0
        
        # King safety penalty if exposed
        for color in [Color.WHITE, Color.BLACK]:
            king_pos = self.board.find_king(color)
            if king_pos:
                king_row, king_col = king_pos
                
                # Count attackers around king
                attacker_count = 0
                opponent_color = Color.BLACK if color == Color.WHITE else Color.WHITE
                
                for dr in [-1, 0, 1]:
                    for dc in [-1, 0, 1]:
                        if dr == 0 and dc == 0:
                            continue
                        
                        check_row, check_col = king_row + dr, king_col + dc
                        if self.board.is_valid_square(check_row, check_col):
                            if self.board.is_square_attacked(check_row, check_col, opponent_color):
                                attacker_count += 1
                
                king_safety_penalty = attacker_count * 20
                
                if color == Color.WHITE:
                    score -= king_safety_penalty
                else:
                    score += king_safety_penalty
        
        return score
