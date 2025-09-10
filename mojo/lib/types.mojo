"""
Type definitions for the chess engine.
"""


@value
struct PieceType:
    """Chess piece types."""
    var value: Int
    
    fn __init__(inout self, value: Int):
        self.value = value
    
    @staticmethod
    fn PAWN() -> PieceType:
        return PieceType(1)
    
    @staticmethod
    fn KNIGHT() -> PieceType:
        return PieceType(2)
    
    @staticmethod
    fn BISHOP() -> PieceType:
        return PieceType(3)
    
    @staticmethod
    fn ROOK() -> PieceType:
        return PieceType(4)
    
    @staticmethod
    fn QUEEN() -> PieceType:
        return PieceType(5)
    
    @staticmethod
    fn KING() -> PieceType:
        return PieceType(6)
    
    fn __eq__(self, other: PieceType) -> Bool:
        return self.value == other.value
    
    fn __ne__(self, other: PieceType) -> Bool:
        return self.value != other.value
    
    fn to_char(self) -> String:
        if self.value == 1:
            return "P"
        elif self.value == 2:
            return "N"
        elif self.value == 3:
            return "B"
        elif self.value == 4:
            return "R"
        elif self.value == 5:
            return "Q"
        elif self.value == 6:
            return "K"
        else:
            return "?"


@value
struct Color:
    """Chess piece colors."""
    var value: Int
    
    fn __init__(inout self, value: Int):
        self.value = value
    
    @staticmethod
    fn WHITE() -> Color:
        return Color(0)
    
    @staticmethod
    fn BLACK() -> Color:
        return Color(1)
    
    fn __eq__(self, other: Color) -> Bool:
        return self.value == other.value
    
    fn __ne__(self, other: Color) -> Bool:
        return self.value != other.value


@value
struct Piece:
    """Represents a chess piece."""
    var piece_type: PieceType
    var color: Color
    
    fn __init__(inout self, piece_type: PieceType, color: Color):
        self.piece_type = piece_type
        self.color = color
    
    fn to_string(self) -> String:
        """Return the piece symbol."""
        var symbol = self.piece_type.to_char()
        if self.color == Color.WHITE():
            return symbol
        else:
            return symbol.lower()
    
    fn is_white(self) -> Bool:
        """Check if piece is white."""
        return self.color == Color.WHITE()
    
    fn is_black(self) -> Bool:
        """Check if piece is black."""
        return self.color == Color.BLACK()


@value
struct Move:
    """Represents a chess move."""
    var from_row: Int
    var from_col: Int
    var to_row: Int
    var to_col: Int
    var promotion: Int  # 0 = no promotion, 1-6 = piece type
    var is_castling: Bool
    var is_en_passant: Bool
    
    fn __init__(inout self, from_row: Int, from_col: Int, to_row: Int, to_col: Int):
        self.from_row = from_row
        self.from_col = from_col
        self.to_row = to_row
        self.to_col = to_col
        self.promotion = 0
        self.is_castling = False
        self.is_en_passant = False
    
    fn to_algebraic(self) -> String:
        """Convert move to algebraic notation."""
        var files = "abcdefgh"
        var from_file = files[self.from_col]
        var from_rank = str(self.from_row + 1)
        var to_file = files[self.to_col]
        var to_rank = str(self.to_row + 1)
        
        var result = from_file + from_rank + to_file + to_rank
        
        if self.promotion > 0:
            var promo_type = PieceType(self.promotion)
            result = result + promo_type.to_char()
        
        return result


@value
struct CastlingRights:
    """Tracks castling availability."""
    var white_kingside: Bool
    var white_queenside: Bool
    var black_kingside: Bool
    var black_queenside: Bool
    
    fn __init__(inout self):
        self.white_kingside = True
        self.white_queenside = True
        self.black_kingside = True
        self.black_queenside = True
    
    fn __init__(inout self, wk: Bool, wq: Bool, bk: Bool, bq: Bool):
        self.white_kingside = wk
        self.white_queenside = wq
        self.black_kingside = bk
        self.black_queenside = bq
    
    fn to_fen(self) -> String:
        """Convert to FEN castling string."""
        var result = ""
        if self.white_kingside:
            result = result + "K"
        if self.white_queenside:
            result = result + "Q"
        if self.black_kingside:
            result = result + "k"
        if self.black_queenside:
            result = result + "q"
        if len(result) == 0:
            return "-"
        return result


@value
struct Position:
    """Represents a position on the chess board."""
    var row: Int
    var col: Int
    
    fn __init__(inout self, row: Int, col: Int):
        self.row = row
        self.col = col
    
    fn is_valid(self) -> Bool:
        """Check if position is on the board."""
        return 0 <= self.row <= 7 and 0 <= self.col <= 7


fn parse_move(move_str: String) -> Move:
    """Parse algebraic notation into a Move object."""
    # Simple parsing for now - assumes valid format like "e2e4"
    var files = "abcdefgh"
    
    # Get positions of characters
    var from_file_char = move_str[0]
    var from_rank_char = move_str[1] 
    var to_file_char = move_str[2]
    var to_rank_char = move_str[3]
    
    # Convert to indices
    var from_col = ord(from_file_char) - ord("a")
    var from_row = int(from_rank_char) - 1
    var to_col = ord(to_file_char) - ord("a") 
    var to_row = int(to_rank_char) - 1
    
    var move = Move(from_row, from_col, to_row, to_col)
    
    # Handle promotion
    if len(move_str) > 4:
        var promo_char = move_str[4]
        if promo_char == "Q":
            move.promotion = 5
        elif promo_char == "R":
            move.promotion = 4
        elif promo_char == "B":
            move.promotion = 3
        elif promo_char == "N":
            move.promotion = 2
    
    return move