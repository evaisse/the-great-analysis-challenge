"""
FEN (Forsyth-Edwards Notation) parser and serializer.
"""

from typing import Optional
from lib.types import Piece, PieceType, Color, CastlingRights
from lib.board import Board


class FenParser:
    """Parses and generates FEN strings."""
    
    def __init__(self, board: Board):
        self.board = board
    
    def parse(self, fen: str):
        """Parse a FEN string and update the board."""
        parts = fen.strip().split()
        
        if len(parts) != 6:
            raise ValueError("Invalid FEN: must have 6 parts")
        
        pieces_str, turn_str, castling_str, en_passant_str, halfmove_str, fullmove_str = parts
        
        # Parse board position
        self._parse_pieces(pieces_str)
        
        # Parse turn
        self._parse_turn(turn_str)
        
        # Parse castling rights
        self._parse_castling(castling_str)
        
        # Parse en passant
        self._parse_en_passant(en_passant_str)
        
        # Parse move clocks
        self._parse_clocks(halfmove_str, fullmove_str)
    
    def _parse_pieces(self, pieces_str: str):
        """Parse piece placement from FEN."""
        # Clear the board
        for row in range(8):
            for col in range(8):
                self.board.set_piece(row, col, None)
        
        ranks = pieces_str.split('/')
        if len(ranks) != 8:
            raise ValueError("Invalid FEN: board must have 8 ranks")
        
        for rank_idx, rank in enumerate(ranks):
            row = 7 - rank_idx  # FEN starts from rank 8
            col = 0
            
            for char in rank:
                if char.isdigit():
                    # Empty squares
                    col += int(char)
                else:
                    # Piece
                    piece = self._char_to_piece(char)
                    if not piece:
                        raise ValueError(f"Invalid piece character: {char}")
                    
                    if col >= 8:
                        raise ValueError("Invalid FEN: too many pieces in rank")
                    
                    self.board.set_piece(row, col, piece)
                    col += 1
            
            if col != 8:
                raise ValueError("Invalid FEN: incorrect number of squares in rank")
    
    def _parse_turn(self, turn_str: str):
        """Parse active color from FEN."""
        if turn_str == 'w':
            self.board.to_move = Color.WHITE
        elif turn_str == 'b':
            self.board.to_move = Color.BLACK
        else:
            raise ValueError(f"Invalid turn indicator: {turn_str}")
    
    def _parse_castling(self, castling_str: str):
        """Parse castling availability from FEN."""
        self.board.castling_rights = CastlingRights(False, False, False, False)
        
        if castling_str != '-':
            for char in castling_str:
                if char == 'K':
                    self.board.castling_rights.white_kingside = True
                elif char == 'Q':
                    self.board.castling_rights.white_queenside = True
                elif char == 'k':
                    self.board.castling_rights.black_kingside = True
                elif char == 'q':
                    self.board.castling_rights.black_queenside = True
                else:
                    raise ValueError(f"Invalid castling character: {char}")
    
    def _parse_en_passant(self, en_passant_str: str):
        """Parse en passant target from FEN."""
        if en_passant_str == '-':
            self.board.en_passant_target = None
        else:
            if len(en_passant_str) != 2:
                raise ValueError(f"Invalid en passant square: {en_passant_str}")
            
            file_char, rank_char = en_passant_str
            col = ord(file_char.lower()) - ord('a')
            row = int(rank_char) - 1
            
            if not (0 <= col <= 7 and 0 <= row <= 7):
                raise ValueError(f"Invalid en passant square: {en_passant_str}")
            
            self.board.en_passant_target = (row, col)
    
    def _parse_clocks(self, halfmove_str: str, fullmove_str: str):
        """Parse move clocks from FEN."""
        try:
            self.board.halfmove_clock = int(halfmove_str)
            self.board.fullmove_number = int(fullmove_str)
        except ValueError:
            raise ValueError("Invalid move clock values")
        
        if self.board.halfmove_clock < 0 or self.board.fullmove_number < 1:
            raise ValueError("Invalid move clock values")
    
    def _char_to_piece(self, char: str) -> Optional[Piece]:
        """Convert FEN character to Piece object."""
        piece_map = {
            'P': (PieceType.PAWN, Color.WHITE),
            'N': (PieceType.KNIGHT, Color.WHITE),
            'B': (PieceType.BISHOP, Color.WHITE),
            'R': (PieceType.ROOK, Color.WHITE),
            'Q': (PieceType.QUEEN, Color.WHITE),
            'K': (PieceType.KING, Color.WHITE),
            'p': (PieceType.PAWN, Color.BLACK),
            'n': (PieceType.KNIGHT, Color.BLACK),
            'b': (PieceType.BISHOP, Color.BLACK),
            'r': (PieceType.ROOK, Color.BLACK),
            'q': (PieceType.QUEEN, Color.BLACK),
            'k': (PieceType.KING, Color.BLACK),
        }
        
        if char in piece_map:
            piece_type, color = piece_map[char]
            return Piece(piece_type, color)
        
        return None
    
    def export(self) -> str:
        """Generate FEN string from current board position."""
        # Generate piece placement
        pieces_str = self._generate_pieces_string()
        
        # Generate turn
        turn_str = 'w' if self.board.to_move == Color.WHITE else 'b'
        
        # Generate castling
        castling_str = self.board.castling_rights.to_fen()
        
        # Generate en passant
        en_passant_str = self._generate_en_passant_string()
        
        # Generate clocks
        halfmove_str = str(self.board.halfmove_clock)
        fullmove_str = str(self.board.fullmove_number)
        
        return f"{pieces_str} {turn_str} {castling_str} {en_passant_str} {halfmove_str} {fullmove_str}"
    
    def _generate_pieces_string(self) -> str:
        """Generate piece placement string for FEN."""
        ranks = []
        
        for rank_idx in range(8):
            row = 7 - rank_idx  # FEN starts from rank 8
            rank_str = ""
            empty_count = 0
            
            for col in range(8):
                piece = self.board.get_piece(row, col)
                
                if piece:
                    if empty_count > 0:
                        rank_str += str(empty_count)
                        empty_count = 0
                    rank_str += str(piece)
                else:
                    empty_count += 1
            
            if empty_count > 0:
                rank_str += str(empty_count)
            
            ranks.append(rank_str)
        
        return '/'.join(ranks)
    
    def _generate_en_passant_string(self) -> str:
        """Generate en passant string for FEN."""
        if not self.board.en_passant_target:
            return '-'
        
        row, col = self.board.en_passant_target
        file_char = chr(ord('a') + col)
        rank_char = str(row + 1)
        
        return file_char + rank_char