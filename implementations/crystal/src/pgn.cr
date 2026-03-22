require "json"
require "./types"
require "./board"
require "./fen"
require "./move_generator"

module PGN
  RESULTS = ["1-0", "0-1", "1/2-1/2", "*"]

  class Error < Exception
  end

  enum TokenKind
    TagOpen
    TagClose
    QuotedString
    Symbol
    MoveNumber
    Result
    Nag
    Comment
    VariationOpen
    VariationClose
    Eof
  end

  struct Token
    getter kind : TokenKind
    getter value : String

    def initialize(@kind : TokenKind, @value : String)
    end
  end

  struct VariationRef
    getter move_index : Int32
    getter variation_index : Int32

    def initialize(@move_index : Int32, @variation_index : Int32)
    end
  end

  class MoveNode
    property san : String
    property move : Move
    property move_number : Int32
    property color : Color
    property nags : Array(String)
    property comments : Array(String)
    property variations : Array(Variation)

    def initialize(@san : String, @move : Move, @move_number : Int32, @color : Color)
      @nags = [] of String
      @comments = [] of String
      @variations = [] of Variation
    end
  end

  class Variation
    property moves : Array(MoveNode)
    property comments : Array(String)

    def initialize
      @moves = [] of MoveNode
      @comments = [] of String
    end
  end

  class Game
    property tags : Hash(String, String)
    property mainline : Variation
    property result : String
    property source_path : String?

    def initialize(@tags : Hash(String, String), @mainline : Variation, @result : String = "*", @source_path : String? = nil)
    end

    def mainline_san_moves : Array(String)
      @mainline.moves.map(&.san)
    end
  end

  class Document
    getter games : Array(Game)

    def initialize(@games : Array(Game))
    end
  end

  private class Tokenizer
    @index = 0

    def initialize(@content : String)
    end

    def tokenize : Array(Token)
      tokens = [] of Token

      while (char = current_char)
        if whitespace?(char)
          advance
          next
        end

        case char
        when '['
          tokens << Token.new(TokenKind::TagOpen, "[")
          advance
        when ']'
          tokens << Token.new(TokenKind::TagClose, "]")
          advance
        when '('
          tokens << Token.new(TokenKind::VariationOpen, "(")
          advance
        when ')'
          tokens << Token.new(TokenKind::VariationClose, ")")
          advance
        when '{'
          tokens << Token.new(TokenKind::Comment, read_block_comment)
        when ';'
          tokens << Token.new(TokenKind::Comment, read_line_comment)
        when '"'
          tokens << Token.new(TokenKind::QuotedString, read_quoted_string)
        when '$'
          tokens << Token.new(TokenKind::Nag, read_nag)
        else
          token = read_symbol
          next if token.empty?
          kind = classify_symbol(token)
          tokens << Token.new(kind, token)
        end
      end

      tokens << Token.new(TokenKind::Eof, "")
      tokens
    end

    private def current_char : Char?
      @content[@index]?
    end

    private def advance
      @index += 1
    end

    private def whitespace?(char : Char) : Bool
      char.whitespace?
    end

    private def read_block_comment : String
      advance
      comment = String.build do |io|
        while (char = current_char)
          break if char == '}'
          io << char
          advance
        end
      end
      if current_char == '}'
        advance
        comment
      else
        raise Error.new("Unterminated PGN block comment")
      end
    end

    private def read_line_comment : String
      advance
      String.build do |io|
        while (char = current_char)
          break if char == '\n' || char == '\r'
          io << char
          advance
        end
      end.strip
    end

    private def read_quoted_string : String
      advance
      value = String.build do |io|
        while (char = current_char)
          break if char == '"'
          if char == '\\'
            advance
            escaped = current_char
            raise Error.new("Unterminated PGN quoted string") unless escaped
            io << escaped
            advance
          else
            io << char
            advance
          end
        end
      end
      if current_char == '"'
        advance
        value
      else
        raise Error.new("Unterminated PGN quoted string")
      end
    end

    private def read_nag : String
      String.build do |io|
        io << '$'
        advance
        while (char = current_char)
          break unless char.number?
          io << char
          advance
        end
      end
    end

    private def read_symbol : String
      String.build do |io|
        while (char = current_char)
          break if whitespace?(char)
          break if "[](){};\"".includes?(char)
          io << char
          advance
        end
      end
    end

    private def classify_symbol(token : String) : TokenKind
      return TokenKind::Result if RESULTS.includes?(token)
      return TokenKind::MoveNumber if token.matches?(/^\d+\.(?:\.\.)?$/)
      TokenKind::Symbol
    end
  end

  private class Parser
    @tokens : Array(Token)
    @index = 0
    @move_generator = MoveGenerator.new

    def initialize(content : String)
      @tokens = Tokenizer.new(content).tokenize
    end

    def parse : Document
      games = [] of Game
      until eof?
        skip_noise
        break if eof?
        games << parse_game
      end
      Document.new(games)
    end

    private def parse_game : Game
      tags = Hash(String, String).new

      while match?(TokenKind::TagOpen)
        advance
        name = consume(TokenKind::Symbol, "PGN tag name").value
        value = consume(TokenKind::QuotedString, "PGN tag value").value
        consume(TokenKind::TagClose, "closing tag bracket")
        tags[name] = value
      end

      initial_state = initial_state_from_tags(tags)
      mainline, result = parse_variation(initial_state, stop_on_close: false)
      Game.new(tags, mainline, result || tags["Result"]? || "*")
    end

    private def initial_state_from_tags(tags : Hash(String, String)) : GameState
      if tags["SetUp"]? == "1"
        fen = tags["FEN"]?
        raise Error.new("PGN SetUp=1 requires a FEN tag") unless fen

        parsed = FEN.parse(fen)
        raise Error.new("Invalid FEN tag in PGN") unless parsed
        return parsed
      end

      FEN.starting_position
    end

    private def parse_variation(initial_state : GameState, stop_on_close : Bool) : {Variation, String?}
      variation = Variation.new
      pending_comments = [] of String
      last_move : MoveNode? = nil
      state = initial_state
      state_before_last_move = initial_state
      result : String? = nil

      loop do
        token = current_token

        case token.kind
        when TokenKind::Comment
          comment = token.value.strip
          if move = last_move
            move.comments << comment
          else
            pending_comments << comment
          end
          advance
        when TokenKind::Nag
          if move = last_move
            move.nags << token.value
          else
            pending_comments << token.value
          end
          advance
        when TokenKind::MoveNumber
          advance
        when TokenKind::VariationOpen
          advance
          base_state = last_move ? state_before_last_move : state
          nested_variation, _nested_result = parse_variation(base_state, stop_on_close: true)
          if move = last_move
            move.variations << nested_variation
          else
            variation.comments.concat(nested_variation.comments)
          end
        when TokenKind::VariationClose
          if stop_on_close
            advance
            break
          end
          raise Error.new("Unexpected variation close in PGN")
        when TokenKind::Result
          result = token.value
          advance
          break unless stop_on_close
        when TokenKind::Symbol
          san, inline_nags = split_inline_nags(token.value)
          move = PGN.san_to_move(state, san, @move_generator)
          raise Error.new("Illegal or unsupported SAN move: #{san}") unless move

          node = MoveNode.new(san, move, state.fullmove_number, state.turn)
          node.nags.concat(inline_nags)
          node.comments.concat(pending_comments)
          pending_comments.clear
          variation.moves << node
          last_move = node
          state_before_last_move = state
          state = Board.make_move(state, move)
          advance
        when TokenKind::TagOpen
          break
        when TokenKind::Eof
          break
        else
          raise Error.new("Unexpected PGN token: #{token.value}")
        end
      end

      if pending_comments.any?
        if move = last_move
          move.comments.concat(pending_comments)
        else
          variation.comments.concat(pending_comments)
        end
      end

      {variation, result}
    end

    private def split_inline_nags(token : String) : {String, Array(String)}
      if match = token.match(/^(.*?)(\?\!|\!\?|\!\!|\?\?|\!|\?)$/)
        {match[1], [match[2]]}
      else
        {token, [] of String}
      end
    end

    private def skip_noise
      while match?(TokenKind::Comment) || match?(TokenKind::Result)
        advance
      end
    end

    private def current_token : Token
      @tokens[@index]
    end

    private def advance : Token
      token = @tokens[@index]
      @index += 1 unless eof?
      token
    end

    private def consume(kind : TokenKind, label : String) : Token
      token = current_token
      return advance if token.kind == kind
      actual = token.value.empty? ? token.kind.to_s : token.value
      raise Error.new("Expected #{label}, got #{actual}")
    end

    private def match?(kind : TokenKind) : Bool
      current_token.kind == kind
    end

    private def eof? : Bool
      current_token.kind == TokenKind::Eof
    end
  end

  private class Serializer
    def serialize(game : Game) : String
      String.build do |io|
        write_tags(io, game.tags)
        if game.tags.any?
          io << "\n"
        end
        write_variation(io, game.mainline)
        io << ' '
        io << game.result
      end.strip
    end

    private def write_tags(io : IO, tags : Hash(String, String))
      tags.each do |name, value|
        io << '[' << name << " \"" << escape_tag_value(value) << "\"]\n"
      end
    end

    private def write_variation(io : IO, variation : Variation)
      first = true
      variation.comments.each do |comment|
        unless first
          io << ' '
        end
        io << '{' << sanitize_comment(comment) << '}'
        first = false
      end

      variation.moves.each do |move|
        unless first
          io << ' '
        end
        io << move.move_number
        io << (move.color.white? ? "." : "...")
        io << ' '
        io << move.san
        move.nags.each do |nag|
          io << ' ' << nag
        end
        move.comments.each do |comment|
          io << ' ' << '{' << sanitize_comment(comment) << '}'
        end
        move.variations.each do |nested|
          io << " ("
          write_variation(io, nested)
          io << ')'
        end
        first = false
      end
    end

    private def escape_tag_value(value : String) : String
      value.gsub('\\', "\\\\").gsub('"', "\\\"")
    end

    private def sanitize_comment(comment : String) : String
      comment.gsub('}', ']')
    end
  end

  def self.parse(content : String) : Document
    Parser.new(content).parse
  end

  def self.parse_game(content : String) : Game
    document = parse(content)
    game = document.games.first?
    raise Error.new("No PGN game found") unless game
    game
  end

  def self.extract_moves(content : String) : Array(String)
    parse_game(content).mainline_san_moves
  end

  def self.serialize(game : Game) : String
    Serializer.new.serialize(game)
  end

  def self.build_live_game(initial_state : GameState, moves : Array(Move), existing : Game? = nil) : Game
    state = initial_state
    tags = existing ? existing.not_nil!.tags.dup : Hash(String, String).new
    variation = Variation.new

    moves.each do |move|
      san = move_to_san(state, move)
      node = MoveNode.new(san, move, state.fullmove_number, state.turn)
      variation.moves << node
      state = Board.make_move(state, move)
    end

    result = existing.try(&.result) || "*"
    game = Game.new(tags, variation, result, existing.try(&.source_path))

    if tags.empty?
      game.tags["Event"] = "?"
      game.tags["Site"] = "?"
      game.tags["Date"] = "????.??.??"
      game.tags["Round"] = "?"
      game.tags["White"] = "White"
      game.tags["Black"] = "Black"
      game.tags["Result"] = result
      initial_fen = FEN.export(initial_state)
      if initial_fen != FEN.export(FEN.starting_position)
        game.tags["SetUp"] = "1"
        game.tags["FEN"] = initial_fen
      end
    else
      game.tags["Result"] = result
    end

    game
  end

  def self.find_variation(game : Game, path : Array(VariationRef)) : Variation
    current = game.mainline
    path.each do |ref|
      move = current.moves[ref.move_index]?
      raise Error.new("Variation path is out of range") unless move
      nested = move.variations[ref.variation_index]?
      raise Error.new("Variation path is out of range") unless nested
      current = nested
    end
    current
  end

  def self.san_to_move(game_state : GameState, san : String, move_generator = MoveGenerator.new) : Move?
    cleaned = san.strip
    return nil if cleaned.empty?

    cleaned = cleaned.gsub(/[\+\#]+$/, "")
    cleaned = cleaned.gsub(/(\?\!|\!\?|\!\!|\?\?|\!|\?)$/, "")

    legal_moves = move_generator.get_legal_moves(game_state, game_state.turn)

    if cleaned == "O-O" || cleaned == "0-0"
      return legal_moves.find { |move| move.is_castling && (move.to % 8) == 6 }
    end

    if cleaned == "O-O-O" || cleaned == "0-0-0"
      return legal_moves.find { |move| move.is_castling && (move.to % 8) == 2 }
    end

    promotion : PieceType? = nil
    if promotion_index = cleaned.index('=')
      promotion_char = cleaned[promotion_index + 1]?
      return nil unless promotion_char
      promotion = PieceType.from_char(promotion_char)
      cleaned = cleaned[0, promotion_index]
    end

    piece_type = PieceType::Pawn
    start_index = 0
    if first = cleaned[0]?
      if first.ascii_uppercase? && (resolved_piece = PieceType.from_char(first))
        unless resolved_piece.pawn?
          piece_type = resolved_piece
          start_index = 1
        end
      end
    end

    capture = cleaned.includes?('x')
    destination_text = cleaned[-2, 2]?
    return nil unless destination_text
    destination = algebraic_to_square(destination_text)
    return nil unless destination

    body_length = cleaned.size - 2 - start_index
    return nil if body_length < 0
    body = body_length.zero? ? "" : cleaned[start_index, body_length]
    disambiguation = body.gsub('x', "")

    legal_moves.select do |move|
      next false unless move.piece == piece_type
      next false unless move.to == destination
      next false unless move.promotion == promotion
      next false if capture && move.captured.nil? && !move.is_en_passant
      next false if !capture && (!move.captured.nil? || move.is_en_passant)
      matches_disambiguation?(move, disambiguation)
    end.first?
  end

  def self.move_to_san(game_state : GameState, move : Move, move_generator = MoveGenerator.new) : String
    return move.to % 8 == 6 ? "O-O" : "O-O-O" if move.is_castling

    piece = game_state.board[move.from]
    raise Error.new("Cannot render SAN for a move without a source piece") unless piece

    target_square = square_to_algebraic(move.to)
    capture = !move.captured.nil? || move.is_en_passant
    san = String.build do |io|
      unless piece.type.pawn?
        io << piece.type.symbol
        io << disambiguation_for_move(game_state, move, move_generator)
      end

      if piece.type.pawn? && capture
        io << square_to_algebraic(move.from)[0]
      end

      io << 'x' if capture
      io << target_square

      if promotion = move.promotion
        io << '=' << promotion.symbol
      end
    end

    new_state = Board.make_move(game_state, move)
    if move_generator.checkmate?(new_state, new_state.turn)
      san + "#"
    elsif move_generator.in_check?(new_state, new_state.turn)
      san + "+"
    else
      san
    end
  end

  private def self.matches_disambiguation?(move : Move, disambiguation : String) : Bool
    return true if disambiguation.empty?
    from = square_to_algebraic(move.from)
    case disambiguation.size
    when 1
      from[0] == disambiguation[0] || from[1] == disambiguation[0]
    when 2
      from == disambiguation
    else
      false
    end
  end

  private def self.disambiguation_for_move(game_state : GameState, move : Move, move_generator : MoveGenerator) : String
    conflicts = move_generator.get_legal_moves(game_state, game_state.turn).select do |candidate|
      candidate != move && candidate.piece == move.piece && candidate.to == move.to
    end
    return "" if conflicts.empty?

    from = square_to_algebraic(move.from)
    same_file = conflicts.any? { |candidate| square_to_algebraic(candidate.from)[0] == from[0] }
    same_rank = conflicts.any? { |candidate| square_to_algebraic(candidate.from)[1] == from[1] }

    return from if same_file && same_rank
    return from[1].to_s if same_file
    from[0].to_s
  end
end
