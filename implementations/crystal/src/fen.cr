# FEN (Forsyth-Edwards Notation) parsing and export

require "./types"
require "./board"

class FEN
  STARTING_FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

  def self.parse(fen : String) : GameState?
    parts = fen.split(' ')
    return nil unless parts.size == 6

    board_str, turn_str, castling_str, en_passant_str, halfmove_str, fullmove_str = parts

    # Parse board
    board = Array(Piece?).new(64, nil)
    rank = 7
    file = 0

    board_str.each_char do |char|
      case char
      when '/'
        rank -= 1
        file = 0
      when '1'..'8'
        file += char.to_i
      else
        piece = Piece.from_char(char)
        return nil unless piece
        
        square = rank * 8 + file
        return nil unless valid_square?(square)
        
        board[square] = piece
        file += 1
      end
    end

    # Parse turn
    turn = case turn_str
           when "w"
             Color::White
           when "b"
             Color::Black
           else
             return nil
           end

    # Parse castling rights
    castling_rights = CastlingRights.new(
      castling_str.includes?('K'),
      castling_str.includes?('Q'),
      castling_str.includes?('k'),
      castling_str.includes?('q')
    )

    # Parse en passant target
    en_passant_target = if en_passant_str == "-"
                          nil
                        else
                          algebraic_to_square(en_passant_str)
                        end

    # Parse halfmove clock
    halfmove_clock = halfmove_str.to_i? || 0

    # Parse fullmove number
    fullmove_number = fullmove_str.to_i? || 1

    GameState.new(
      board,
      turn,
      castling_rights,
      en_passant_target,
      halfmove_clock,
      fullmove_number
    )
  rescue
    nil
  end

  def self.export(game_state : GameState) : String
    # Export board
    board_str = String.build do |io|
      7.downto(0) do |rank|
        empty_count = 0
        
        8.times do |file|
          square = rank * 8 + file
          piece = game_state.board[square]
          
          if piece
            if empty_count > 0
              io << empty_count
              empty_count = 0
            end
            io << piece.to_char
          else
            empty_count += 1
          end
        end
        
        if empty_count > 0
          io << empty_count
        end
        
        io << '/' unless rank == 0
      end
    end

    # Export turn
    turn_str = game_state.turn.white? ? "w" : "b"

    # Export castling rights
    castling_str = String.build do |io|
      io << 'K' if game_state.castling_rights.white_kingside
      io << 'Q' if game_state.castling_rights.white_queenside
      io << 'k' if game_state.castling_rights.black_kingside
      io << 'q' if game_state.castling_rights.black_queenside
    end
    castling_str = "-" if castling_str.empty?

    # Export en passant target
    en_passant_str = "-"
    # if target = game_state.en_passant_target
    #   en_passant_str = square_to_algebraic(target)
    # else
    #   en_passant_str = "-"
    # end

    # Build FEN string
    "#{board_str} #{turn_str} #{castling_str} #{en_passant_str} #{game_state.halfmove_clock} #{game_state.fullmove_number}"
  end

  def self.starting_position : GameState
    parse(STARTING_FEN) || Board.initial_position
  end

  # Common test positions
  def self.test_positions : Hash(String, String)
    {
      "starting"   => STARTING_FEN,
      "kiwipete"   => "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
      "position3"  => "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1",
      "position4"  => "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
      "position5"  => "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8",
      "position6"  => "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10"
    }
  end

  # Validate FEN string format
  def self.valid?(fen : String) : Bool
    parse(fen) != nil
  end
end