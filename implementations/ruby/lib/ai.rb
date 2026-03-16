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

      legal_moves = order_moves(@move_generator.generate_legal_moves(color))
      return nil if legal_moves.empty?

      best_move = legal_moves.first
      best_score = -Float::INFINITY
      opponent_color = opposite(color)

      legal_moves.each do |move|
        @board.make_move(move)
        score = minimax(depth - 1, -Float::INFINITY, Float::INFINITY, opponent_color, color)
        @board.undo_move(move)

        if score > best_score
          best_score = score
          best_move = move
        end
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

    def minimax(depth, alpha, beta, current_color, perspective_color)
      if @move_generator.in_checkmate?(current_color)
        winner = opposite(current_color)
        return winner == perspective_color ? CHECKMATE_VALUE + depth : -CHECKMATE_VALUE - depth
      end

      return STALEMATE_VALUE if @move_generator.in_stalemate?(current_color)
      return evaluate_position(perspective_color) if depth.zero?

      legal_moves = order_moves(@move_generator.generate_legal_moves(current_color))
      return evaluate_position(perspective_color) if legal_moves.empty?

      if current_color == perspective_color
        max_eval = -Float::INFINITY
        legal_moves.each do |move|
          @board.make_move(move)
          eval_score = minimax(depth - 1, alpha, beta, opposite(current_color), perspective_color)
          @board.undo_move(move)

          max_eval = [max_eval, eval_score].max
          alpha = [alpha, eval_score].max
          break if beta <= alpha
        end
        max_eval
      else
        min_eval = Float::INFINITY
        legal_moves.each do |move|
          @board.make_move(move)
          eval_score = minimax(depth - 1, alpha, beta, opposite(current_color), perspective_color)
          @board.undo_move(move)

          min_eval = [min_eval, eval_score].min
          beta = [beta, eval_score].min
          break if beta <= alpha
        end
        min_eval
      end
    end

    def order_moves(moves)
      moves.sort_by { |move| -move_priority(move) }
    end

    def move_priority(move)
      piece = @board.piece_at(move.from_row, move.from_col)
      target_piece = @board.piece_at(move.to_row, move.to_col)
      target_value = target_piece&.value || 0
      if piece&.type == :pawn && move.from_col != move.to_col && target_piece.nil?
        target_value = PIECE_VALUES[:pawn]
      end

      moving_value = piece&.value || 0
      score = target_value.positive? ? (target_value * 10) - moving_value : 0
      score += PIECE_VALUES[move.promotion] if move.promotion
      score += 50 if piece&.type == :king && (move.to_col - move.from_col).abs == 2
      score += 10 if [3, 4].include?(move.to_row) && [3, 4].include?(move.to_col)
      score
    end

    def evaluate_position(perspective_color)
      evaluate_material(perspective_color) + evaluate_position_bonuses(perspective_color)
    end

    def evaluate_material(perspective_color)
      white_material = 0
      black_material = 0

      (0..7).each do |row|
        (0..7).each do |col|
          piece = @board.piece_at(row, col)
          next unless piece

          if piece.color == :white
            white_material += piece.value
          else
            black_material += piece.value
          end
        end
      end

      material_balance = white_material - black_material
      perspective_color == :white ? material_balance : -material_balance
    end

    def evaluate_position_bonuses(perspective_color)
      bonus = 0

      center_squares = [[3, 3], [3, 4], [4, 3], [4, 4]]
      center_squares.each do |row, col|
        piece = @board.piece_at(row, col)
        next unless piece

        piece_bonus = piece.type == :pawn ? 10 : 10
        bonus += piece.color == perspective_color ? piece_bonus : -piece_bonus
      end

      (0..7).each do |row|
        (0..7).each do |col|
          piece = @board.piece_at(row, col)
          next unless piece&.type == :pawn

          advancement = piece.color == :white ? (6 - row) : (row - 1)
          advancement_bonus = advancement * 5
          bonus += piece.color == perspective_color ? advancement_bonus : -advancement_bonus
        end
      end

      king_pos = @board.find_king(perspective_color)
      if king_pos && king_exposed?(king_pos[0], king_pos[1], perspective_color)
        bonus -= 20
      end

      enemy_color = opposite(perspective_color)
      enemy_king_pos = @board.find_king(enemy_color)
      if enemy_king_pos && king_exposed?(enemy_king_pos[0], enemy_king_pos[1], enemy_color)
        bonus += 20
      end

      bonus
    end

    def king_exposed?(king_row, king_col, king_color)
      friendly_pieces_nearby = 0

      (-1..1).each do |row_offset|
        (-1..1).each do |col_offset|
          next if row_offset.zero? && col_offset.zero?

          check_row = king_row + row_offset
          check_col = king_col + col_offset
          next unless @board.valid_position?(check_row, check_col)

          piece = @board.piece_at(check_row, check_col)
          friendly_pieces_nearby += 1 if piece && piece.color == king_color
        end
      end

      friendly_pieces_nearby < 2
    end

    def opposite(color)
      color == :white ? :black : :white
    end
  end
end
