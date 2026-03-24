"""
Move generation for chess pieces.
"""

from typing import List, Optional
from lib.attack_tables import king_attacks, knight_attacks, ray_attacks
from lib.types import Move, Piece, PieceType, Color
from lib.board import Board


class MoveGenerator:
    """Generates legal moves for chess pieces."""
    
    def __init__(self, board: Board):
        self.board = board
    
    def generate_legal_moves(self) -> List[Move]:
        """Generate all legal moves for the current player."""
        pseudo_legal_moves = self.generate_pseudo_legal_moves()
        legal_moves = []
        
        for move in pseudo_legal_moves:
            if self.is_legal_move(move):
                legal_moves.append(move)
        
        return legal_moves
    
    def generate_pseudo_legal_moves(self) -> List[Move]:
        """Generate all pseudo-legal moves (not checking for check)."""
        moves = []
        
        for row in range(8):
            for col in range(8):
                piece = self.board.get_piece(row, col)
                if piece and piece.color == self.board.to_move:
                    piece_moves = self.generate_piece_moves(row, col, piece)
                    moves.extend(piece_moves)
        
        return moves
    
    def generate_piece_moves(self, row: int, col: int, piece: Piece) -> List[Move]:
        """Generate moves for a specific piece."""
        if piece.type == PieceType.PAWN:
            return self.generate_pawn_moves(row, col, piece)
        elif piece.type == PieceType.KNIGHT:
            return self.generate_knight_moves(row, col, piece)
        elif piece.type == PieceType.BISHOP:
            return self.generate_bishop_moves(row, col, piece)
        elif piece.type == PieceType.ROOK:
            return self.generate_rook_moves(row, col, piece)
        elif piece.type == PieceType.QUEEN:
            return self.generate_queen_moves(row, col, piece)
        elif piece.type == PieceType.KING:
            return self.generate_king_moves(row, col, piece)
        
        return []
    
    def generate_pawn_moves(self, row: int, col: int, piece: Piece) -> List[Move]:
        """Generate pawn moves."""
        moves = []
        direction = 1 if piece.color == Color.WHITE else -1
        start_row = 1 if piece.color == Color.WHITE else 6
        promotion_row = 7 if piece.color == Color.WHITE else 0
        
        # Forward moves
        new_row = row + direction
        if self.board.is_valid_square(new_row, col) and self.board.is_empty(new_row, col):
            if new_row == promotion_row:
                # Promotion
                for promo_type in [PieceType.QUEEN, PieceType.ROOK, 
                                 PieceType.BISHOP, PieceType.KNIGHT]:
                    moves.append(Move(row, col, new_row, col, promo_type))
            else:
                moves.append(Move(row, col, new_row, col))
            
            # Two square move from starting position
            if row == start_row:
                new_row = row + 2 * direction
                if self.board.is_valid_square(new_row, col) and self.board.is_empty(new_row, col):
                    move = Move(row, col, new_row, col)
                    moves.append(move)
        
        # Captures
        for dc in [-1, 1]:
            new_col = col + dc
            new_row = row + direction
            
            if self.board.is_valid_square(new_row, new_col):
                target_piece = self.board.get_piece(new_row, new_col)
                
                # Regular capture
                if target_piece and target_piece.color != piece.color:
                    if new_row == promotion_row:
                        # Promotion capture
                        for promo_type in [PieceType.QUEEN, PieceType.ROOK,
                                         PieceType.BISHOP, PieceType.KNIGHT]:
                            moves.append(Move(row, col, new_row, new_col, promo_type))
                    else:
                        moves.append(Move(row, col, new_row, new_col))
                
                # En passant capture
                elif (self.board.en_passant_target and 
                      self.board.en_passant_target == (new_row, new_col)):
                    move = Move(row, col, new_row, new_col)
                    move.is_en_passant = True
                    moves.append(move)
        
        return moves
    
    def generate_knight_moves(self, row: int, col: int, piece: Piece) -> List[Move]:
        """Generate knight moves."""
        moves = []
        for new_row, new_col in knight_attacks(row, col):
            target_piece = self.board.get_piece(new_row, new_col)

            if not target_piece or target_piece.color != piece.color:
                moves.append(Move(row, col, new_row, new_col))
        
        return moves
    
    def generate_bishop_moves(self, row: int, col: int, piece: Piece) -> List[Move]:
        """Generate bishop moves."""
        return self.generate_sliding_moves(row, col, piece,
                                         [(-1, -1), (-1, 1), (1, -1), (1, 1)])
    
    def generate_rook_moves(self, row: int, col: int, piece: Piece) -> List[Move]:
        """Generate rook moves."""
        return self.generate_sliding_moves(row, col, piece,
                                         [(-1, 0), (1, 0), (0, -1), (0, 1)])
    
    def generate_queen_moves(self, row: int, col: int, piece: Piece) -> List[Move]:
        """Generate queen moves."""
        return self.generate_sliding_moves(row, col, piece,
                                         [(-1, -1), (-1, 0), (-1, 1), (0, -1),
                                          (0, 1), (1, -1), (1, 0), (1, 1)])
    
    def generate_sliding_moves(self, row: int, col: int, piece: Piece,
                             directions: List[tuple]) -> List[Move]:
        """Generate moves for sliding pieces (bishop, rook, queen)."""
        moves = []
        
        for dr, dc in directions:
            for new_row, new_col in ray_attacks(row, col, dr, dc):
                target_piece = self.board.get_piece(new_row, new_col)
                
                if not target_piece:
                    moves.append(Move(row, col, new_row, new_col))
                elif target_piece.color != piece.color:
                    moves.append(Move(row, col, new_row, new_col))
                    break
                else:
                    break
        
        return moves
    
    def generate_king_moves(self, row: int, col: int, piece: Piece) -> List[Move]:
        """Generate king moves including castling."""
        moves = []

        for new_row, new_col in king_attacks(row, col):
            target_piece = self.board.get_piece(new_row, new_col)

            if not target_piece or target_piece.color != piece.color:
                moves.append(Move(row, col, new_row, new_col))
        
        # Castling moves
        if not self.board.is_in_check(piece.color):
            moves.extend(self.generate_castling_moves(row, col, piece))
        
        return moves
    
    def generate_castling_moves(self, row: int, col: int, piece: Piece) -> List[Move]:
        """Generate castling moves."""
        moves = []

        for side, has_right in (
            ('K', self.board.castling_rights.white_kingside if piece.color == Color.WHITE else self.board.castling_rights.black_kingside),
            ('Q', self.board.castling_rights.white_queenside if piece.color == Color.WHITE else self.board.castling_rights.black_queenside),
        ):
            if not has_right:
                continue

            king_start, rook_start, king_target, rook_target = self.board.get_castle_details(piece.color, side)
            if (row, col) != king_start:
                continue

            rook = self.board.get_piece(*rook_start)
            if not rook or rook.color != piece.color or rook.type != PieceType.ROOK:
                continue

            blocker_squares = []
            seen = set()
            for square in self.board.line_path(king_start, king_target) + self.board.line_path(rook_start, rook_target):
                if square not in seen:
                    blocker_squares.append(square)
                    seen.add(square)

            if any(
                square not in (king_start, rook_start) and
                not self.board.is_empty(square[0], square[1])
                for square in blocker_squares
            ):
                continue

            attack_squares = [king_start] + self.board.line_path(king_start, king_target)
            if any(
                self.board.is_square_attacked(square[0], square[1], Color.BLACK if piece.color == Color.WHITE else Color.WHITE)
                for square in dict.fromkeys(attack_squares)
            ):
                continue

            move = Move(row, col, king_target[0], king_target[1])
            move.is_castling = True
            moves.append(move)
        
        return moves
    
    def is_legal_move(self, move: Move) -> bool:
        """Check if a move is legal (doesn't leave king in check)."""
        # Make the move temporarily
        self.board.make_move(move)
        
        # Switch back the turn to check the correct king
        original_turn = self.board.to_move
        self.board.to_move = Color.BLACK if original_turn == Color.WHITE else Color.WHITE
        
        # Check if the king is in check after the move
        in_check = self.board.is_in_check(self.board.to_move)
        
        # Restore the turn
        self.board.to_move = original_turn
        
        # Undo the move
        self.board.undo_move(move)
        
        return not in_check
