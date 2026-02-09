"""Rich evaluator combining material, PST, mobility, pawn structure, king safety, and positional factors."""

from lib.board import Board
from lib.types import PieceType, Color
from lib.eval import tables, tapered, mobility, pawn_structure, king_safety, positional


class RichEvaluator:
    """Rich position evaluator."""
    
    PIECE_VALUES = {
        PieceType.PAWN: 100,
        PieceType.KNIGHT: 320,
        PieceType.BISHOP: 330,
        PieceType.ROOK: 500,
        PieceType.QUEEN: 900,
        PieceType.KING: 20000
    }
    
    def __init__(self):
        pass
    
    def evaluate(self, board: Board) -> int:
        """Evaluate position using rich evaluation."""
        phase = self.compute_phase(board)
        
        mg_score = self.evaluate_phase(board, True)
        eg_score = self.evaluate_phase(board, False)
        
        tapered_score = tapered.interpolate(mg_score, eg_score, phase)
        
        mobility_score = mobility.evaluate(board)
        pawn_score = pawn_structure.evaluate(board)
        king_score = king_safety.evaluate(board)
        positional_score = positional.evaluate(board)
        
        return tapered_score + mobility_score + pawn_score + king_score + positional_score
    
    def compute_phase(self, board: Board) -> int:
        """Compute game phase based on material."""
        phase = 0
        
        for square in range(64):
            row = square // 8
            col = square % 8
            piece = board.get_piece(row, col)
            
            if piece:
                if piece.type == PieceType.KNIGHT:
                    phase += 1
                elif piece.type == PieceType.BISHOP:
                    phase += 1
                elif piece.type == PieceType.ROOK:
                    phase += 2
                elif piece.type == PieceType.QUEEN:
                    phase += 4
        
        return min(phase, 24)
    
    def evaluate_phase(self, board: Board, middlegame: bool) -> int:
        """Evaluate material and piece-square tables for one phase."""
        score = 0
        
        for square in range(64):
            row = square // 8
            col = square % 8
            piece = board.get_piece(row, col)
            
            if piece:
                value = self.PIECE_VALUES[piece.type]
                
                if middlegame:
                    position_bonus = tables.get_middlegame_bonus(square, piece.type, piece.color)
                else:
                    position_bonus = tables.get_endgame_bonus(square, piece.type, piece.color)
                
                total_value = value + position_bonus
                score += total_value if piece.color == Color.WHITE else -total_value
        
        return score
