"""
AI engine using iterative deepening negamax with alpha-beta pruning.
"""

import time
from dataclasses import dataclass
from typing import Dict, Optional, Tuple, List
from lib.types import Move, Piece, PieceType, Color
from lib.board import Board
from lib.move_generator import MoveGenerator


class SearchTimeout(Exception):
    """Raised when search reaches its deadline."""


@dataclass
class TTEntry:
    """Transposition table entry."""
    depth: int
    score: int
    flag: str
    best_move: Optional[Tuple[int, int, int, int, Optional[PieceType], bool, bool]]


class AI:
    """Chess AI with iterative deepening, TT-backed negamax and alpha-beta pruning."""

    TT_EXACT = "exact"
    TT_LOWERBOUND = "lowerbound"
    TT_UPPERBOUND = "upperbound"
    MATE_SCORE = 100000
    TT_MAX_SIZE = 250000

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
        self.transposition_table: Dict[int, TTEntry] = {}
        self._deadline: Optional[float] = None

    def get_best_move(self, depth: int) -> Tuple[Optional[Move], int]:
        """Get best move for fixed depth (backward-compatible API)."""
        best_move, score, _ = self.search(max_depth=depth)
        return best_move, score

    def get_best_move_timed(self, movetime_ms: int, max_depth: int = 5) -> Tuple[Optional[Move], int, int]:
        """Get best move using iterative deepening bounded by movetime."""
        return self.search(max_depth=max_depth, time_limit_ms=movetime_ms)

    def search(self, max_depth: int, time_limit_ms: Optional[int] = None) -> Tuple[Optional[Move], int, int]:
        """
        Iterative deepening search.

        Returns (best_move, eval_score, completed_depth). If timeout happens during a
        deeper iteration, result from the last fully completed depth is returned.
        """
        if max_depth < 1:
            max_depth = 1

        legal_moves = self.move_generator.generate_legal_moves()
        if not legal_moves:
            return None, 0, 0

        fallback_move = self._order_moves(legal_moves)[0]
        fallback_score = self._evaluate_for_side_to_move()

        if time_limit_ms is not None and time_limit_ms <= 0:
            time_limit_ms = 1

        self._deadline = None
        if time_limit_ms is not None:
            self._deadline = time.monotonic() + (time_limit_ms / 1000.0)

        best_move = fallback_move
        best_score = fallback_score
        completed_depth = 0

        try:
            for depth in range(1, max_depth + 1):
                self._check_timeout()
                iter_move, iter_score = self._search_root(depth)
                if iter_move is None:
                    break
                best_move = iter_move
                best_score = iter_score
                completed_depth = depth
        except SearchTimeout:
            # Keep last completed iteration result.
            pass
        finally:
            self._deadline = None

        return best_move, best_score, completed_depth

    def _search_root(self, depth: int) -> Tuple[Optional[Move], int]:
        """Search root node at a fixed depth."""
        self._check_timeout()

        alpha = -self.MATE_SCORE
        beta = self.MATE_SCORE
        best_score = -self.MATE_SCORE
        best_move: Optional[Move] = None

        node_hash = self.board.zobrist_hash
        tt_entry = self.transposition_table.get(node_hash)
        tt_move_key = tt_entry.best_move if tt_entry else None

        legal_moves = self.move_generator.generate_legal_moves()
        if not legal_moves:
            if self.board.is_in_check(self.board.to_move):
                return None, -self.MATE_SCORE
            return None, 0

        ordered_moves = self._order_moves(legal_moves, tt_move_key)
        alpha_original = alpha
        beta_original = beta

        for move in ordered_moves:
            self._check_timeout()
            self.board.make_move(move)
            score = -self._negamax(depth - 1, -beta, -alpha, 1)
            self.board.undo_move(move)

            if score > best_score:
                best_score = score
                best_move = move

            if score > alpha:
                alpha = score

            if alpha >= beta:
                break

        if best_move is not None:
            flag = self.TT_EXACT
            if best_score <= alpha_original:
                flag = self.TT_UPPERBOUND
            elif best_score >= beta_original:
                flag = self.TT_LOWERBOUND
            self._store_tt(node_hash, depth, best_score, flag, best_move)

        return best_move, best_score

    def _negamax(self, depth: int, alpha: int, beta: int, ply: int) -> int:
        """Negamax with alpha-beta pruning and TT lookup/store."""
        self._check_timeout()
        alpha_original = alpha
        beta_original = beta

        node_hash = self.board.zobrist_hash
        tt_entry = self.transposition_table.get(node_hash)
        tt_move_key = None
        if tt_entry:
            tt_move_key = tt_entry.best_move
            if tt_entry.depth >= depth:
                if tt_entry.flag == self.TT_EXACT:
                    return tt_entry.score
                if tt_entry.flag == self.TT_LOWERBOUND:
                    alpha = max(alpha, tt_entry.score)
                elif tt_entry.flag == self.TT_UPPERBOUND:
                    beta = min(beta, tt_entry.score)
                if alpha >= beta:
                    return tt_entry.score

        if depth == 0:
            return self._evaluate_for_side_to_move()

        legal_moves = self.move_generator.generate_legal_moves()
        if not legal_moves:
            if self.board.is_in_check(self.board.to_move):
                # Prefer faster mates and slower losses.
                return -self.MATE_SCORE + ply
            return 0

        best_score = -self.MATE_SCORE
        best_move: Optional[Move] = None

        for move in self._order_moves(legal_moves, tt_move_key):
            self._check_timeout()
            self.board.make_move(move)
            score = -self._negamax(depth - 1, -beta, -alpha, ply + 1)
            self.board.undo_move(move)

            if score > best_score:
                best_score = score
                best_move = move

            if score > alpha:
                alpha = score

            if alpha >= beta:
                break

        flag = self.TT_EXACT
        if best_score <= alpha_original:
            flag = self.TT_UPPERBOUND
        elif best_score >= beta_original:
            flag = self.TT_LOWERBOUND

        self._store_tt(node_hash, depth, best_score, flag, best_move)
        return best_score

    def _store_tt(self, node_hash: int, depth: int, score: int, flag: str, best_move: Optional[Move]) -> None:
        """Store TT entry with shallow size control."""
        if len(self.transposition_table) >= self.TT_MAX_SIZE:
            self.transposition_table.clear()
        self.transposition_table[node_hash] = TTEntry(
            depth=depth,
            score=score,
            flag=flag,
            best_move=self._move_to_key(best_move) if best_move else None
        )

    def _evaluate_for_side_to_move(self) -> int:
        """Return static eval from side-to-move perspective."""
        score = self.evaluate_position()
        return score if self.board.to_move == Color.WHITE else -score

    def _check_timeout(self) -> None:
        """Raise SearchTimeout when deadline is reached."""
        if self._deadline is not None and time.monotonic() >= self._deadline:
            raise SearchTimeout()

    def _move_to_key(
        self,
        move: Optional[Move]
    ) -> Optional[Tuple[int, int, int, int, Optional[PieceType], bool, bool]]:
        """Serialize move identity for TT storage."""
        if move is None:
            return None
        return (
            move.from_row,
            move.from_col,
            move.to_row,
            move.to_col,
            move.promotion,
            move.is_castling,
            move.is_en_passant,
        )

    def _move_matches_key(
        self,
        move: Move,
        move_key: Optional[Tuple[int, int, int, int, Optional[PieceType], bool, bool]]
    ) -> bool:
        """Compare a move against TT move identity."""
        if move_key is None:
            return False
        return self._move_to_key(move) == move_key

    def _order_moves(
        self,
        moves: List[Move],
        tt_move_key: Optional[Tuple[int, int, int, int, Optional[PieceType], bool, bool]] = None
    ) -> List[Move]:
        """Order moves for better pruning and deterministic choices."""
        def move_score(move: Move) -> int:
            score = 0

            # Prioritize captures.
            target_piece = self.board.get_piece(move.to_row, move.to_col)
            if target_piece:
                score += self.PIECE_VALUES[target_piece.type]
            elif move.is_en_passant:
                score += self.PIECE_VALUES[PieceType.PAWN]

            # Prioritize promotions.
            if move.promotion:
                score += self.PIECE_VALUES[move.promotion]

            # Prioritize center moves.
            if 3 <= move.to_row <= 4 and 3 <= move.to_col <= 4:
                score += 10

            return score

        def move_key(move: Move):
            tt_priority = 0 if self._move_matches_key(move, tt_move_key) else 1
            return (tt_priority, -move_score(move), move.to_algebraic())

        return sorted(moves, key=move_key)
    
    def evaluate_position(self) -> int:
        """Evaluate the current position."""
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
