# frozen_string_literal: true

module Chess
  # Piece types
  PIECE_TYPES = %i[pawn knight bishop rook queen king].freeze
  
  # Colors
  COLORS = %i[white black].freeze
  
  # Piece symbols for display
  PIECE_SYMBOLS = {
    white: { pawn: 'P', knight: 'N', bishop: 'B', rook: 'R', queen: 'Q', king: 'K' },
    black: { pawn: 'p', knight: 'n', bishop: 'b', rook: 'r', queen: 'q', king: 'k' }
  }.freeze
  
  # Piece values for evaluation
  PIECE_VALUES = {
    pawn: 100,
    knight: 320,
    bishop: 330,
    rook: 500,
    queen: 900,
    king: 20_000
  }.freeze
  
  # Move represents a chess move
  class Move
    attr_accessor :from_row, :from_col, :to_row, :to_col, :promotion, :captured_piece,
                  :is_castling, :is_en_passant, :en_passant_target
    
    def initialize(from_row, from_col, to_row, to_col, promotion = nil)
      @from_row = from_row
      @from_col = from_col
      @to_row = to_row
      @to_col = to_col
      @promotion = promotion
      @captured_piece = nil
      @is_castling = false
      @is_en_passant = false
      @en_passant_target = nil
    end
    
    def to_algebraic
      from_square = "#{('a'.ord + @from_col).chr}#{8 - @from_row}"
      to_square = "#{('a'.ord + @to_col).chr}#{8 - @to_row}"
      promotion_part = @promotion ? @promotion.to_s.upcase : ''
      "#{from_square}#{to_square}#{promotion_part}"
    end
    
    def self.from_algebraic(move_str)
      return nil if move_str.length < 4
      
      from_col = move_str[0].ord - 'a'.ord
      from_row = 8 - move_str[1].to_i
      to_col = move_str[2].ord - 'a'.ord
      to_row = 8 - move_str[3].to_i
      
      promotion = nil
      if move_str.length > 4
        promotion_char = move_str[4].downcase
        promotion = case promotion_char
                   when 'q' then :queen
                   when 'r' then :rook
                   when 'b' then :bishop
                   when 'n' then :knight
                   end
      end
      
      new(from_row, from_col, to_row, to_col, promotion)
    end
  end
  
  # Piece represents a chess piece
  class Piece
    attr_accessor :type, :color
    
    def initialize(type, color)
      @type = type
      @color = color
    end
    
    def symbol
      PIECE_SYMBOLS[@color][@type]
    end
    
    def value
      PIECE_VALUES[@type]
    end
    
    def enemy_color
      @color == :white ? :black : :white
    end
  end
end