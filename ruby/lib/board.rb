# frozen_string_literal: true

require_relative 'types'

module Chess
  class Board
    attr_accessor :board, :current_turn, :castling_rights, :en_passant_target, :halfmove_clock, :fullmove_number
    
    def initialize
      @board = Array.new(8) { Array.new(8) }
      @current_turn = :white
      @castling_rights = { white: { kingside: true, queenside: true }, black: { kingside: true, queenside: true } }
      @en_passant_target = nil
      @halfmove_clock = 0
      @fullmove_number = 1
      setup_initial_position
    end
    
    def setup_initial_position
      # Setup pawns
      (0..7).each do |col|
        @board[1][col] = Piece.new(:pawn, :black)
        @board[6][col] = Piece.new(:pawn, :white)
      end
      
      # Setup pieces
      piece_order = %i[rook knight bishop queen king bishop knight rook]
      piece_order.each_with_index do |piece_type, col|
        @board[0][col] = Piece.new(piece_type, :black)
        @board[7][col] = Piece.new(piece_type, :white)
      end
    end
    
    def piece_at(row, col)
      return nil unless valid_position?(row, col)
      
      @board[row][col]
    end
    
    def set_piece(row, col, piece)
      return false unless valid_position?(row, col)
      
      @board[row][col] = piece
      true
    end
    
    def remove_piece(row, col)
      return nil unless valid_position?(row, col)
      
      piece = @board[row][col]
      @board[row][col] = nil
      piece
    end
    
    def valid_position?(row, col)
      row.between?(0, 7) && col.between?(0, 7)
    end
    
    def make_move(move)
      piece = piece_at(move.from_row, move.from_col)
      return false unless piece && piece.color == @current_turn
      
      # Store captured piece
      move.captured_piece = piece_at(move.to_row, move.to_col)
      
      # Handle special moves
      handle_special_moves(move, piece)
      
      # Move the piece
      remove_piece(move.from_row, move.from_col)
      
      # Handle promotion
      if move.promotion && piece.type == :pawn
        set_piece(move.to_row, move.to_col, Piece.new(move.promotion, piece.color))
      else
        set_piece(move.to_row, move.to_col, piece)
      end
      
      # Update game state
      update_game_state(move, piece)
      
      # Switch turns
      @current_turn = @current_turn == :white ? :black : :white
      
      true
    end
    
    def undo_move(move)
      piece = piece_at(move.to_row, move.to_col)
      return false unless piece
      
      # Handle special move undos
      undo_special_moves(move, piece)
      
      # Move piece back
      remove_piece(move.to_row, move.to_col)
      
      # Handle promotion undo
      if move.promotion
        set_piece(move.from_row, move.from_col, Piece.new(:pawn, piece.color))
      else
        set_piece(move.from_row, move.from_col, piece)
      end
      
      # Restore captured piece
      set_piece(move.to_row, move.to_col, move.captured_piece) if move.captured_piece
      
      # Switch turns back
      @current_turn = @current_turn == :white ? :black : :white
      
      true
    end
    
    def in_check?(color)
      king_pos = find_king(color)
      return false unless king_pos
      
      enemy_color = color == :white ? :black : :white
      under_attack?(king_pos[0], king_pos[1], enemy_color)
    end
    
    def under_attack?(row, col, attacking_color)
      (0..7).each do |r|
        (0..7).each do |c|
          piece = piece_at(r, c)
          next unless piece && piece.color == attacking_color
          
          return true if can_piece_attack?(piece, r, c, row, col)
        end
      end
      false
    end
    
    def find_king(color)
      (0..7).each do |row|
        (0..7).each do |col|
          piece = piece_at(row, col)
          return [row, col] if piece && piece.type == :king && piece.color == color
        end
      end
      nil
    end
    
    def display
      result = "  a b c d e f g h\n"
      (0..7).each do |row|
        result += "#{8 - row} "
        (0..7).each do |col|
          piece = piece_at(row, col)
          result += piece ? piece.symbol : '.'
          result += ' '
        end
        result += "#{8 - row}\n"
      end
      result += "  a b c d e f g h\n\n"
      result += "#{@current_turn.to_s.capitalize} to move"
      result
    end
    
    private
    
    def handle_special_moves(move, piece)
      # Handle castling
      if piece.type == :king && (move.to_col - move.from_col).abs == 2
        move.is_castling = true
        handle_castling(move)
      end
      
      # Handle en passant
      if piece.type == :pawn && move.to_col != move.from_col && !piece_at(move.to_row, move.to_col)
        move.is_en_passant = true
        move.en_passant_target = [@en_passant_target[0], @en_passant_target[1]]
        remove_piece(@en_passant_target[0], @en_passant_target[1])
      end
    end
    
    def undo_special_moves(move, piece)
      # Undo castling
      if move.is_castling
        undo_castling(move, piece.color)
      end
      
      # Undo en passant
      if move.is_en_passant && move.en_passant_target
        enemy_color = piece.color == :white ? :black : :white
        set_piece(move.en_passant_target[0], move.en_passant_target[1], Piece.new(:pawn, enemy_color))
      end
    end
    
    def handle_castling(move)
      color = @current_turn
      if move.to_col > move.from_col # Kingside
        rook = remove_piece(move.from_row, 7)
        set_piece(move.from_row, 5, rook)
      else # Queenside
        rook = remove_piece(move.from_row, 0)
        set_piece(move.from_row, 3, rook)
      end
    end
    
    def undo_castling(move, color)
      if move.to_col > move.from_col # Kingside
        rook = remove_piece(move.from_row, 5)
        set_piece(move.from_row, 7, rook)
      else # Queenside
        rook = remove_piece(move.from_row, 3)
        set_piece(move.from_row, 0, rook)
      end
    end
    
    def update_game_state(move, piece)
      # Update castling rights
      update_castling_rights(move, piece)
      
      # Update en passant target
      @en_passant_target = nil
      if piece.type == :pawn && (move.to_row - move.from_row).abs == 2
        en_passant_row = (move.from_row + move.to_row) / 2
        @en_passant_target = [en_passant_row, move.to_col]
      end
      
      # Update move counters
      if piece.type == :pawn || move.captured_piece
        @halfmove_clock = 0
      else
        @halfmove_clock += 1
      end
      
      @fullmove_number += 1 if @current_turn == :black
    end
    
    def update_castling_rights(move, piece)
      return unless piece.type == :king || piece.type == :rook
      
      color = piece.color
      
      if piece.type == :king
        @castling_rights[color][:kingside] = false
        @castling_rights[color][:queenside] = false
      elsif piece.type == :rook
        if move.from_col == 0 # Queenside rook
          @castling_rights[color][:queenside] = false
        elsif move.from_col == 7 # Kingside rook
          @castling_rights[color][:kingside] = false
        end
      end
    end
    
    def can_piece_attack?(piece, from_row, from_col, to_row, to_col)
      case piece.type
      when :pawn
        can_pawn_attack?(piece.color, from_row, from_col, to_row, to_col)
      when :knight
        can_knight_attack?(from_row, from_col, to_row, to_col)
      when :bishop
        can_bishop_attack?(from_row, from_col, to_row, to_col)
      when :rook
        can_rook_attack?(from_row, from_col, to_row, to_col)
      when :queen
        can_queen_attack?(from_row, from_col, to_row, to_col)
      when :king
        can_king_attack?(from_row, from_col, to_row, to_col)
      else
        false
      end
    end
    
    def can_pawn_attack?(color, from_row, from_col, to_row, to_col)
      direction = color == :white ? -1 : 1
      to_row == from_row + direction && (to_col - from_col).abs == 1
    end
    
    def can_knight_attack?(from_row, from_col, to_row, to_col)
      row_diff = (to_row - from_row).abs
      col_diff = (to_col - from_col).abs
      (row_diff == 2 && col_diff == 1) || (row_diff == 1 && col_diff == 2)
    end
    
    def can_bishop_attack?(from_row, from_col, to_row, to_col)
      return false unless (to_row - from_row).abs == (to_col - from_col).abs
      
      path_clear?(from_row, from_col, to_row, to_col)
    end
    
    def can_rook_attack?(from_row, from_col, to_row, to_col)
      return false unless from_row == to_row || from_col == to_col
      
      path_clear?(from_row, from_col, to_row, to_col)
    end
    
    def can_queen_attack?(from_row, from_col, to_row, to_col)
      can_rook_attack?(from_row, from_col, to_row, to_col) ||
        can_bishop_attack?(from_row, from_col, to_row, to_col)
    end
    
    def can_king_attack?(from_row, from_col, to_row, to_col)
      (to_row - from_row).abs <= 1 && (to_col - from_col).abs <= 1
    end
    
    def path_clear?(from_row, from_col, to_row, to_col)
      row_step = to_row <=> from_row
      col_step = to_col <=> from_col
      
      current_row = from_row + row_step
      current_col = from_col + col_step
      
      while current_row != to_row || current_col != to_col
        return false if piece_at(current_row, current_col)
        
        current_row += row_step
        current_col += col_step
      end
      
      true
    end
  end
end