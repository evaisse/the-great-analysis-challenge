"""
Chess board representation and manipulation.
"""
from .types import Piece, PieceType, Color, Move, CastlingRights, Position


struct Board:
    """Represents a chess board with pieces and game state."""
    var pieces: StaticTuple[Int, 64]  # piece encoding: 0=empty, 1-6=white pieces, 7-12=black pieces
    var to_move: Color
    var castling_rights: CastlingRights
    var en_passant_target: Int  # -1 = none, 0-63 = square index
    var halfmove_clock: Int
    var fullmove_number: Int
    
    fn __init__(inout self):
        """Initialize board to starting position."""
        self.pieces = StaticTuple[Int, 64]()
        
        # Initialize all squares as empty
        for i in range(64):
            self.pieces[i] = 0
        
        self.to_move = Color.WHITE()
        self.castling_rights = CastlingRights()
        self.en_passant_target = -1
        self.halfmove_clock = 0
        self.fullmove_number = 1
        
        self.setup_starting_position()
    
    fn setup_starting_position(inout self):
        """Set up the standard chess starting position."""
        # White pieces (1-6: P,N,B,R,Q,K)
        self.pieces[0] = 4   # a1 rook
        self.pieces[1] = 2   # b1 knight  
        self.pieces[2] = 3   # c1 bishop
        self.pieces[3] = 5   # d1 queen
        self.pieces[4] = 6   # e1 king
        self.pieces[5] = 3   # f1 bishop
        self.pieces[6] = 2   # g1 knight
        self.pieces[7] = 4   # h1 rook
        
        for col in range(8):
            self.pieces[8 + col] = 1  # white pawns on rank 2
        
        # Black pieces (7-12: p,n,b,r,q,k)
        self.pieces[56] = 10  # a8 rook
        self.pieces[57] = 8   # b8 knight
        self.pieces[58] = 9   # c8 bishop
        self.pieces[59] = 11  # d8 queen
        self.pieces[60] = 12  # e8 king
        self.pieces[61] = 9   # f8 bishop
        self.pieces[62] = 8   # g8 knight
        self.pieces[63] = 10  # h8 rook
        
        for col in range(8):
            self.pieces[48 + col] = 7  # black pawns on rank 7
    
    fn get_piece_at(self, row: Int, col: Int) -> Int:
        """Get piece code at given position."""
        if 0 <= row <= 7 and 0 <= col <= 7:
            return self.pieces[row * 8 + col]
        return 0
    
    fn set_piece_at(inout self, row: Int, col: Int, piece_code: Int):
        """Set piece code at given position."""
        if 0 <= row <= 7 and 0 <= col <= 7:
            self.pieces[row * 8 + col] = piece_code
    
    fn is_empty(self, row: Int, col: Int) -> Bool:
        """Check if square is empty."""
        return self.get_piece_at(row, col) == 0
    
    fn is_white_piece(self, piece_code: Int) -> Bool:
        """Check if piece code represents a white piece."""
        return 1 <= piece_code <= 6
    
    fn is_black_piece(self, piece_code: Int) -> Bool:
        """Check if piece code represents a black piece."""
        return 7 <= piece_code <= 12
    
    fn get_piece_type(self, piece_code: Int) -> Int:
        """Get piece type from piece code."""
        if piece_code == 0:
            return 0
        elif piece_code <= 6:
            return piece_code  # white pieces
        else:
            return piece_code - 6  # black pieces
    
    fn get_piece_color(self, piece_code: Int) -> Color:
        """Get piece color from piece code."""
        if self.is_white_piece(piece_code):
            return Color.WHITE()
        else:
            return Color.BLACK()
    
    fn piece_to_char(self, piece_code: Int) -> String:
        """Convert piece code to character representation."""
        if piece_code == 0:
            return "."
        
        var piece_type = self.get_piece_type(piece_code)
        var char = ""
        
        if piece_type == 1:
            char = "P"
        elif piece_type == 2:
            char = "N"
        elif piece_type == 3:
            char = "B"
        elif piece_type == 4:
            char = "R"
        elif piece_type == 5:
            char = "Q"
        elif piece_type == 6:
            char = "K"
        
        if self.is_black_piece(piece_code):
            return char.lower()
        else:
            return char
    
    fn find_king(self, color: Color) -> Int:
        """Find the king of the given color. Returns square index or -1."""
        var king_code = 6 if color == Color.WHITE() else 12
        
        for i in range(64):
            if self.pieces[i] == king_code:
                return i
        return -1
    
    fn make_move(inout self, move: Move) -> Bool:
        """Make a move on the board. Returns True if successful."""
        var from_square = move.from_row * 8 + move.from_col
        var to_square = move.to_row * 8 + move.to_col
        
        var piece_code = self.pieces[from_square]
        if piece_code == 0:
            return False
        
        # Verify it's the correct color's turn
        var piece_color = self.get_piece_color(piece_code)
        if piece_color != self.to_move:
            return False
        
        # Make the move
        self.pieces[to_square] = piece_code
        self.pieces[from_square] = 0
        
        # Handle promotion
        if move.promotion > 0:
            if piece_color == Color.WHITE():
                self.pieces[to_square] = move.promotion
            else:
                self.pieces[to_square] = move.promotion + 6
        
        # Handle castling
        if move.is_castling:
            if move.to_col == 6:  # Kingside
                var rook_code = self.pieces[move.from_row * 8 + 7]
                self.pieces[move.from_row * 8 + 5] = rook_code
                self.pieces[move.from_row * 8 + 7] = 0
            elif move.to_col == 2:  # Queenside
                var rook_code = self.pieces[move.from_row * 8 + 0]
                self.pieces[move.from_row * 8 + 3] = rook_code
                self.pieces[move.from_row * 8 + 0] = 0
        
        # Update game state
        self.to_move = Color.BLACK() if self.to_move == Color.WHITE() else Color.WHITE()
        
        # Update castling rights
        var piece_type = self.get_piece_type(piece_code)
        if piece_type == 6:  # King moved
            if piece_color == Color.WHITE():
                self.castling_rights.white_kingside = False
                self.castling_rights.white_queenside = False
            else:
                self.castling_rights.black_kingside = False
                self.castling_rights.black_queenside = False
        
        if piece_type == 4:  # Rook moved
            if piece_color == Color.WHITE():
                if from_square == 0:  # a1
                    self.castling_rights.white_queenside = False
                elif from_square == 7:  # h1
                    self.castling_rights.white_kingside = False
            else:
                if from_square == 56:  # a8
                    self.castling_rights.black_queenside = False
                elif from_square == 63:  # h8
                    self.castling_rights.black_kingside = False
        
        # Update en passant
        if piece_type == 1 and abs(move.to_row - move.from_row) == 2:
            # Double pawn move
            self.en_passant_target = (move.from_row + move.to_row) // 2 * 8 + move.from_col
        else:
            self.en_passant_target = -1
        
        # Update counters
        self.halfmove_clock += 1
        if self.to_move == Color.WHITE():
            self.fullmove_number += 1
        
        return True
    
    fn display(self) -> String:
        """Display the board in the standard format."""
        var result = "  a b c d e f g h\n"
        
        for row in range(7, -1, -1):
            result = result + str(row + 1) + " "
            
            for col in range(8):
                var piece_code = self.get_piece_at(row, col)
                result = result + self.piece_to_char(piece_code) + " "
            
            result = result + str(row + 1) + "\n"
        
        result = result + "  a b c d e f g h\n\n"
        
        if self.to_move == Color.WHITE():
            result = result + "White to move"
        else:
            result = result + "Black to move"
        
        return result