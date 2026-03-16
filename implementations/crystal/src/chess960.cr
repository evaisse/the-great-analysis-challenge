require "./types"
require "./board"

module Chess960
  KNIGHT_COMBINATIONS = [
    {0, 1},
    {0, 2},
    {0, 3},
    {0, 4},
    {1, 2},
    {1, 3},
    {1, 4},
    {2, 3},
    {2, 4},
    {3, 4},
  ]

  def self.starting_position(id : Int32) : GameState
    # Crystal still assumes classical castling squares, so Chess960 starts with castling disabled for now.
    Board.position_from_back_rank(piece_order(id), CastlingRights.none)
  end

  def self.piece_order(id : Int32) : Array(PieceType)
    raise ArgumentError.new("Chess960 id must be between 0 and 959") unless valid_id?(id)

    pieces = Array(PieceType?).new(8, nil)
    remainder = id

    bishop_dark = remainder % 4
    remainder //= 4
    pieces[2 * bishop_dark + 1] = PieceType::Bishop

    bishop_light = remainder % 4
    remainder //= 4
    pieces[2 * bishop_light] = PieceType::Bishop

    queen_slot = remainder % 6
    remainder //= 6
    empty = empty_squares(pieces)
    pieces[empty[queen_slot]] = PieceType::Queen

    knight_left, knight_right = KNIGHT_COMBINATIONS[remainder]
    empty = empty_squares(pieces)
    pieces[empty[knight_left]] = PieceType::Knight
    pieces[empty[knight_right]] = PieceType::Knight

    empty = empty_squares(pieces)
    pieces[empty[0]] = PieceType::Rook
    pieces[empty[1]] = PieceType::King
    pieces[empty[2]] = PieceType::Rook

    pieces.map(&.not_nil!)
  end

  def self.valid_id?(id : Int32) : Bool
    id >= 0 && id <= 959
  end

  private def self.empty_squares(pieces : Array(PieceType?)) : Array(Int32)
    empty = Array(Int32).new
    pieces.each_with_index do |piece, index|
      empty << index unless piece
    end
    empty
  end
end
