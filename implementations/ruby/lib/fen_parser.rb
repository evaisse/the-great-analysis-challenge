# frozen_string_literal: true

require_relative 'types'

module Chess
  class FenParser
    def initialize(board)
      @board = board
    end
    
    def parse(fen_string)
      parts = fen_string.strip.split
      return false unless parts.length >= 4
      
      board_part = parts[0]
      turn_part = parts[1]
      castling_part = parts[2]
      en_passant_part = parts[3]
      halfmove_part = parts[4] || '0'
      fullmove_part = parts[5] || '1'
      
      # Clear the board
      clear_board
      
      # Parse board position
      return false unless parse_board_position(board_part)
      
      # Parse turn
      @board.current_turn = turn_part == 'w' ? :white : :black
      
      # Parse castling rights
      parse_castling_rights(castling_part)
      
      # Parse en passant target
      parse_en_passant_target(en_passant_part)
      
      # Parse move counters
      @board.halfmove_clock = halfmove_part.to_i
      @board.fullmove_number = fullmove_part.to_i
      
      true
    rescue StandardError
      false
    end
    
    def export
      board_part = export_board_position
      turn_part = @board.current_turn == :white ? 'w' : 'b'
      castling_part = export_castling_rights
      en_passant_part = export_en_passant_target
      halfmove_part = @board.halfmove_clock.to_s
      fullmove_part = @board.fullmove_number.to_s
      
      "#{board_part} #{turn_part} #{castling_part} #{en_passant_part} #{halfmove_part} #{fullmove_part}"
    end
    
    private
    
    def clear_board
      (0..7).each do |row|
        (0..7).each do |col|
          @board.set_piece(row, col, nil)
        end
      end
    end
    
    def parse_board_position(board_part)
      ranks = board_part.split('/')
      return false unless ranks.length == 8
      
      ranks.each_with_index do |rank, row|
        col = 0
        rank.each_char do |char|
          if char.match?(/[1-8]/)
            # Empty squares
            col += char.to_i
          else
            # Piece
            piece = char_to_piece(char)
            return false unless piece
            
            @board.set_piece(row, col, piece)
            col += 1
          end
          
          return false if col > 8
        end
        
        return false unless col == 8
      end
      
      true
    end
    
    def char_to_piece(char)
      color = char == char.upcase ? :white : :black
      char_lower = char.downcase
      
      piece_type = case char_lower
                   when 'p' then :pawn
                   when 'n' then :knight
                   when 'b' then :bishop
                   when 'r' then :rook
                   when 'q' then :queen
                   when 'k' then :king
                   else return nil
                   end
      
      Piece.new(piece_type, color)
    end
    
    def parse_castling_rights(castling_part)
      @board.castling_rights = {
        white: { kingside: false, queenside: false },
        black: { kingside: false, queenside: false }
      }
      
      return if castling_part == '-'
      
      castling_part.each_char do |char|
        case char
        when 'K'
          @board.castling_rights[:white][:kingside] = true
        when 'Q'
          @board.castling_rights[:white][:queenside] = true
        when 'k'
          @board.castling_rights[:black][:kingside] = true
        when 'q'
          @board.castling_rights[:black][:queenside] = true
        end
      end
    end
    
    def parse_en_passant_target(en_passant_part)
      @board.en_passant_target = nil
      
      return if en_passant_part == '-'
      return unless en_passant_part.length == 2
      
      col = en_passant_part[0].ord - 'a'.ord
      row = 8 - en_passant_part[1].to_i
      
      @board.en_passant_target = [row, col] if @board.valid_position?(row, col)
    end
    
    def export_board_position
      ranks = []
      
      (0..7).each do |row|
        rank = ''
        empty_count = 0
        
        (0..7).each do |col|
          piece = @board.piece_at(row, col)
          
          if piece
            rank += empty_count.to_s if empty_count > 0
            empty_count = 0
            rank += piece_to_char(piece)
          else
            empty_count += 1
          end
        end
        
        rank += empty_count.to_s if empty_count > 0
        ranks << rank
      end
      
      ranks.join('/')
    end
    
    def piece_to_char(piece)
      char = case piece.type
             when :pawn then 'p'
             when :knight then 'n'
             when :bishop then 'b'
             when :rook then 'r'
             when :queen then 'q'
             when :king then 'k'
             end
      
      piece.color == :white ? char.upcase : char
    end
    
    def export_castling_rights
      castling = ''
      
      castling += 'K' if @board.castling_rights[:white][:kingside]
      castling += 'Q' if @board.castling_rights[:white][:queenside]
      castling += 'k' if @board.castling_rights[:black][:kingside]
      castling += 'q' if @board.castling_rights[:black][:queenside]
      
      castling.empty? ? '-' : castling
    end
    
    def export_en_passant_target
      return '-' unless @board.en_passant_target
      
      row, col = @board.en_passant_target
      file = ('a'.ord + col).chr
      rank = (8 - row).to_s
      "#{file}#{rank}"
    end
  end
end