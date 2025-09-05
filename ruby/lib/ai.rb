# frozen_string_literal: true

require_relative 'types'

module Chess
  class AI
    CHECKMATE_VALUE = 100_000
    STALEMATE_VALUE = 0
    
    def initialize(board, move_generator)
      @board = board
      @move_generator = move_generator
    end
    
    def find_best_move(depth, color = nil)
      color ||= @board.current_turn
      start_time = Time.now
      
      legal_moves = @move_generator.generate_legal_moves(color)
      return nil if legal_moves.empty?
      
      best_move = legal_moves.first
      best_score = -Float::INFINITY
      
      legal_moves.each do |move|
        original_state = save_board_state
        @board.make_move(move)
        
        score = -minimax(depth - 1, -Float::INFINITY, Float::INFINITY, false, color == :white ? :black : :white)
        
        if score > best_score
          best_score = score
          best_move = move
        end
        
        @board.undo_move(move)
        restore_board_state(original_state)
      end
      
      end_time = Time.now
      time_ms = ((end_time - start_time) * 1000).round
      
      {
        move: best_move,
        score: best_score,
        depth: depth,
        time_ms: time_ms
      }
    end
    
    private
    
    def minimax(depth, alpha, beta, maximizing_player, color)
      # Check for game end conditions
      if @move_generator.in_checkmate?(color)
        return maximizing_player ? -CHECKMATE_VALUE : CHECKMATE_VALUE
      end
      
      if @move_generator.in_stalemate?(color)
        return STALEMATE_VALUE
      end
      
      # If we've reached the maximum depth, evaluate the position
      return evaluate_position(color) if depth == 0
      
      legal_moves = @move_generator.generate_legal_moves(color)
      
      if maximizing_player
        max_eval = -Float::INFINITY
        
        legal_moves.each do |move|
          original_state = save_board_state
          @board.make_move(move)
          
          eval_score = minimax(depth - 1, alpha, beta, false, color == :white ? :black : :white)
          max_eval = [max_eval, eval_score].max
          alpha = [alpha, eval_score].max
          
          @board.undo_move(move)
          restore_board_state(original_state)
          
          break if beta <= alpha # Alpha-beta pruning
        end
        
        max_eval
      else
        min_eval = Float::INFINITY
        
        legal_moves.each do |move|
          original_state = save_board_state
          @board.make_move(move)
          
          eval_score = minimax(depth - 1, alpha, beta, true, color == :white ? :black : :white)
          min_eval = [min_eval, eval_score].min
          beta = [beta, eval_score].min
          
          @board.undo_move(move)
          restore_board_state(original_state)
          
          break if beta <= alpha # Alpha-beta pruning
        end
        
        min_eval
      end
    end
    
    def evaluate_position(perspective_color)
      score = 0
      
      # Material evaluation
      score += evaluate_material(perspective_color)
      
      # Positional evaluation
      score += evaluate_position_bonuses(perspective_color)
      
      score
    end
    
    def evaluate_material(perspective_color)
      white_material = 0
      black_material = 0
      
      (0..7).each do |row|
        (0..7).each do |col|
          piece = @board.piece_at(row, col)
          next unless piece
          
          value = piece.value
          
          if piece.color == :white
            white_material += value
          else
            black_material += value
          end
        end
      end
      
      material_balance = white_material - black_material
      perspective_color == :white ? material_balance : -material_balance
    end
    
    def evaluate_position_bonuses(perspective_color)
      bonus = 0
      
      # Center control bonus
      center_squares = [[3, 3], [3, 4], [4, 3], [4, 4]]
      center_squares.each do |row, col|
        piece = @board.piece_at(row, col)
        next unless piece
        
        piece_bonus = piece.type == :pawn ? 10 : 10
        if piece.color == perspective_color
          bonus += piece_bonus
        else
          bonus -= piece_bonus
        end
      end
      
      # Pawn advancement bonus
      (0..7).each do |row|
        (0..7).each do |col|
          piece = @board.piece_at(row, col)
          next unless piece && piece.type == :pawn
          advancement = piece.color == :white ? (6 - row) : (row - 1)
          advancement_bonus = advancement * 5
          
          if piece.color == perspective_color
            bonus += advancement_bonus
          else
            bonus -= advancement_bonus
          end
        end
      end
      
      # King safety (basic)
      king_pos = @board.find_king(perspective_color)
      if king_pos
        king_row, king_col = king_pos
        
        # Penalty for exposed king (simple heuristic)
        if king_exposed?(king_row, king_col, perspective_color)
          bonus -= 20
        end
      end
      
      enemy_king_pos = @board.find_king(perspective_color == :white ? :black : :white)
      if enemy_king_pos
        enemy_king_row, enemy_king_col = enemy_king_pos
        
        # Bonus for attacking enemy king
        if king_exposed?(enemy_king_row, enemy_king_col, perspective_color == :white ? :black : :white)
          bonus += 20
        end
      end
      
      bonus
    end
    
    def king_exposed?(king_row, king_col, king_color)
      # Simple check: see if there are friendly pieces around the king
      friendly_pieces_nearby = 0
      
      (-1..1).each do |row_offset|
        (-1..1).each do |col_offset|
          next if row_offset == 0 && col_offset == 0
          
          check_row = king_row + row_offset
          check_col = king_col + col_offset
          
          next unless @board.valid_position?(check_row, check_col)
          
          piece = @board.piece_at(check_row, check_col)
          friendly_pieces_nearby += 1 if piece && piece.color == king_color
        end
      end
      
      friendly_pieces_nearby < 2
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