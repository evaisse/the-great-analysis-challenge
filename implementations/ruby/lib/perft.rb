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
      
      legal_moves.each do |move|
        original_state = save_board_state
        @board.make_move(move)
        
        nodes = depth > 1 ? perft_recursive(depth - 1, color == :white ? :black : :white) : 1
        results[move.to_algebraic] = nodes
        total_nodes += nodes
        
        @board.undo_move(move)
        restore_board_state(original_state)
      end
      
      {
        moves: results,
        total: total_nodes,
        depth: depth
      }
    end
    
    private
    
    def perft_recursive(depth, color)
      return 1 if depth == 0
      
      legal_moves = @move_generator.generate_legal_moves(color)
      return 0 if legal_moves.empty?
      
      node_count = 0
      next_color = color == :white ? :black : :white
      
      legal_moves.each do |move|
        original_state = save_board_state
        @board.make_move(move)
        
        node_count += perft_recursive(depth - 1, next_color)
        
        @board.undo_move(move)
        restore_board_state(original_state)
      end
      
      node_count
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