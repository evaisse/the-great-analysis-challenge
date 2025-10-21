"""
Move generation for the chess engine.
"""
from .types import Move, Color, PieceType
from .board import Board


struct MoveGenerator:
    """Generates legal moves for chess positions."""
    
    fn __init__(inout self):
        pass
    
    fn is_valid_move(self, board: Board, move: Move) -> Bool:
        """Check if a move is valid (basic validation)."""
        # Check bounds
        if not (0 <= move.from_row <= 7 and 0 <= move.from_col <= 7 and
                0 <= move.to_row <= 7 and 0 <= move.to_col <= 7):
            return False
        
        # Check if there's a piece at the source
        var piece_code = board.get_piece_at(move.from_row, move.from_col)
        if piece_code == 0:
            return False
        
        # Check if it's the correct color's turn
        var piece_color = board.get_piece_color(piece_code)
        if piece_color != board.to_move:
            return False
        
        # Check if destination has friendly piece
        var dest_piece = board.get_piece_at(move.to_row, move.to_col)
        if dest_piece != 0:
            var dest_color = board.get_piece_color(dest_piece)
            if dest_color == piece_color:
                return False
        
        # Basic piece movement validation
        var piece_type = board.get_piece_type(piece_code)
        return self.is_valid_piece_move(board, move, piece_type, piece_color)
    
    fn is_valid_piece_move(self, board: Board, move: Move, piece_type: Int, color: Color) -> Bool:
        """Check if a move is valid for a specific piece type."""
        var dr = move.to_row - move.from_row
        var dc = move.to_col - move.from_col
        
        if piece_type == 1:  # Pawn
            return self.is_valid_pawn_move(board, move, dr, dc, color)
        elif piece_type == 2:  # Knight
            return (abs(dr) == 2 and abs(dc) == 1) or (abs(dr) == 1 and abs(dc) == 2)
        elif piece_type == 3:  # Bishop
            return abs(dr) == abs(dc) and abs(dr) > 0 and self.is_clear_diagonal(board, move)
        elif piece_type == 4:  # Rook
            return (dr == 0 or dc == 0) and (dr != 0 or dc != 0) and self.is_clear_line(board, move)
        elif piece_type == 5:  # Queen
            return ((dr == 0 or dc == 0) or (abs(dr) == abs(dc))) and (dr != 0 or dc != 0) and self.is_clear_path(board, move)
        elif piece_type == 6:  # King
            return abs(dr) <= 1 and abs(dc) <= 1 and (dr != 0 or dc != 0)
        
        return False
    
    fn is_valid_pawn_move(self, board: Board, move: Move, dr: Int, dc: Int, color: Color) -> Bool:
        """Check if a pawn move is valid."""
        var direction = 1 if color == Color.WHITE() else -1
        
        if dc == 0:  # Forward move
            if dr == direction:
                # Single step forward
                return board.is_empty(move.to_row, move.to_col)
            elif dr == 2 * direction:
                # Double step from starting position
                var start_rank = 1 if color == Color.WHITE() else 6
                return (move.from_row == start_rank and 
                        board.is_empty(move.to_row, move.to_col) and
                        board.is_empty(move.from_row + direction, move.from_col))
        elif abs(dc) == 1 and dr == direction:
            # Diagonal capture
            var dest_piece = board.get_piece_at(move.to_row, move.to_col)
            if dest_piece != 0:
                return board.get_piece_color(dest_piece) != color
            
            # Check en passant
            if board.en_passant_target == move.to_row * 8 + move.to_col:
                return True
        
        return False
    
    fn is_clear_line(self, board: Board, move: Move) -> Bool:
        """Check if the path is clear for rook-like movement."""
        var dr = 0 if move.to_row == move.from_row else (1 if move.to_row > move.from_row else -1)
        var dc = 0 if move.to_col == move.from_col else (1 if move.to_col > move.from_col else -1)
        
        var r = move.from_row + dr
        var c = move.from_col + dc
        
        while r != move.to_row or c != move.to_col:
            if not board.is_empty(r, c):
                return False
            r += dr
            c += dc
        
        return True
    
    fn is_clear_diagonal(self, board: Board, move: Move) -> Bool:
        """Check if the diagonal path is clear for bishop-like movement."""
        var dr = 1 if move.to_row > move.from_row else -1
        var dc = 1 if move.to_col > move.from_col else -1
        
        var r = move.from_row + dr
        var c = move.from_col + dc
        
        while r != move.to_row:
            if not board.is_empty(r, c):
                return False
            r += dr
            c += dc
        
        return True
    
    fn is_clear_path(self, board: Board, move: Move) -> Bool:
        """Check if the path is clear for queen-like movement."""
        var dr = move.to_row - move.from_row
        var dc = move.to_col - move.from_col
        
        if dr == 0 or dc == 0:
            return self.is_clear_line(board, move)
        elif abs(dr) == abs(dc):
            return self.is_clear_diagonal(board, move)
        
        return False