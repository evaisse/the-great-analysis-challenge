# Core chess types and data structures

enum Color
  White
  Black

  def opposite
    case self
    in .white?
      Black
    in .black?
      White
    end
  end
end

enum PieceType
  Pawn
  Knight
  Bishop
  Rook
  Queen
  King

  def value
    case self
    in .pawn?
      100
    in .knight?
      320
    in .bishop?
      330
    in .rook?
      500
    in .queen?
      900
    in .king?
      20000
    end
  end

  def symbol
    case self
    in .pawn?
      'P'
    in .knight?
      'N'
    in .bishop?
      'B'
    in .rook?
      'R'
    in .queen?
      'Q'
    in .king?
      'K'
    end
  end

  def self.from_char(char : Char)
    case char.upcase
    when 'P'
      Pawn
    when 'N'
      Knight
    when 'B'
      Bishop
    when 'R'
      Rook
    when 'Q'
      Queen
    when 'K'
      King
    else
      nil
    end
  end
end

struct Piece
  getter type : PieceType
  getter color : Color

  def initialize(@type : PieceType, @color : Color)
  end

  def to_char
    char = @type.symbol
    @color.white? ? char : char.downcase
  end

  def self.from_char(char : Char)
    piece_type = PieceType.from_char(char)
    return nil unless piece_type

    color = char.ascii_uppercase? ? Color::White : Color::Black
    Piece.new(piece_type, color)
  end
end

alias Square = Int32

struct Move
  getter from : Square
  getter to : Square
  getter piece : PieceType
  getter captured : PieceType?
  getter promotion : PieceType?
  getter is_castling : Bool
  getter is_en_passant : Bool

  def initialize(@from : Square, @to : Square, @piece : PieceType,
                 @captured : PieceType? = nil, @promotion : PieceType? = nil,
                 @is_castling : Bool = false, @is_en_passant : Bool = false)
  end

  def to_s(io : IO) : Nil
    from_str = square_to_algebraic(@from)
    to_str = square_to_algebraic(@to)
    promotion_str = @promotion ? @promotion.not_nil!.symbol.to_s : ""
    io << from_str << to_str << promotion_str
  end
end

struct CastlingRights
  getter white_kingside : Bool
  getter white_queenside : Bool
  getter black_kingside : Bool
  getter black_queenside : Bool

  def initialize(@white_kingside : Bool = true, @white_queenside : Bool = true,
                 @black_kingside : Bool = true, @black_queenside : Bool = true)
  end

  def self.none
    CastlingRights.new(false, false, false, false)
  end
end

class GameState
  property board : Array(Piece?)
  property turn : Color
  property castling_rights : CastlingRights
  property en_passant_target : Square?
  property halfmove_clock : Int32
  property fullmove_number : Int32
  property move_history : Array(Move)

  def initialize(@board = Array(Piece?).new(64, nil),
                 @turn = Color::White,
                 @castling_rights = CastlingRights.new,
                 @en_passant_target = nil,
                 @halfmove_clock = 0,
                 @fullmove_number = 1,
                 @move_history = Array(Move).new)
  end

  def dup
    new_board = @board.map { |piece| piece }  # Deep copy the board array
    GameState.new(
      new_board,
      @turn,
      @castling_rights,
      @en_passant_target,
      @halfmove_clock,
      @fullmove_number,
      [] of Move  # Don't copy history to avoid circular references
    )
  end
end

struct SearchResult
  getter best_move : Move?
  getter evaluation : Int32
  getter nodes : Int32
  getter time_ms : Int64

  def initialize(@best_move : Move?, @evaluation : Int32, @nodes : Int32, @time_ms : Int64)
  end
end

# Utility functions
def square_to_algebraic(square : Square) : String
  file = square % 8
  rank = square // 8
  "#{('a'.ord + file).chr}#{rank + 1}"
end

def algebraic_to_square(algebraic : String) : Square?
  return nil if algebraic.size != 2

  file = algebraic[0].ord - 'a'.ord
  rank = algebraic[1].ord - '1'.ord

  return nil if file < 0 || file > 7 || rank < 0 || rank > 7

  rank * 8 + file
end

def valid_square?(square : Square) : Bool
  square >= 0 && square <= 63
end

# Constants for display
FILES = "abcdefgh"
RANKS = "12345678"