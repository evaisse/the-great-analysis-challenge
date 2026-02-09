"""
Chess board representation and manipulation.
"""

from typing import Optional, List, Tuple
from lib.types import Piece, PieceType, Color, Move, CastlingRights, GameState


class Board:
    """Represents a chess board with pieces and game state."""
    
    def __init__(self):
        """Initialize board to starting position."""
        self.board = [[None for _ in range(8)] for _ in range(8)]
        self.to_move = Color.WHITE
        self.castling_rights = CastlingRights()
        self.en_passant_target: Optional[Tuple[int, int]] = None
        self.halfmove_clock = 0
        self.fullmove_number = 1
        self.game_history: List[GameState] = []
        self.zobrist_hash = 0
        self.position_history = []
        self.irreversible_history = []
        
        self.setup_starting_position()
        from lib.zobrist import zobrist
        self.zobrist_hash = zobrist.compute_hash(self)
    
    def setup_starting_position(self):
        """Set up the standard chess starting position."""
        # White pieces
        self.board[0][0] = Piece(PieceType.ROOK, Color.WHITE)
        self.board[0][1] = Piece(PieceType.KNIGHT, Color.WHITE)
        self.board[0][2] = Piece(PieceType.BISHOP, Color.WHITE)
        self.board[0][3] = Piece(PieceType.QUEEN, Color.WHITE)
        self.board[0][4] = Piece(PieceType.KING, Color.WHITE)
        self.board[0][5] = Piece(PieceType.BISHOP, Color.WHITE)
        self.board[0][6] = Piece(PieceType.KNIGHT, Color.WHITE)
        self.board[0][7] = Piece(PieceType.ROOK, Color.WHITE)
        
        for col in range(8):
            self.board[1][col] = Piece(PieceType.PAWN, Color.WHITE)
        
        # Black pieces
        self.board[7][0] = Piece(PieceType.ROOK, Color.BLACK)
        self.board[7][1] = Piece(PieceType.KNIGHT, Color.BLACK)
        self.board[7][2] = Piece(PieceType.BISHOP, Color.BLACK)
        self.board[7][3] = Piece(PieceType.QUEEN, Color.BLACK)
        self.board[7][4] = Piece(PieceType.KING, Color.BLACK)
        self.board[7][5] = Piece(PieceType.BISHOP, Color.BLACK)
        self.board[7][6] = Piece(PieceType.KNIGHT, Color.BLACK)
        self.board[7][7] = Piece(PieceType.ROOK, Color.BLACK)
        
        for col in range(8):
            self.board[6][col] = Piece(PieceType.PAWN, Color.BLACK)
    
    def get_piece(self, row: int, col: int) -> Optional[Piece]:
        """Get piece at given position."""
        if 0 <= row <= 7 and 0 <= col <= 7:
            return self.board[row][col]
        return None
    
    def set_piece(self, row: int, col: int, piece: Optional[Piece]):
        """Set piece at given position."""
        if 0 <= row <= 7 and 0 <= col <= 7:
            self.board[row][col] = piece
    
    def is_valid_square(self, row: int, col: int) -> bool:
        """Check if square coordinates are valid."""
        return 0 <= row <= 7 and 0 <= col <= 7
    
    def is_empty(self, row: int, col: int) -> bool:
        """Check if square is empty."""
        return self.get_piece(row, col) is None
    
    def find_king(self, color: Color) -> Optional[Tuple[int, int]]:
        """Find the king of the given color."""
        for row in range(8):
            for col in range(8):
                piece = self.get_piece(row, col)
                if piece and piece.type == PieceType.KING and piece.color == color:
                    return (row, col)
        return None
    
    def is_square_attacked(self, row: int, col: int, by_color: Color) -> bool:
        """Check if a square is attacked by pieces of the given color."""
        # Check pawn attacks
        pawn_direction = 1 if by_color == Color.WHITE else -1
        pawn_start_row = row - pawn_direction
        
        for pawn_col in [col - 1, col + 1]:
            if self.is_valid_square(pawn_start_row, pawn_col):
                piece = self.get_piece(pawn_start_row, pawn_col)
                if (piece and piece.type == PieceType.PAWN and 
                    piece.color == by_color):
                    return True
        
        # Check knight attacks
        knight_moves = [(-2, -1), (-2, 1), (-1, -2), (-1, 2),
                       (1, -2), (1, 2), (2, -1), (2, 1)]
        for dr, dc in knight_moves:
            new_row, new_col = row + dr, col + dc
            if self.is_valid_square(new_row, new_col):
                piece = self.get_piece(new_row, new_col)
                if (piece and piece.type == PieceType.KNIGHT and 
                    piece.color == by_color):
                    return True
        
        # Check bishop/queen diagonal attacks
        diagonal_directions = [(-1, -1), (-1, 1), (1, -1), (1, 1)]
        for dr, dc in diagonal_directions:
            for i in range(1, 8):
                new_row, new_col = row + i * dr, col + i * dc
                if not self.is_valid_square(new_row, new_col):
                    break
                piece = self.get_piece(new_row, new_col)
                if piece:
                    if (piece.color == by_color and 
                        piece.type in [PieceType.BISHOP, PieceType.QUEEN]):
                        return True
                    break
        
        # Check rook/queen straight attacks
        straight_directions = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        for dr, dc in straight_directions:
            for i in range(1, 8):
                new_row, new_col = row + i * dr, col + i * dc
                if not self.is_valid_square(new_row, new_col):
                    break
                piece = self.get_piece(new_row, new_col)
                if piece:
                    if (piece.color == by_color and 
                        piece.type in [PieceType.ROOK, PieceType.QUEEN]):
                        return True
                    break
        
        # Check king attacks
        king_moves = [(-1, -1), (-1, 0), (-1, 1), (0, -1),
                     (0, 1), (1, -1), (1, 0), (1, 1)]
        for dr, dc in king_moves:
            new_row, new_col = row + dr, col + dc
            if self.is_valid_square(new_row, new_col):
                piece = self.get_piece(new_row, new_col)
                if (piece and piece.type == PieceType.KING and 
                    piece.color == by_color):
                    return True
        
        return False
    
    def is_in_check(self, color: Color) -> bool:
        """Check if the king of the given color is in check."""
        king_pos = self.find_king(color)
        if not king_pos:
            return False
        
        opponent_color = Color.BLACK if color == Color.WHITE else Color.WHITE
        return self.is_square_attacked(king_pos[0], king_pos[1], opponent_color)
    
    def make_move(self, move: Move):
        """Make a move on the board."""
        from lib.zobrist import zobrist
        from lib.types import IrreversibleState
        
        # Save current game state for undo
        game_state = GameState(
            castling_rights=self.castling_rights.copy(),
            en_passant_target=self.en_passant_target,
            halfmove_clock=self.halfmove_clock,
            fullmove_number=self.fullmove_number,
            zobrist_hash=self.zobrist_hash,
            position_history=self.position_history.copy(),
            irreversible_history=self.irreversible_history.copy(),
            captured_piece=move.captured_piece
        )
        self.game_history.append(game_state)
        self.irreversible_history.append(IrreversibleState(
            castling_rights=self.castling_rights.copy(),
            en_passant_target=self.en_passant_target,
            halfmove_clock=self.halfmove_clock,
            zobrist_hash=self.zobrist_hash
        ))
        self.position_history.append(self.zobrist_hash)

        hash_val = self.zobrist_hash
        
        # Get the piece being moved
        piece = self.get_piece(move.from_row, move.from_col)
        target_piece = self.get_piece(move.to_row, move.to_col)
        
        # 1. Remove moving piece from source
        if piece:
            hash_val ^= zobrist.pieces[zobrist.get_piece_index(piece)][move.from_row * 8 + move.from_col]
        
        # 2. Handle capture
        if move.is_en_passant:
            captured_row = move.from_row
            captured_piece = Piece(PieceType.PAWN, Color.BLACK if piece.color == Color.WHITE else Color.WHITE)
            hash_val ^= zobrist.pieces[zobrist.get_piece_index(captured_piece)][captured_row * 8 + move.to_col]
            self.set_piece(captured_row, move.to_col, None)
            move.captured_piece = captured_piece
        elif target_piece:
            hash_val ^= zobrist.pieces[zobrist.get_piece_index(target_piece)][move.to_row * 8 + move.to_col]
            move.captured_piece = target_piece

        # 3. Place piece at destination
        final_piece = piece
        if move.promotion and piece:
            final_piece = Piece(move.promotion, piece.color)
        
        if final_piece:
            hash_val ^= zobrist.pieces[zobrist.get_piece_index(final_piece)][move.to_row * 8 + move.to_col]
            self.set_piece(move.to_row, move.to_col, final_piece)
            self.set_piece(move.from_row, move.from_col, None)

        # 4. Handle castling rook
        if move.is_castling:
            if move.to_col == 6:  # Kingside
                rook = self.get_piece(move.from_row, 7)
                if rook:
                    hash_val ^= zobrist.pieces[zobrist.get_piece_index(rook)][move.from_row * 8 + 7]
                    hash_val ^= zobrist.pieces[zobrist.get_piece_index(rook)][move.from_row * 8 + 5]
                    self.set_piece(move.from_row, 5, rook)
                    self.set_piece(move.from_row, 7, None)
            else:  # Queenside
                rook = self.get_piece(move.from_row, 0)
                if rook:
                    hash_val ^= zobrist.pieces[zobrist.get_piece_index(rook)][move.from_row * 8 + 0]
                    hash_val ^= zobrist.pieces[zobrist.get_piece_index(rook)][move.from_row * 8 + 3]
                    self.set_piece(move.from_row, 3, rook)
                    self.set_piece(move.from_row, 0, None)

        # 5. Update castling rights in hash
        rights = self.castling_rights
        if rights.white_kingside: hash_val ^= zobrist.castling[0]
        if rights.white_queenside: hash_val ^= zobrist.castling[1]
        if rights.black_kingside: hash_val ^= zobrist.castling[2]
        if rights.black_queenside: hash_val ^= zobrist.castling[3]

        self._update_castling_rights(move, piece)
        
        rights = self.castling_rights
        if rights.white_kingside: hash_val ^= zobrist.castling[0]
        if rights.white_queenside: hash_val ^= zobrist.castling[1]
        if rights.black_kingside: hash_val ^= zobrist.castling[2]
        if rights.black_queenside: hash_val ^= zobrist.castling[3]

        # 6. Update en passant target in hash
        if self.en_passant_target:
            hash_val ^= zobrist.en_passant[self.en_passant_target[1]]
        
        self._update_en_passant_target(move, piece)
        
        if self.en_passant_target:
            hash_val ^= zobrist.en_passant[self.en_passant_target[1]]

        # 7. Update side to move and clocks
        hash_val ^= zobrist.side_to_move
        
        if target_piece or (piece and piece.type == PieceType.PAWN):
            self.halfmove_clock = 0
        else:
            self.halfmove_clock += 1
        
        if self.to_move == Color.BLACK:
            self.fullmove_number += 1
        
        self.to_move = Color.BLACK if self.to_move == Color.WHITE else Color.WHITE
        self.zobrist_hash = hash_val

    def undo_move(self, move: Move):
        """Undo a move on the board."""
        if not self.game_history:
            return
        
        # Restore game state
        game_state = self.game_history.pop()
        self.irreversible_history.pop()
        self.position_history.pop()
        
        self.castling_rights = game_state.castling_rights
        self.en_passant_target = game_state.en_passant_target
        self.halfmove_clock = game_state.halfmove_clock
        self.fullmove_number = game_state.fullmove_number
        self.zobrist_hash = game_state.zobrist_hash
        
        # Switch turns back
        self.to_move = Color.BLACK if self.to_move == Color.WHITE else Color.WHITE
        
        # Get the piece that was moved
        moved_piece = self.get_piece(move.to_row, move.to_col)
        
        # Handle special undos
        if move.is_castling:
            self._undo_castling(move)
        elif move.is_en_passant:
            self._undo_en_passant(move)
        else:
            # Normal undo
            # Handle promotion undo
            if move.promotion and moved_piece:
                original_piece = Piece(PieceType.PAWN, moved_piece.color)
                self.set_piece(move.from_row, move.from_col, original_piece)
            else:
                self.set_piece(move.from_row, move.from_col, moved_piece)
            
            # Restore captured piece
            self.set_piece(move.to_row, move.to_col, move.captured_piece)
    
    def _handle_castling(self, move: Move):
        """Handle castling move."""
        king = self.get_piece(move.from_row, move.from_col)
        
        # Move king
        self.set_piece(move.to_row, move.to_col, king)
        self.set_piece(move.from_row, move.from_col, None)
        
        # Move rook
        if move.to_col == 6:  # Kingside
            rook = self.get_piece(move.from_row, 7)
            self.set_piece(move.from_row, 5, rook)
            self.set_piece(move.from_row, 7, None)
        else:  # Queenside
            rook = self.get_piece(move.from_row, 0)
            self.set_piece(move.from_row, 3, rook)
            self.set_piece(move.from_row, 0, None)
    
    def _handle_en_passant(self, move: Move):
        """Handle en passant capture."""
        pawn = self.get_piece(move.from_row, move.from_col)
        
        # Move pawn
        self.set_piece(move.to_row, move.to_col, pawn)
        self.set_piece(move.from_row, move.from_col, None)
        
        # Remove captured pawn
        captured_row = move.from_row
        self.set_piece(captured_row, move.to_col, None)
    
    def _undo_castling(self, move: Move):
        """Undo castling move."""
        king = self.get_piece(move.to_row, move.to_col)
        
        # Move king back
        self.set_piece(move.from_row, move.from_col, king)
        self.set_piece(move.to_row, move.to_col, None)
        
        # Move rook back
        if move.to_col == 6:  # Kingside
            rook = self.get_piece(move.from_row, 5)
            self.set_piece(move.from_row, 7, rook)
            self.set_piece(move.from_row, 5, None)
        else:  # Queenside
            rook = self.get_piece(move.from_row, 3)
            self.set_piece(move.from_row, 0, rook)
            self.set_piece(move.from_row, 3, None)
    
    def _undo_en_passant(self, move: Move):
        """Undo en passant capture."""
        pawn = self.get_piece(move.to_row, move.to_col)
        
        # Move pawn back
        self.set_piece(move.from_row, move.from_col, pawn)
        self.set_piece(move.to_row, move.to_col, None)
        
        # Restore captured pawn
        captured_pawn_color = Color.BLACK if pawn and pawn.color == Color.WHITE else Color.WHITE
        captured_pawn = Piece(PieceType.PAWN, captured_pawn_color)
        captured_row = move.from_row
        self.set_piece(captured_row, move.to_col, captured_pawn)
    
    def _update_castling_rights(self, move: Move, piece: Optional[Piece]):
        """Update castling rights after a move."""
        if not piece:
            return
        
        # King moves
        if piece.type == PieceType.KING:
            if piece.color == Color.WHITE:
                self.castling_rights.white_kingside = False
                self.castling_rights.white_queenside = False
            else:
                self.castling_rights.black_kingside = False
                self.castling_rights.black_queenside = False
        
        # Rook moves
        elif piece.type == PieceType.ROOK:
            if piece.color == Color.WHITE:
                if move.from_row == 0 and move.from_col == 0:
                    self.castling_rights.white_queenside = False
                elif move.from_row == 0 and move.from_col == 7:
                    self.castling_rights.white_kingside = False
            else:
                if move.from_row == 7 and move.from_col == 0:
                    self.castling_rights.black_queenside = False
                elif move.from_row == 7 and move.from_col == 7:
                    self.castling_rights.black_kingside = False
        
        # Rook captured
        if move.to_row == 0 and move.to_col == 0:
            self.castling_rights.white_queenside = False
        elif move.to_row == 0 and move.to_col == 7:
            self.castling_rights.white_kingside = False
        elif move.to_row == 7 and move.to_col == 0:
            self.castling_rights.black_queenside = False
        elif move.to_row == 7 and move.to_col == 7:
            self.castling_rights.black_kingside = False
    
    def _update_en_passant_target(self, move: Move, piece: Optional[Piece]):
        """Update en passant target square."""
        self.en_passant_target = None
        
        if (piece and piece.type == PieceType.PAWN and 
            abs(move.to_row - move.from_row) == 2):
            # Pawn moved two squares, set en passant target
            target_row = (move.from_row + move.to_row) // 2
            self.en_passant_target = (target_row, move.to_col)
    
    def get_game_status(self) -> str:
        """Get current game status."""
        from lib.move_generator import MoveGenerator
        move_gen = MoveGenerator(self)
        legal_moves = move_gen.generate_legal_moves()
        
        if not legal_moves:
            if self.is_in_check(self.to_move):
                return 'checkmate'
            else:
                return 'stalemate'
        
        return 'ongoing'
    
    def display(self) -> str:
        """Return ASCII representation of the board."""
        result = []
        result.append("  a b c d e f g h")
        
        for row in range(7, -1, -1):
            line = f"{row + 1} "
            for col in range(8):
                piece = self.get_piece(row, col)
                if piece:
                    line += str(piece) + " "
                else:
                    line += ". "
            line += f"{row + 1}"
            result.append(line)
        
        result.append("  a b c d e f g h")
        result.append("")
        
        color_str = "White" if self.to_move == Color.WHITE else "Black"
        result.append(f"{color_str} to move")
        
        return "\n".join(result)