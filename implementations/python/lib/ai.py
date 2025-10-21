"""
AI engine using minimax with alpha-beta pruning.
"""

from typing import Tuple, Optional, List
from lib.types import Move, Piece, PieceType, Color
from lib.board import Board
from lib.move_generator import MoveGenerator


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
    
    def get_best_move(self, depth: int) -> Tuple[Optional[Move], int]:
        """Get the best move using minimax with alpha-beta pruning."""
        legal_moves = self.move_generator.generate_legal_moves()
        
        if not legal_moves:
            return None, 0
        
        # Order moves for better pruning
        ordered_moves = self._order_moves(legal_moves)
        
        # We're always maximizing from our perspective
        maximizing_player = self.board.to_move == Color.WHITE
        best_score = float('-inf') if maximizing_player else float('inf')
        best_move = None
        
        alpha = float('-inf')
        beta = float('inf')
        
        for move in ordered_moves:
            self.board.make_move(move)
            
            # After our move, it's the opponent's turn
            score = self._minimax(depth - 1, alpha, beta, not maximizing_player)
            
            self.board.undo_move(move)
            
            if maximizing_player:
                if score > best_score:
                    best_score = score
                    best_move = move
                alpha = max(alpha, score)
            else:
                if score < best_score:
                    best_score = score
                    best_move = move
                beta = min(beta, score)
            
            # Alpha-beta pruning
            if beta <= alpha:
                break
        
        return best_move, best_score
    
    def _minimax(self, depth: int, alpha: float, beta: float, maximizing: bool) -> int:
        """Minimax algorithm with alpha-beta pruning."""
        if depth == 0:
            return self.evaluate_position()
        
        # Check for game end
        legal_moves = self.move_generator.generate_legal_moves()
        
        if not legal_moves:
            if self.board.is_in_check(self.board.to_move):
                # Checkmate
                return -100000 if maximizing else 100000
            else:
                # Stalemate
                return 0
        
        if maximizing:
            max_eval = float('-inf')
            for move in self._order_moves(legal_moves):
                self.board.make_move(move)
                eval_score = self._minimax(depth - 1, alpha, beta, False)
                self.board.undo_move(move)
                
                max_eval = max(max_eval, eval_score)
                alpha = max(alpha, eval_score)
                
                if beta <= alpha:
                    break  # Beta cutoff
            
            return max_eval
        else:
            min_eval = float('inf')
            for move in self._order_moves(legal_moves):
                self.board.make_move(move)
                eval_score = self._minimax(depth - 1, alpha, beta, True)
                self.board.undo_move(move)
                
                min_eval = min(min_eval, eval_score)
                beta = min(beta, eval_score)
                
                if beta <= alpha:
                    break  # Alpha cutoff
            
            return min_eval
    
    def _order_moves(self, moves: List[Move]) -> List[Move]:
        """Order moves for better alpha-beta pruning."""
        def move_score(move):
            score = 0
            
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