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
    when PieceType::Pawn
      100
    when PieceType::Knight
      320
    when PieceType::Bishop
      330
    when PieceType::Rook
      500
    when PieceType::Queen
      900
    when PieceType::King
      20000
    else
      0
    end
  end

  def to_index
    case self
    when PieceType::Pawn   then 0
    when PieceType::Knight then 1
    when PieceType::Bishop then 2
    when PieceType::Rook   then 3
    when PieceType::Queen  then 4
    when PieceType::King   then 5
    else                        0
    end
  end

  def symbol
    case self
    when PieceType::Pawn
      'P'
    when PieceType::Knight
      'N'
    when PieceType::Bishop
      'B'
    when PieceType::Rook
      'R'
    when PieceType::Queen
      'Q'
    when PieceType::King
      'K'
    else
      ' '
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
    promotion_str = @promotion ? @promotion.not_nil!.symbol.to_s.downcase : ""
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

module Zobrist
  @@piece_keys = Array(UInt64).new
  @@turn_key = 0u64
  @@castling_keys = Array(UInt64).new
  @@en_passant_keys = Array(UInt64).new
  @@initialized = false

  class Xorshift64
    def initialize(@state : UInt64)
    end

    def next : UInt64
      @state ^= @state << 13
      @state ^= @state >> 7
      @state ^= @state << 17
      @state
    end
  end

  def self.init
    return if @@initialized
    rng = Xorshift64.new(0x123456789ABCDEF0u64)

    768.times { @@piece_keys << rng.next }
    @@turn_key = rng.next
    16.times { @@castling_keys << rng.next }
    64.times { @@en_passant_keys << rng.next }
    @@initialized = true
  end

  def self.get_piece_key(square, piece_type, color)
    init
    index = square * 12 + piece_type.to_index + (color.white? ? 0 : 6)
    @@piece_keys[index]
  end

  def self.get_turn_key
    init
    @@turn_key
  end

  def self.get_castling_key(rights)
    init
    index = 0
    index |= 1 if rights.white_kingside
    index |= 2 if rights.white_queenside
    index |= 4 if rights.black_kingside
    index |= 8 if rights.black_queenside
    @@castling_keys[index]
  end

  def self.get_en_passant_key(square)
    init
    @@en_passant_keys[square]
  end

  def self.calculate_hash(game_state)
    h = 0u64
    game_state.board.each_with_index do |piece, square|
      if piece
        h ^= get_piece_key(square, piece.type, piece.color)
      end
    end
    h ^= get_turn_key if game_state.turn.black?
    h ^= get_castling_key(game_state.castling_rights)
    if ep = game_state.en_passant_target
      h ^= get_en_passant_key(ep)
    end
    h
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
  property hash : UInt64
  property position_history : Array(UInt64)

  def initialize(@board = Array(Piece?).new(64, nil),
                 @turn = Color::White,
                 @castling_rights = CastlingRights.new,
                 @en_passant_target = nil,
                 @halfmove_clock = 0,
                 @fullmove_number = 1,
                 @move_history = Array(Move).new,
                 @hash = 0u64,
                 @position_history = Array(UInt64).new)
    if @hash == 0u64
      @hash = Zobrist.calculate_hash(self)
    end
  end

  def dup
    new_board = @board.dup
    new_history = @move_history.dup
    new_pos_history = @position_history.dup
    GameState.new(
      new_board,
      @turn,
      @castling_rights,
      @en_passant_target,
      @halfmove_clock,
      @fullmove_number,
      new_history,
      @hash,
      new_pos_history
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
  "#{(('a'.ord + file).chr)}#{rank + 1}"
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
