"""
AI engine for the chess game using minimax with alpha-beta pruning.
"""
from .types import Move, Color, PieceType
from .board import Board
from .move_generator import MoveGenerator


struct AI:
    """Chess AI engine."""
    
    fn __init__(inout self):
        pass
    
    fn evaluate_position(self, board: Board) -> Int:
        """Evaluate the current position. Positive favors white, negative favors black."""
        var score = 0
        
        # Material evaluation
        for i in range(64):
            var piece_code = board.pieces[i]
            if piece_code != 0:
                var piece_value = self.get_piece_value(board.get_piece_type(piece_code))
                if board.is_white_piece(piece_code):
                    score += piece_value
                else:
                    score -= piece_value
        
        # Simple positional bonuses
        score += self.evaluate_position_bonuses(board)
        
        return score
    
    fn get_piece_value(self, piece_type: Int) -> Int:
        """Get the material value of a piece type."""
        if piece_type == 1:  # Pawn
            return 100
        elif piece_type == 2:  # Knight
            return 320
        elif piece_type == 3:  # Bishop
            return 330
        elif piece_type == 4:  # Rook
            return 500
        elif piece_type == 5:  # Queen
            return 900
        elif piece_type == 6:  # King
            return 20000
        else:
            return 0
    
    fn evaluate_position_bonuses(self, board: Board) -> Int:
        """Evaluate positional bonuses."""
        var bonus = 0
        
        # Center control bonus
        var center_squares = StaticTuple[Int, 4](27, 28, 35, 36)  # d4, e4, d5, e5
        
        for i in range(4):
            var square = center_squares[i]
            var piece_code = board.pieces[square]
            if piece_code != 0:
                if board.is_white_piece(piece_code):
                    bonus += 10
                else:
                    bonus -= 10
        
        return bonus
    
    fn get_best_move(self, board: Board, depth: Int) -> Move:
        """Get the best move using minimax with alpha-beta pruning."""
        var move_gen = MoveGenerator()
        var best_move = Move(0, 0, 0, 0)
        var best_score = -99999
        
        # Generate some candidate moves (simplified)
        var moves = self.generate_candidate_moves(board, move_gen)
        
        for i in range(len(moves)):
            var move = moves[i]
            if move_gen.is_valid_move(board, move):
                var mut_board = board  # Create a copy
                if mut_board.make_move(move):
                    var score = -self.minimax(mut_board, depth - 1, -99999, 99999, False)
                    if score > best_score:
                        best_score = score
                        best_move = move
        
        return best_move
    
    fn minimax(self, board: Board, depth: Int, alpha: Int, beta: Int, maximizing: Bool) -> Int:
        """Minimax algorithm with alpha-beta pruning."""
        if depth == 0:
            return self.evaluate_position(board)
        
        var move_gen = MoveGenerator()
        var moves = self.generate_candidate_moves(board, move_gen)
        
        if maximizing:
            var max_eval = -99999
            var mut_alpha = alpha
            
            for i in range(len(moves)):
                var move = moves[i]
                if move_gen.is_valid_move(board, move):
                    var mut_board = board
                    if mut_board.make_move(move):
                        var eval_score = self.minimax(mut_board, depth - 1, mut_alpha, beta, False)
                        if eval_score > max_eval:
                            max_eval = eval_score
                        if eval_score > mut_alpha:
                            mut_alpha = eval_score
                        if beta <= mut_alpha:
                            break  # Beta cutoff
            
            return max_eval
        else:
            var min_eval = 99999
            var mut_beta = beta
            
            for i in range(len(moves)):
                var move = moves[i]
                if move_gen.is_valid_move(board, move):
                    var mut_board = board
                    if mut_board.make_move(move):
                        var eval_score = self.minimax(mut_board, depth - 1, alpha, mut_beta, True)
                        if eval_score < min_eval:
                            min_eval = eval_score
                        if eval_score < mut_beta:
                            mut_beta = eval_score
                        if mut_beta <= alpha:
                            break  # Alpha cutoff
            
            return min_eval
    
    fn generate_candidate_moves(self, board: Board, move_gen: MoveGenerator) -> List[Move]:
        """Generate a list of candidate moves (simplified version)."""
        var moves = List[Move]()
        
        # Generate moves for all pieces of the current color
        for from_row in range(8):
            for from_col in range(8):
                var piece_code = board.get_piece_at(from_row, from_col)
                if piece_code != 0:
                    var piece_color = board.get_piece_color(piece_code)
                    if piece_color == board.to_move:
                        # Try all possible destination squares
                        for to_row in range(8):
                            for to_col in range(8):
                                if from_row != to_row or from_col != to_col:
                                    var move = Move(from_row, from_col, to_row, to_col)
                                    if move_gen.is_valid_move(board, move):
                                        moves.append(move)
        
        return moves