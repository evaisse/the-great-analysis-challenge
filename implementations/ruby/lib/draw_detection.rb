# frozen_string_literal: true

module Chess
  module DrawDetection
    def self.draw_by_repetition?(board)
      current_hash = board.zobrist_hash
      count = 1
      
      history = board.position_history
      halfmove_clock = board.halfmove_clock
      
      start_idx = [0, history.length - halfmove_clock].max
      
      (history.length - 1).downto(start_idx) do |i|
        if history[i] == current_hash
          count += 1
          return true if count >= 3
        end
      end
      
      false
    end

    def self.draw_by_fifty_moves?(board)
      board.halfmove_clock >= 100
    end

    def self.draw?(board)
      draw_by_repetition?(board) || draw_by_fifty_moves?(board)
    end
  end
end
