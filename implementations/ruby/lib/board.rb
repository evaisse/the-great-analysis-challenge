# frozen_string_literal: true

require_relative 'types'

module Chess
  class Board
    attr_accessor :board, :current_turn, :castling_rights, :en_passant_target, :halfmove_clock, :fullmove_number,
                  :zobrist_hash, :position_history, :irreversible_history
    
    def initialize
      @board = Array.new(8) { Array.new(8) }
      @current_turn = :white
      @castling_rights = CastlingRights.new
      @en_passant_target = nil
      @halfmove_clock = 0
      @fullmove_number = 1
      @position_history = []
      @irreversible_history = []
      setup_initial_position
      require_relative 'zobrist'
      @zobrist_hash = ZOBRIST.compute_hash(self)
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
      
      # Save irreversible state
      @irreversible_history.push(IrreversibleState.new(
        @castling_rights.copy,
        @en_passant_target ? @en_passant_target.dup : nil,
        @halfmove_clock,
        @zobrist_hash
      ))
      @position_history.push(@zobrist_hash)

      hash = @zobrist_hash
      
      # 1. Remove piece from source
      hash ^= ZOBRIST.pieces[ZOBRIST.piece_index(piece)][(7 - move.from_row) * 8 + move.from_col]

      # Store captured piece
      target_piece = piece_at(move.to_row, move.to_col)
      move.captured_piece = target_piece
      
      # 2. Handle capture
      if target_piece
        hash ^= ZOBRIST.pieces[ZOBRIST.piece_index(target_piece)][(7 - move.to_row) * 8 + move.to_col]
      end

      # Handle special moves
      if piece.type == :king && (move.to_col - move.from_col).abs == 2
        move.is_castling = true
        if move.to_col > move.from_col # Kingside
          rook = piece_at(move.from_row, 7)
          hash ^= ZOBRIST.pieces[ZOBRIST.piece_index(rook)][(7 - move.from_row) * 8 + 7]
          hash ^= ZOBRIST.pieces[ZOBRIST.piece_index(rook)][(7 - move.from_row) * 8 + 5]
          set_piece(move.from_row, 5, remove_piece(move.from_row, 7))
        else # Queenside
          rook = piece_at(move.from_row, 0)
          hash ^= ZOBRIST.pieces[ZOBRIST.piece_index(rook)][(7 - move.from_row) * 8 + 0]
          hash ^= ZOBRIST.pieces[ZOBRIST.piece_index(rook)][(7 - move.from_row) * 8 + 3]
          set_piece(move.from_row, 3, remove_piece(move.from_row, 0))
        end
      elsif piece.type == :pawn && move.to_col != move.from_col && !target_piece
        move.is_en_passant = true
        move.en_passant_target = @en_passant_target.dup
        captured_pawn_row = move.from_row
        captured_pawn = piece_at(captured_pawn_row, move.to_col)
        hash ^= ZOBRIST.pieces[ZOBRIST.piece_index(captured_pawn)][(7 - captured_pawn_row) * 8 + move.to_col]
        remove_piece(captured_pawn_row, move.to_col)
        move.captured_piece = captured_pawn
      end
      
      # Move the piece
      remove_piece(move.from_row, move.from_col)
      
      # 3. Handle promotion
      final_piece = piece
      if move.promotion && piece.type == :pawn
        final_piece = Piece.new(move.promotion, piece.color)
      end
      hash ^= ZOBRIST.pieces[ZOBRIST.piece_index(final_piece)][(7 - move.to_row) * 8 + move.to_col]
      set_piece(move.to_row, move.to_col, final_piece)
      
      # 4. Update castling rights in hash
      hash ^= ZOBRIST.castling[0] if @castling_rights.white_kingside
      hash ^= ZOBRIST.castling[1] if @castling_rights.white_queenside
      hash ^= ZOBRIST.castling[2] if @castling_rights.black_kingside
      hash ^= ZOBRIST.castling[3] if @castling_rights.black_queenside

      update_castling_rights(move, piece)

      hash ^= ZOBRIST.castling[0] if @castling_rights.white_kingside
      hash ^= ZOBRIST.castling[1] if @castling_rights.white_queenside
      hash ^= ZOBRIST.castling[2] if @castling_rights.black_kingside
      hash ^= ZOBRIST.castling[3] if @castling_rights.black_queenside

      # 5. Update en passant target in hash
      hash ^= ZOBRIST.en_passant[@en_passant_target[1]] if @en_passant_target
      
      @en_passant_target = nil
      if piece.type == :pawn && (move.to_row - move.from_row).abs == 2
        en_passant_row = (move.from_row + move.to_row) / 2
        @en_passant_target = [en_passant_row, move.to_col]
        hash ^= ZOBRIST.en_passant[@en_passant_target[1]]
      end
      
      # 6. Update side to move
      hash ^= ZOBRIST.side_to_move
      
      # Update counters
      if piece.type == :pawn || move.captured_piece
        @halfmove_clock = 0
      else
        @halfmove_clock += 1
      end
      @fullmove_number += 1 if @current_turn == :black
      
      @current_turn = @current_turn == :white ? :black : :white
      @zobrist_hash = hash
      true
    end
    
    def undo_move(move)
      return false if @irreversible_history.empty?
      
      # Restore irreversible state
      old_state = @irreversible_history.pop
      @position_history.pop
      @castling_rights = old_state.castling_rights
      @en_passant_target = old_state.en_passant_target
      @halfmove_clock = old_state.halfmove_clock
      @zobrist_hash = old_state.zobrist_hash
      
      # Switch turns back
      @current_turn = @current_turn == :white ? :black : :white
      @fullmove_number -= 1 if @current_turn == :black
      
      # Get the piece that was moved
      moved_piece = piece_at(move.to_row, move.to_col)
      
      # Handle special move undos
      if move.is_castling
        if move.to_col > move.from_col # Kingside
          rook = remove_piece(move.from_row, 5)
          set_piece(move.from_row, 7, rook)
        else # Queenside
          rook = remove_piece(move.from_row, 3)
          set_piece(move.from_row, 0, rook)
        end
      elsif move.is_en_passant && move.en_passant_target
        captured_pawn_color = @current_turn == :white ? :black : :white
        set_piece(move.from_row, move.to_col, Piece.new(:pawn, captured_pawn_color))
      end
      
      # Move piece back
      remove_piece(move.to_row, move.to_col)
      
      # Handle promotion undo
      if move.promotion
        set_piece(move.from_row, move.from_col, Piece.new(:pawn, moved_piece.color))
      else
        set_piece(move.from_row, move.from_col, moved_piece)
      end
      
      # Restore captured piece
      if move.captured_piece && !move.is_en_passant
        set_piece(move.to_row, move.to_col, move.captured_piece)
      end
      
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
    
    def update_castling_rights(move, piece)
      return unless piece
      
      if piece.type == :king
        @castling_rights.white_kingside = false if piece.color == :white
        @castling_rights.white_queenside = false if piece.color == :white
        @castling_rights.black_kingside = false if piece.color == :black
        @castling_rights.black_queenside = false if piece.color == :black
      end
      
      # If a rook moves or is captured
      if move.from_row == 7 && move.from_col == 0 || move.to_row == 7 && move.to_col == 0
        @castling_rights.white_queenside = false
      end
      if move.from_row == 7 && move.from_col == 7 || move.to_row == 7 && move.to_col == 7
        @castling_rights.white_kingside = false
      end
      if move.from_row == 0 && move.from_col == 0 || move.to_row == 0 && move.to_col == 0
        @castling_rights.black_queenside = false
      end
      if move.from_row == 0 && move.from_col == 7 || move.to_row == 0 && move.to_col == 7
        @castling_rights.black_kingside = false
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