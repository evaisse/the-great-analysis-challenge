#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'lib/types'
require_relative 'lib/board'
require_relative 'lib/move_generator'
require_relative 'lib/fen_parser'
require_relative 'lib/ai'
require_relative 'lib/perft'

module Chess
  class ChessEngine
    def initialize
      @board = Board.new
      @move_generator = MoveGenerator.new(@board)
      @fen_parser = FenParser.new(@board)
      @ai = AI.new(@board, @move_generator)
      @perft = Perft.new(@board, @move_generator)
      @move_history = []
    end
    
    def start
      puts @board.display
      flush_output
      
      loop do
        print "\n> " if $stdin.tty?
        flush_output
        input = gets&.strip
        break if input.nil? || input.empty?
        
        process_command(input)
      end
    end
    
    private
    
    def flush_output
      $stdout.flush
    end
    
    def process_command(command)
      parts = command.split
      cmd = parts[0]&.downcase
      
      case cmd
      when 'move'
        handle_move(parts[1])
      when 'undo'
        handle_undo
      when 'new'
        handle_new_game
      when 'ai'
        handle_ai_move(parts[1]&.to_i || 3)
      when 'fen'
        handle_fen(parts[1..-1]&.join(' '))
      when 'export'
        handle_export
      when 'eval'
        handle_eval
      when 'hash'
        handle_hash
      when 'draws'
        handle_draws
      when 'history'
        handle_history
      when 'status'
        handle_status
      when 'perft'
        handle_perft(parts[1]&.to_i || 4)
      when 'help'
        handle_help
      when 'quit', 'exit'
        puts 'Goodbye!'
        flush_output
        exit
      else
        puts 'ERROR: Invalid command. Type "help" for available commands.'
        flush_output
      end
    rescue StandardError => e
      puts "ERROR: #{e.message}"
      flush_output
    end
    
    def handle_move(move_str)
      unless move_str
        puts 'ERROR: Invalid move format'
        flush_output
        return
      end
      
      move = Move.from_algebraic(move_str)
      unless move
        puts 'ERROR: Invalid move format'
        flush_output
        return
      end
      
      # Auto-promote to Queen if not specified and moving to promotion rank
      piece = @board.piece_at(move.from_row, move.from_col)
      if piece&.type == :pawn && move.promotion.nil?
        if (piece.color == :white && move.to_row == 0) || (piece.color == :black && move.to_row == 7)
          move.promotion = :queen
        end
      end
      
      # Validate move is legal
      legal_moves = @move_generator.generate_legal_moves
      legal_move = legal_moves.find do |legal|
        legal.from_row == move.from_row &&
          legal.from_col == move.from_col &&
          legal.to_row == move.to_row &&
          legal.to_col == move.to_col &&
          legal.promotion == move.promotion
      end
      
      unless legal_move
        puts 'ERROR: Illegal move'
        flush_output
        return
      end
      
      # Make the move
      @move_history << legal_move
      @board.make_move(legal_move)
      
      puts "OK: #{move_str}"
      puts @board.display
      flush_output
      
      # Check for game end
      check_game_end
    end
    
    def handle_undo
      if @move_history.empty?
        puts 'ERROR: No moves to undo'
        flush_output
        return
      end
      
      last_move = @move_history.pop
      @board.undo_move(last_move)
      
      puts 'OK: Move undone'
      puts @board.display
      flush_output
    end
    
    def handle_new_game
      @board = Board.new
      @move_generator = MoveGenerator.new(@board)
      @fen_parser = FenParser.new(@board)
      @ai = AI.new(@board, @move_generator)
      @perft = Perft.new(@board, @move_generator)
      @move_history.clear
      
      puts 'OK: New game started'
      puts @board.display
      flush_output
    end
    
    def handle_ai_move(depth)
      unless depth.between?(1, 5)
        puts 'ERROR: AI depth must be 1-5'
        flush_output
        return
      end
      
      result = @ai.find_best_move(depth)
      unless result
        puts 'ERROR: No legal moves available'
        flush_output
        return
      end
      
      move = result[:move]
      @move_history << move
      @board.make_move(move)
      
      puts "AI: #{move.to_algebraic} (depth=#{result[:depth]}, eval=#{result[:score]}, time=#{result[:time_ms]}ms)"
      puts @board.display
      flush_output
      
      check_game_end
    end
    
    def handle_fen(fen_string)
      unless fen_string
        puts 'ERROR: Invalid FEN string'
        flush_output
        return
      end
      
      if @fen_parser.parse(fen_string)
        @move_history.clear
        puts 'OK: FEN loaded'
        puts @board.display
        flush_output
      else
        puts 'ERROR: Invalid FEN string'
        flush_output
      end
    end
    
    def handle_export
      fen = @fen_parser.export
      puts "FEN: #{fen}"
      flush_output
    end
    
    def handle_eval
      # Simple evaluation display
      material_balance = calculate_material_balance
      puts "Evaluation: #{material_balance} (from White's perspective)"
      flush_output
    end

    def handle_hash
      puts "Hash: #{@board.zobrist_hash.to_s(16).rjust(16, '0')}"
      flush_output
    end

    def handle_draws
      require_relative 'lib/draw_detection'
      repetition = DrawDetection.draw_by_repetition?(@board)
      fifty_moves = DrawDetection.draw_by_fifty_moves?(@board)
      puts "Repetition: #{repetition}, 50-move rule: #{fifty_moves}, 50-move clock: #{@board.halfmove_clock}"
      flush_output
    end

    def handle_history
      puts "Position History (#{@board.position_history.length + 1} positions):"
      @board.position_history.each_with_index do |h, i|
        puts "  #{i}: #{h.to_s(16).rjust(16, '0')}"
      end
      puts "  #{@board.position_history.length}: #{@board.zobrist_hash.to_s(16).rjust(16, '0')} (current)"
      flush_output
    end

    def handle_status
      current_color = @board.current_turn
      
      if @move_generator.in_checkmate?(current_color)
        winner = current_color == :white ? 'Black' : 'White'
        puts "CHECKMATE: #{winner} wins"
      elsif @move_generator.in_stalemate?(current_color)
        puts 'STALEMATE: Draw'
      else
        require_relative 'lib/draw_detection'
        if DrawDetection.draw?(@board)
          reason = DrawDetection.draw_by_repetition?(@board) ? "repetition" : "50-move rule"
          puts "DRAW: by #{reason}"
        else
          puts "OK: ongoing"
        end
      end
      flush_output
    end
    
    def handle_perft(depth)
      unless depth.between?(1, 6)
        puts 'ERROR: Perft depth must be 1-6'
        flush_output
        return
      end
      
      result = @perft.calculate(depth)
      puts "Perft #{depth}: #{result[:nodes]} nodes in #{result[:time_ms]}ms"
      flush_output
    end
    
    def handle_help
      puts <<~HELP
        Available commands:
        move <from><to>[promotion] - Execute a move (e.g., move e2e4, move e7e8Q)
        undo                       - Undo the last move
        new                        - Start a new game
        ai <depth>                 - AI makes a move (depth 1-5)
        fen <string>              - Load position from FEN notation
        export                     - Export current position as FEN
        eval                       - Display position evaluation
        hash                       - Show Zobrist hash of current position
        draws                      - Show draw detection status
        history                    - Show position hash history
        perft <depth>             - Performance test (move count)
        help                       - Display this help message
        quit                       - Exit the program
      HELP
      flush_output
    end
    
    def check_game_end
      current_color = @board.current_turn
      
      if @move_generator.in_checkmate?(current_color)
        winner = current_color == :white ? 'Black' : 'White'
        puts "CHECKMATE: #{winner} wins"
        flush_output
      elsif @move_generator.in_stalemate?(current_color)
        puts 'STALEMATE: Draw'
        flush_output
      else
        require_relative 'lib/draw_detection'
        if DrawDetection.draw?(@board)
          reason = DrawDetection.draw_by_repetition?(@board) ? "repetition" : "50-move rule"
          puts "DRAW: by #{reason}"
          flush_output
        end
      end
    end
    
    def calculate_material_balance
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
      
      white_material - black_material
    end
  end
end

# Start the chess engine if this file is run directly
if __FILE__ == $PROGRAM_NAME
  Chess::ChessEngine.new.start
end