"""
Performance testing (perft) for move generation validation.
"""

from lib.board import Board
from lib.move_generator import MoveGenerator


class Perft:
    """Performance test for move generation."""
    
    def __init__(self, board: Board, move_generator: MoveGenerator):
        self.board = board
        self.move_generator = move_generator
    
    def perft(self, depth: int) -> int:
        """Count all possible positions after depth moves."""
        if depth == 0:
            return 1
        
        legal_moves = self.move_generator.generate_legal_moves()
        node_count = 0
        
        for move in legal_moves:
            self.board.make_move(move)
            node_count += self.perft(depth - 1)
            self.board.undo_move(move)
        
        return node_count
    
    def perft_divide(self, depth: int) -> dict:
        """Perft with division - shows move counts for each first move."""
        if depth <= 0:
            return {}
        
        legal_moves = self.move_generator.generate_legal_moves()
        results = {}
        
        for move in legal_moves:
            self.board.make_move(move)
            
            if depth == 1:
                count = 1
            else:
                count = self.perft(depth - 1)
            
            self.board.undo_move(move)
            
            move_str = move.to_algebraic()
            results[move_str] = count
        
        return results