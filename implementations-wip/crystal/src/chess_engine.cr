# Main chess engine CLI

require "./types"
require "./board"
require "./move_generator"
require "./ai"
require "./fen"
require "./perft"

class ChessEngine
  @game_state : GameState
  @move_generator : MoveGenerator
  @ai : ChessAI

  def initialize
    @game_state = FEN.starting_position
    @move_generator = MoveGenerator.new
    @ai = ChessAI.new
  end

  def run
    puts "Crystal Chess Engine v1.0"
    puts "Type 'help' for available commands"
    
    loop do
      print "> "
      input = gets
      break unless input
      
      command = input.strip.downcase
      next if command.empty?
      
      case command
      when "help"
        show_help
      when "board", "show"
        puts Board.display(@game_state)
      when "moves"
        show_legal_moves
      when "fen"
        puts FEN.export(@game_state)
      when "reset"
        @game_state = FEN.starting_position
        puts "Board reset to starting position"
      when "ai", "computer"
        make_ai_move
      when "demo"
        run_demo
      when "perft"
        run_perft_test
      when "benchmark"
        run_benchmark
      when "quit", "exit"
        puts "Goodbye!"
        break
      else
        if command.starts_with?("fen ")
          load_fen(command[4..-1])
        elsif command.starts_with?("perft ")
          depth = command[6..-1].to_i?
          if depth && depth > 0
            run_perft_test(depth)
          else
            puts "Invalid depth. Usage: perft <depth>"
          end
        elsif move_pattern?(command)
          make_human_move(command)
        else
          puts "Unknown command. Type 'help' for available commands."
        end
      end
    end
  end

  private def show_help
    puts <<-HELP
    Available commands:
      help          - Show this help
      board/show    - Display current board
      moves         - Show legal moves
      fen           - Show current position in FEN notation
      fen <string>  - Load position from FEN string
      reset         - Reset to starting position
      ai/computer   - Make AI move
      demo          - Run AI vs AI demo
      perft [depth] - Run perft test (default depth 4)
      benchmark     - Run performance benchmark
      <move>        - Make move (e.g., e2e4, a7a8q)
      quit/exit     - Exit program
    HELP
  end

  private def show_legal_moves
    moves = @move_generator.get_legal_moves(@game_state, @game_state.turn)
    
    if moves.empty?
      puts "No legal moves available"
      
      if @move_generator.in_check?(@game_state, @game_state.turn)
        puts "Checkmate! #{@game_state.turn.opposite} wins"
      else
        puts "Stalemate! Draw"
      end
      return
    end
    
    puts "Legal moves (#{moves.size}):"
    moves.each_slice(8) do |move_slice|
      puts move_slice.map(&.to_s).join("  ")
    end
  end

  private def load_fen(fen : String)
    if new_state = FEN.parse(fen)
      @game_state = new_state
      puts "Position loaded successfully"
      puts Board.display(@game_state)
    else
      puts "Invalid FEN string"
    end
  end

  private def move_pattern?(input : String) : Bool
    # Simple pattern matching for moves like "e2e4" or "e7e8q"
    input.size >= 4 && input.size <= 5 &&
      input[0].ascii_letter? && input[1].ascii_number? &&
      input[2].ascii_letter? && input[3].ascii_number?
  end

  private def make_human_move(move_str : String)
    # Parse move string (e.g., "e2e4" or "e7e8q")
    return unless move_str.size >= 4
    
    from_square = algebraic_to_square(move_str[0..1])
    to_square = algebraic_to_square(move_str[2..3])
    
    unless from_square && to_square
      puts "Invalid move format"
      return
    end
    
    # Find matching legal move
    legal_moves = @move_generator.get_legal_moves(@game_state, @game_state.turn)
    
    matching_moves = legal_moves.select do |move|
      move.from == from_square && move.to == to_square
    end
    
    if matching_moves.empty?
      puts "Illegal move"
      return
    end
    
    # Handle promotion
    chosen_move = if move_str.size == 5 && matching_moves.size > 1
                    promotion_char = move_str[4].upcase
                    promotion_type = PieceType.from_char(promotion_char)
                    
                    if promotion_type
                      matching_moves.find { |m| m.promotion == promotion_type }
                    else
                      matching_moves.first
                    end
                  else
                    matching_moves.first
                  end
    
    if chosen_move
      @game_state = Board.make_move(@game_state, chosen_move)
      puts Board.display(@game_state)
      
      # Check game status
      game_over, message = Board.is_game_over(@game_state)
      puts message if game_over
    else
      puts "Invalid move"
    end
  end

  private def make_ai_move
    puts "AI is thinking..."
    start_time = Time.monotonic
    
    result = @ai.search(@game_state, 4, @game_state.turn.white?)
    
    if best_move = result.best_move
      @game_state = Board.make_move(@game_state, best_move)
      
      time_taken = Time.monotonic - start_time
      puts "AI played: #{best_move} (#{result.evaluation}, #{result.nodes} nodes, #{time_taken.total_milliseconds.round(1)}ms)"
      puts Board.display(@game_state)
      
      # Check game status
      game_over, message = Board.is_game_over(@game_state)
      puts message if game_over
    else
      puts "AI cannot find a move"
    end
  end

  private def run_demo
    puts "Running AI vs AI demo..."
    move_count = 0
    
    while move_count < 50  # Limit demo length
      puts "\n--- Move #{(@game_state.fullmove_number)} (#{@game_state.turn}) ---"
      
      make_ai_move
      move_count += 1
      
      game_over, message = Board.is_game_over(@game_state)
      if game_over
        puts "\nDemo ended: #{message}"
        break
      end
      
      sleep(1.seconds)  # Pause between moves
    end
    
    if move_count >= 50
      puts "\nDemo ended after 50 moves"
    end
  end

  private def run_perft_test(depth : Int32 = 4)
    puts "Running perft test at depth #{depth}..."
    
    perft = Perft.new
    start_time = Time.monotonic
    
    nodes = perft.perft(@game_state, depth)
    
    time_taken = Time.monotonic - start_time
    nps = (nodes / time_taken.total_seconds).to_i64
    
    puts "Depth #{depth}: #{nodes} nodes in #{time_taken.total_milliseconds.round(1)}ms (#{nps} NPS)"
  end

  private def run_benchmark
    puts "Running benchmark suite..."
    
    # Test different positions
    positions = FEN.test_positions
    
    positions.each do |name, fen|
      puts "\n--- Testing #{name} ---"
      
      if test_state = FEN.parse(fen)
        @game_state = test_state
        
        # Quick perft test
        perft = Perft.new
        start_time = Time.monotonic
        nodes = perft.perft(@game_state, 3)
        time_taken = Time.monotonic - start_time
        
        puts "Perft(3): #{nodes} nodes in #{time_taken.total_milliseconds.round(1)}ms"
        
        # AI search test
        start_time = Time.monotonic
        result = @ai.search(@game_state, 4)
        time_taken = Time.monotonic - start_time
        
        puts "AI search: #{result.nodes} nodes in #{time_taken.total_milliseconds.round(1)}ms"
      end
    end
    
    # Reset to starting position
    @game_state = FEN.starting_position
  end
end

# Run the engine if this file is executed directly
if PROGRAM_NAME.ends_with?("chess_engine.cr") || PROGRAM_NAME.ends_with?("chess_engine")
  engine = ChessEngine.new
  engine.run
end