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
    while input = gets
      line = input.strip
      next if line.empty?
      
      parts = line.split(/\s+/)
      command = parts[0].downcase
      
      case command
      when "new"
        @game_state = FEN.starting_position
        puts "OK: New game started"
      when "export"
        puts "FEN: #{FEN.export(@game_state)}"
      when "quit"
        break
      else
        puts "ERROR: Unknown command #{command}"
      end
    end
  end
end

engine = ChessEngine.new
engine.run