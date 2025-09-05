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
      
      loop do
        print "\n> "
        input = gets&.strip
        break if input.nil? || input.empty?
        
        process_command(input)
      end
    end
    
    private
    
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
      when 'perft'
        handle_perft(parts[1]&.to_i || 4)
      when 'help'
        handle_help
      when 'quit', 'exit'
        puts 'Goodbye!'
        exit
      else
        puts 'ERROR: Invalid command. Type "help" for available commands.'
      end
    rescue StandardError => e
      puts "ERROR: #{e.message}"
    end
    
    def handle_move(move_str)
      unless move_str
        puts 'ERROR: Invalid move format'
        return
      end
      
      move = Move.from_algebraic(move_str)
      unless move
        puts 'ERROR: Invalid move format'
        return
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
        return
      end
      
      # Make the move
      @move_history << legal_move
      @board.make_move(legal_move)
      
      puts "OK: #{move_str}"
      puts @board.display
      
      # Check for game end
      check_game_end
    end
    
    def handle_undo
      if @move_history.empty?
        puts 'ERROR: No moves to undo'
        return
      end
      
      last_move = @move_history.pop
      @board.undo_move(last_move)
      
      puts 'OK: Move undone'
      puts @board.display
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
    end
    
    def handle_ai_move(depth)
      unless depth.between?(1, 5)
        puts 'ERROR: AI depth must be 1-5'
        return
      end
      
      result = @ai.find_best_move(depth)
      unless result
        puts 'ERROR: No legal moves available'
        return
      end
      
      move = result[:move]
      @move_history << move
      @board.make_move(move)
      
      puts "AI: #{move.to_algebraic} (depth=#{result[:depth]}, eval=#{result[:score]}, time=#{result[:time_ms]}ms)"
      puts @board.display
      
      check_game_end
    end
    
    def handle_fen(fen_string)
      unless fen_string
        puts 'ERROR: Invalid FEN string'
        return
      end
      
      if @fen_parser.parse(fen_string)
        @move_history.clear
        puts 'OK: Position loaded from FEN'
        puts @board.display
      else
        puts 'ERROR: Invalid FEN string'
      end
    end
    
    def handle_export
      fen = @fen_parser.export
      puts "FEN: #{fen}"
    end
    
    def handle_eval
      # Simple evaluation display
      material_balance = calculate_material_balance
      puts "Evaluation: #{material_balance} (from White's perspective)"
    end
    
    def handle_perft(depth)
      unless depth.between?(1, 6)
        puts 'ERROR: Perft depth must be 1-6'
        return
      end
      
      result = @perft.calculate(depth)
      puts "Perft #{depth}: #{result[:nodes]} nodes in #{result[:time_ms]}ms"
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
        perft <depth>             - Performance test (move count)
        help                       - Display this help message
        quit                       - Exit the program
      HELP
    end
    
    def check_game_end
      current_color = @board.current_turn
      
      if @move_generator.in_checkmate?(current_color)
        winner = current_color == :white ? 'Black' : 'White'
        puts "CHECKMATE: #{winner} wins"
      elsif @move_generator.in_stalemate?(current_color)
        puts 'STALEMATE: Draw'
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