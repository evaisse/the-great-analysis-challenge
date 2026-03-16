# frozen_string_literal: true

require_relative 'types'

module Chess
  class Perft
    def initialize(board, move_generator)
      @board = board
      @move_generator = move_generator
    end

    def calculate(depth, color = nil)
      color ||= @board.current_turn
      start_time = Time.now

      node_count = perft_recursive(depth, color)

      end_time = Time.now
      time_ms = ((end_time - start_time) * 1000).round

      {
        nodes: node_count,
        depth: depth,
        time_ms: time_ms
      }
    end

    def perft_divide(depth, color = nil)
      color ||= @board.current_turn
      legal_moves = @move_generator.generate_legal_moves(color)

      results = {}
      total_nodes = 0
      next_color = color == :white ? :black : :white

      legal_moves.each do |move|
        @board.make_move(move)
        nodes = depth > 1 ? perft_recursive(depth - 1, next_color) : 1
        results[move.to_algebraic] = nodes
        total_nodes += nodes
        @board.undo_move(move)
      end

      {
        moves: results,
        total: total_nodes,
        depth: depth
      }
    end

    private

    def perft_recursive(depth, color)
      return 1 if depth.zero?

      legal_moves = @move_generator.generate_legal_moves(color)
      return 0 if legal_moves.empty?

      node_count = 0
      next_color = color == :white ? :black : :white

      legal_moves.each do |move|
        @board.make_move(move)
        node_count += perft_recursive(depth - 1, next_color)
        @board.undo_move(move)
      end

      node_count
    end
  end
end
