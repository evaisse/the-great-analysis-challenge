"""
Chess board representation and manipulation.
"""

from typing import Optional, List, Tuple
from lib.attack_tables import king_attacks, knight_attacks, ray_attacks
from lib.types import Piece, PieceType, Color, Move, CastlingRights, CastlingConfig, GameState


class Board:
    """Represents a chess board with pieces and game state."""
    
    def __init__(self):
        """Initialize board to starting position."""
        self.board: List[List[Optional[Piece]]] = [[None for _ in range(8)] for _ in range(8)]
        self.to_move = Color.WHITE
        self.castling_rights = CastlingRights()
        self.castling_config = CastlingConfig()
        self.chess960_mode = False
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
        self.board = [[None for _ in range(8)] for _ in range(8)]
        self.castling_rights = CastlingRights()
        self.castling_config = CastlingConfig()
        self.chess960_mode = False
        self.en_passant_target = None
        self.halfmove_clock = 0
        self.fullmove_number = 1

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

    def line_path(self, start: Tuple[int, int], target: Tuple[int, int]) -> List[Tuple[int, int]]:
        """Return squares from start toward target, excluding start and including target."""
        if start == target:
            return []
        start_row, start_col = start
        target_row, target_col = target
        row_step = 0 if target_row == start_row else (1 if target_row > start_row else -1)
        col_step = 0 if target_col == start_col else (1 if target_col > start_col else -1)
        row = start_row + row_step
        col = start_col + col_step
        squares = []
        while (row, col) != target:
            squares.append((row, col))
            row += row_step
            col += col_step
        squares.append(target)
        return squares

    def get_castle_details(self, color: Color, side: str):
        """Return the generalized castling mapping for a side."""
        if color == Color.WHITE:
            king_start = (0, self.castling_config.white_king_col)
            rook_start = (
                0,
                self.castling_config.white_kingside_rook_col if side == 'K' else self.castling_config.white_queenside_rook_col,
            )
            king_target = (0, 6 if side == 'K' else 2)
            rook_target = (0, 5 if side == 'K' else 3)
        else:
            king_start = (7, self.castling_config.black_king_col)
            rook_start = (
                7,
                self.castling_config.black_kingside_rook_col if side == 'K' else self.castling_config.black_queenside_rook_col,
            )
            king_target = (7, 6 if side == 'K' else 2)
            rook_target = (7, 5 if side == 'K' else 3)
        return king_start, rook_start, king_target, rook_target
    
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
        for new_row, new_col in knight_attacks(row, col):
            piece = self.get_piece(new_row, new_col)
            if piece and piece.type == PieceType.KNIGHT and piece.color == by_color:
                return True
        
        # Check bishop/queen diagonal attacks
        diagonal_directions = [(-1, -1), (-1, 1), (1, -1), (1, 1)]
        for dr, dc in diagonal_directions:
            for new_row, new_col in ray_attacks(row, col, dr, dc):
                piece = self.get_piece(new_row, new_col)
                if piece:
                    if (piece.color == by_color and 
                        piece.type in [PieceType.BISHOP, PieceType.QUEEN]):
                        return True
                    break
        
        # Check rook/queen straight attacks
        straight_directions = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        for dr, dc in straight_directions:
            for new_row, new_col in ray_attacks(row, col, dr, dc):
                piece = self.get_piece(new_row, new_col)
                if piece:
                    if (piece.color == by_color and 
                        piece.type in [PieceType.ROOK, PieceType.QUEEN]):
                        return True
                    break
        
        # Check king attacks
        for new_row, new_col in king_attacks(row, col):
            piece = self.get_piece(new_row, new_col)
            if piece and piece.type == PieceType.KING and piece.color == by_color:
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
            castling_config=self.castling_config.copy(),
            chess960_mode=self.chess960_mode,
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
            castling_config=self.castling_config.copy(),
            chess960_mode=self.chess960_mode,
            en_passant_target=self.en_passant_target,
            halfmove_clock=self.halfmove_clock,
            zobrist_hash=self.zobrist_hash
        ))
        self.position_history.append(self.zobrist_hash)

        hash_val = self.zobrist_hash
        
        # Get the piece being moved
        piece = self.get_piece(move.from_row, move.from_col)
        if piece is None:
            return
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
            rook_from_col, rook_to_col = self._castling_rook_columns(piece.color, move.to_col)
            rook = self.get_piece(move.from_row, rook_from_col)
            if rook:
                self.set_piece(move.from_row, move.to_col, None)
                if rook_from_col != move.from_col:
                    self.set_piece(move.from_row, rook_from_col, None)
                self.set_piece(move.from_row, move.from_col, None)
                self.set_piece(move.from_row, move.to_col, final_piece)
                self.set_piece(move.from_row, rook_to_col, rook)
        
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
        if move.is_castling:
            self.zobrist_hash = zobrist.compute_hash(self)
        else:
            self.zobrist_hash = hash_val

    def _castling_rook_columns(self, color: Color, king_target_col: int) -> Tuple[int, int]:
        if color == Color.WHITE:
            if king_target_col == 6:
                return self.castling_config.white_kingside_rook_col, 5
            return self.castling_config.white_queenside_rook_col, 3
        if king_target_col == 6:
            return self.castling_config.black_kingside_rook_col, 5
        return self.castling_config.black_queenside_rook_col, 3

    def _castling_king_start_col(self, color: Color) -> int:
        return self.castling_config.white_king_col if color == Color.WHITE else self.castling_config.black_king_col

    def _find_home_rank_piece(self, color: Color, piece_type: PieceType) -> Optional[int]:
        row = 0 if color == Color.WHITE else 7
        for col in range(8):
            piece = self.get_piece(row, col)
            if piece and piece.color == color and piece.type == piece_type:
                return col
        return None

    def configure_chess960(self):
        white_king_col = self._find_home_rank_piece(Color.WHITE, PieceType.KING)
        black_king_col = self._find_home_rank_piece(Color.BLACK, PieceType.KING)

        if white_king_col is None or black_king_col is None:
            self.castling_config = CastlingConfig()
            self.chess960_mode = False
            return

        white_rooks = [
            col for col in range(8)
            if (piece := self.get_piece(0, col)) and piece.color == Color.WHITE and piece.type == PieceType.ROOK
        ]
        black_rooks = [
            col for col in range(8)
            if (piece := self.get_piece(7, col)) and piece.color == Color.BLACK and piece.type == PieceType.ROOK
        ]

        if not white_rooks or not black_rooks:
            self.castling_config = CastlingConfig()
            self.chess960_mode = False
            return

        self.castling_config = CastlingConfig(
            white_king_col=white_king_col,
            white_kingside_rook_col=max((col for col in white_rooks if col > white_king_col), default=7),
            white_queenside_rook_col=min((col for col in white_rooks if col < white_king_col), default=0),
            black_king_col=black_king_col,
            black_kingside_rook_col=max((col for col in black_rooks if col > black_king_col), default=7),
            black_queenside_rook_col=min((col for col in black_rooks if col < black_king_col), default=0),
        )
        self.chess960_mode = not self.castling_config.is_classical()

    def undo_move(self, move: Move):
        """Undo a move on the board."""
        if not self.game_history:
            return
        
        # Restore game state
        game_state = self.game_history.pop()
        self.irreversible_history.pop()
        self.position_history.pop()
        
        self.castling_rights = game_state.castling_rights
        self.castling_config = game_state.castling_config
        self.chess960_mode = game_state.chess960_mode
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
        king_color = king.color if king else (Color.WHITE if move.from_row == 0 else Color.BLACK)
        rook_from_col, rook_to_col = self._castling_rook_columns(king_color, move.to_col)
        
        # Move king back
        self.set_piece(move.from_row, move.from_col, king)
        if move.to_col != rook_from_col:
            self.set_piece(move.to_row, move.to_col, None)
        
        # Move rook back
        rook = self.get_piece(move.from_row, rook_to_col)
        self.set_piece(move.from_row, rook_from_col, rook)
        if rook_to_col != move.from_col:
            self.set_piece(move.from_row, rook_to_col, None)
    
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
                if move.from_row == 0 and move.from_col == self.castling_config.white_queenside_rook_col:
                    self.castling_rights.white_queenside = False
                elif move.from_row == 0 and move.from_col == self.castling_config.white_kingside_rook_col:
                    self.castling_rights.white_kingside = False
            else:
                if move.from_row == 7 and move.from_col == self.castling_config.black_queenside_rook_col:
                    self.castling_rights.black_queenside = False
                elif move.from_row == 7 and move.from_col == self.castling_config.black_kingside_rook_col:
                    self.castling_rights.black_kingside = False
        
        # Rook captured
        if move.to_row == 0 and move.to_col == self.castling_config.white_queenside_rook_col:
            self.castling_rights.white_queenside = False
        elif move.to_row == 0 and move.to_col == self.castling_config.white_kingside_rook_col:
            self.castling_rights.white_kingside = False
        elif move.to_row == 7 and move.to_col == self.castling_config.black_queenside_rook_col:
            self.castling_rights.black_queenside = False
        elif move.to_row == 7 and move.to_col == self.castling_config.black_kingside_rook_col:
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
