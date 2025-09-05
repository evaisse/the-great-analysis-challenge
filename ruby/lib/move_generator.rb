# frozen_string_literal: true

require_relative 'types'

module Chess
  class MoveGenerator
    def initialize(board)
      @board = board
    end
    
    def generate_legal_moves(color = nil)
      color ||= @board.current_turn
      pseudo_legal_moves = generate_pseudo_legal_moves(color)
      
      legal_moves = []
      pseudo_legal_moves.each do |move|
        if legal_move?(move)
          legal_moves << move
        end
      end
      
      legal_moves
    end
    
    def legal_move?(move)
      # Make the move temporarily
      original_state = save_board_state
      return false unless @board.make_move(move)
      
      # Check if the king is in check after the move
      enemy_color = @board.current_turn # Current turn switched after move
      king_color = enemy_color == :white ? :black : :white
      legal = !@board.in_check?(king_color)
      
      # Undo the move
      @board.undo_move(move)
      restore_board_state(original_state)
      
      legal
    end
    
    def in_checkmate?(color)
      return false unless @board.in_check?(color)
      
      generate_legal_moves(color).empty?
    end
    
    def in_stalemate?(color)
      return false if @board.in_check?(color)
      
      generate_legal_moves(color).empty?
    end
    
    private
    
    def generate_pseudo_legal_moves(color)
      moves = []
      
      (0..7).each do |row|
        (0..7).each do |col|
          piece = @board.piece_at(row, col)
          next unless piece && piece.color == color
          
          moves.concat(generate_piece_moves(piece, row, col))
        end
      end
      
      # Add castling moves
      moves.concat(generate_castling_moves(color))
      
      moves
    end
    
    def generate_piece_moves(piece, row, col)
      case piece.type
      when :pawn
        generate_pawn_moves(piece.color, row, col)
      when :knight
        generate_knight_moves(row, col)
      when :bishop
        generate_bishop_moves(row, col)
      when :rook
        generate_rook_moves(row, col)
      when :queen
        generate_queen_moves(row, col)
      when :king
        generate_king_moves(row, col)
      else
        []
      end
    end
    
    def generate_pawn_moves(color, row, col)
      moves = []
      direction = color == :white ? -1 : 1
      start_row = color == :white ? 6 : 1
      promotion_row = color == :white ? 0 : 7
      
      # Forward move
      new_row = row + direction
      if @board.valid_position?(new_row, col) && !@board.piece_at(new_row, col)
        if new_row == promotion_row
          # Promotion
          %i[queen rook bishop knight].each do |promotion_piece|
            moves << Move.new(row, col, new_row, col, promotion_piece)
          end
        else
          moves << Move.new(row, col, new_row, col)
        end
        
        # Double forward from starting position
        if row == start_row
          new_row2 = row + (2 * direction)
          if @board.valid_position?(new_row2, col) && !@board.piece_at(new_row2, col)
            moves << Move.new(row, col, new_row2, col)
          end
        end
      end
      
      # Captures
      [-1, 1].each do |col_offset|
        new_col = col + col_offset
        next unless @board.valid_position?(new_row, new_col)
        
        target_piece = @board.piece_at(new_row, new_col)
        
        # Regular capture
        if target_piece && target_piece.color != color
          if new_row == promotion_row
            # Capture with promotion
            %i[queen rook bishop knight].each do |promotion_piece|
              moves << Move.new(row, col, new_row, new_col, promotion_piece)
            end
          else
            moves << Move.new(row, col, new_row, new_col)
          end
        end
        
        # En passant capture
        if @board.en_passant_target && 
           @board.en_passant_target[0] == new_row && 
           @board.en_passant_target[1] == new_col
          moves << Move.new(row, col, new_row, new_col)
        end
      end
      
      moves
    end
    
    def generate_knight_moves(row, col)
      moves = []
      knight_moves = [
        [-2, -1], [-2, 1], [-1, -2], [-1, 2],
        [1, -2], [1, 2], [2, -1], [2, 1]
      ]
      
      knight_moves.each do |row_offset, col_offset|
        new_row = row + row_offset
        new_col = col + col_offset
        
        next unless @board.valid_position?(new_row, new_col)
        
        target_piece = @board.piece_at(new_row, new_col)
        piece = @board.piece_at(row, col)
        
        if !target_piece || target_piece.color != piece.color
          moves << Move.new(row, col, new_row, new_col)
        end
      end
      
      moves
    end
    
    def generate_bishop_moves(row, col)
      generate_sliding_moves(row, col, [[-1, -1], [-1, 1], [1, -1], [1, 1]])
    end
    
    def generate_rook_moves(row, col)
      generate_sliding_moves(row, col, [[-1, 0], [1, 0], [0, -1], [0, 1]])
    end
    
    def generate_queen_moves(row, col)
      generate_sliding_moves(row, col, [
        [-1, -1], [-1, 0], [-1, 1],
        [0, -1],           [0, 1],
        [1, -1],  [1, 0],  [1, 1]
      ])
    end
    
    def generate_king_moves(row, col)
      moves = []
      king_moves = [
        [-1, -1], [-1, 0], [-1, 1],
        [0, -1],           [0, 1],
        [1, -1],  [1, 0],  [1, 1]
      ]
      
      king_moves.each do |row_offset, col_offset|
        new_row = row + row_offset
        new_col = col + col_offset
        
        next unless @board.valid_position?(new_row, new_col)
        
        target_piece = @board.piece_at(new_row, new_col)
        piece = @board.piece_at(row, col)
        
        if !target_piece || target_piece.color != piece.color
          moves << Move.new(row, col, new_row, new_col)
        end
      end
      
      moves
    end
    
    def generate_sliding_moves(row, col, directions)
      moves = []
      piece = @board.piece_at(row, col)
      
      directions.each do |row_offset, col_offset|
        new_row = row + row_offset
        new_col = col + col_offset
        
        while @board.valid_position?(new_row, new_col)
          target_piece = @board.piece_at(new_row, new_col)
          
          if target_piece
            # Capture enemy piece
            if target_piece.color != piece.color
              moves << Move.new(row, col, new_row, new_col)
            end
            break # Can't move further
          else
            # Empty square
            moves << Move.new(row, col, new_row, new_col)
          end
          
          new_row += row_offset
          new_col += col_offset
        end
      end
      
      moves
    end
    
    def generate_castling_moves(color)
      moves = []
      return moves if @board.in_check?(color)
      
      king_row = color == :white ? 7 : 0
      
      # Kingside castling
      if @board.castling_rights[color][:kingside]
        if can_castle_kingside?(color, king_row)
          moves << Move.new(king_row, 4, king_row, 6)
        end
      end
      
      # Queenside castling
      if @board.castling_rights[color][:queenside]
        if can_castle_queenside?(color, king_row)
          moves << Move.new(king_row, 4, king_row, 2)
        end
      end
      
      moves
    end
    
    def can_castle_kingside?(color, king_row)
      # Check if squares between king and rook are empty
      return false if @board.piece_at(king_row, 5) || @board.piece_at(king_row, 6)
      
      # Check if king passes through check
      enemy_color = color == :white ? :black : :white
      !@board.under_attack?(king_row, 5, enemy_color) && 
        !@board.under_attack?(king_row, 6, enemy_color)
    end
    
    def can_castle_queenside?(color, king_row)
      # Check if squares between king and rook are empty
      return false if @board.piece_at(king_row, 3) || 
                      @board.piece_at(king_row, 2) || 
                      @board.piece_at(king_row, 1)
      
      # Check if king passes through check
      enemy_color = color == :white ? :black : :white
      !@board.under_attack?(king_row, 3, enemy_color) && 
        !@board.under_attack?(king_row, 2, enemy_color)
    end
    
    def save_board_state
      {
        current_turn: @board.current_turn,
        castling_rights: Marshal.load(Marshal.dump(@board.castling_rights)),
        en_passant_target: @board.en_passant_target&.dup,
        halfmove_clock: @board.halfmove_clock,
        fullmove_number: @board.fullmove_number
      }
    end
    
    def restore_board_state(state)
      @board.current_turn = state[:current_turn]
      @board.castling_rights = state[:castling_rights]
      @board.en_passant_target = state[:en_passant_target]
      @board.halfmove_clock = state[:halfmove_clock]
      @board.fullmove_number = state[:fullmove_number]
    end
  end
end