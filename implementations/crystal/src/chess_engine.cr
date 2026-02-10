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
    loop do
      input = gets
      break unless input
      
      line = input.strip
      next if line.empty?
      
      parts = line.split(/\s+/)
      command = parts[0].downcase
      
      case command
      when "new"
        @game_state = FEN.starting_position
        puts "OK: New game started"
      when "move"
        if parts.size < 2
          puts "ERROR: Missing move"
          next
        end
        make_move(parts[1])
      when "undo"
        handle_undo
      when "export"
        puts "FEN: #{FEN.export(@game_state)}"
      when "fen"
        if parts.size < 2
          puts "ERROR: Missing FEN string"
          next
        end
        load_fen(parts[1..-1].join(" "))
      when "ai"
        depth = parts.size > 1 ? (parts[1].to_i? || 3) : 3
        make_ai_move(depth)
      when "status"
        show_status
      when "hash"
        puts "HASH: #{@game_state.hash.to_s(16).rjust(16, '0')}"
      when "draws"
        puts "REPETITION: #{Board.is_draw_by_repetition(@game_state)}"
        puts "50-MOVE RULE: #{Board.is_draw_by_fifty_moves(@game_state)}"
        puts "OK: clock=#{@game_state.halfmove_clock}"
      when "eval"
        puts "EVALUATION: #{@ai.search(@game_state, 0).evaluation}"
      when "perft"
        depth = parts.size > 1 ? (parts[1].to_i? || 3) : 3
        run_perft(depth)
      when "display"
        puts Board.display(@game_state)
      when "help"
        show_help
      when "quit"
        break
      else
        if move_pattern?(command)
          make_move(command)
        else
          puts "ERROR: Unknown command #{command}"
        end
      end
    end
  end

  private def handle_undo
    if @game_state.move_history.empty?
      puts "ERROR: No moves to undo"
    else
      history = @game_state.move_history.dup
      history.pop
      new_state = FEN.starting_position
      history.each do |m|
        new_state = Board.make_move(new_state, m)
      end
      @game_state = new_state
      puts "OK: undo"
    end
  end

  private def load_fen(fen : String)
    if new_state = FEN.parse(fen)
      @game_state = new_state
      puts "OK: FEN loaded"
    else
      puts "ERROR: Invalid FEN string"
    end
  end

  private def move_pattern?(input : String) : Bool
    input.size >= 4 && input.size <= 5 &&
      input[0].ascii_letter? && input[1].ascii_number? &&
      input[2].ascii_letter? && input[3].ascii_number?
  end

  private def make_move(move_str : String)
    from_square = algebraic_to_square(move_str[0..1])
    to_square = algebraic_to_square(move_str[2..3])
    
    unless from_square && to_square
      puts "ERROR: Invalid move format"
      return
    end
    
    legal_moves = @move_generator.get_legal_moves(@game_state, @game_state.turn)
    
    matching_moves = legal_moves.select do |move|
      move.from == from_square && move.to == to_square
    end
    
    if matching_moves.empty?
      # Provide more specific error for the harness if possible
      if @move_generator.generate_moves(@game_state, @game_state.turn).any? { |m| m.from == from_square && m.to == to_square }
        puts "ERROR: King would be in check"
      else
        puts "ERROR: Illegal move"
      end
      return
    end
    
    chosen_move = if move_str.size == 5
                    promotion_char = move_str[4].upcase
                    promotion_type = PieceType.from_char(promotion_char)
                    matching_moves.find { |m| m.promotion == promotion_type }
                  else
                    matching_moves.first
                  end
    
    if chosen_move
      @game_state = Board.make_move(@game_state, chosen_move)
      
      # Check for game end
      over, message = Board.is_game_over(@game_state)
      if over
        puts message
      else
        next_moves = @move_generator.get_legal_moves(@game_state, @game_state.turn)
        if next_moves.empty?
          if @move_generator.in_check?(@game_state, @game_state.turn)
            puts "CHECKMATE: #{move_str}"
          else
            puts "STALEMATE: Draw"
          end
        else
          puts "OK: #{move_str}"
        end
      end
    else
      puts "ERROR: Invalid move"
    end
  end

  private def make_ai_move(depth : Int32)
    result = @ai.search(@game_state, depth, @game_state.turn.white?)
    
    if best_move = result.best_move
      move_str = best_move.to_s
      @game_state = Board.make_move(@game_state, best_move)
      
      over, message = Board.is_game_over(@game_state)
      if over
        puts "AI: #{move_str} (#{message})"
      else
        next_moves = @move_generator.get_legal_moves(@game_state, @game_state.turn)
        if next_moves.empty?
          if @move_generator.in_check?(@game_state, @game_state.turn)
            puts "AI: #{move_str} (CHECKMATE)"
          else
            puts "AI: #{move_str} (STALEMATE)"
          end
        else
          puts "AI: #{move_str} (depth=#{depth}, eval=#{result.evaluation}, time=#{result.time_ms})"
        end
      end
    else
      puts "ERROR: No legal moves"
    end
  end

  private def show_status
    moves = @move_generator.get_legal_moves(@game_state, @game_state.turn)
    if moves.empty?
      if @move_generator.in_check?(@game_state, @game_state.turn)
        puts "CHECKMATE: #{@game_state.turn.opposite} wins"
      else
        puts "STALEMATE: Draw"
      end
    else
      over, message = Board.is_game_over(@game_state)
      if over
        puts message
      else
        puts "OK: ongoing"
      end
    end
  end

  private def run_perft(depth : Int32)
    perft = Perft.new
    start_time = Time.monotonic
    nodes = perft.perft(@game_state, depth)
    puts "Perft #{depth}: #{nodes}"
  end

  private def show_help
    puts <<-HELP
Commands:
new - Start new game
move <from><to>[promo] - Make move (e.g., move e2e4, move a7a8q)
undo - Undo last move
fen <string> - Load FEN position
export - Export current position as FEN
eval - Evaluate position
ai <depth> - AI makes a move (default depth: 3)
perft <depth> - Count positions at depth
status - Show game status
hash - Show position hash
draws - Show draw status
display - Display the board
quit - Exit program
HELP
  end
end

engine = ChessEngine.new
engine.run