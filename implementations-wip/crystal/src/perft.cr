# Performance testing utilities

require "./types"
require "./board"
require "./move_generator"

class Perft
  @move_generator : MoveGenerator

  def initialize
    @move_generator = MoveGenerator.new
  end

  def perft(game_state : GameState, depth : Int32) : Int64
    return 1_i64 if depth == 0

    color = game_state.turn
    moves = @move_generator.get_legal_moves(game_state, color)
    nodes = 0_i64

    moves.each do |move|
      new_state = Board.make_move(game_state, move)
      nodes += perft(new_state, depth - 1)
    end

    nodes
  end

  def perft_divide(game_state : GameState, depth : Int32) : Hash(String, Int64)
    results = Hash(String, Int64).new
    color = game_state.turn
    moves = @move_generator.get_legal_moves(game_state, color)

    moves.each do |move|
      move_str = move.to_s
      new_state = Board.make_move(game_state, move)
      count = perft(new_state, depth - 1)
      results[move_str] = count
    end

    results
  end

  # Known perft results for validation
  def self.known_results : Hash(String, Hash(Int32, Int64))
    {
      "starting" => {
        1 => 20_i64,
        2 => 400_i64,
        3 => 8_902_i64,
        4 => 197_281_i64,
        5 => 4_865_609_i64,
        6 => 119_060_324_i64
      },
      "kiwipete" => {
        1 => 48_i64,
        2 => 2_039_i64,
        3 => 97_862_i64,
        4 => 4_085_603_i64,
        5 => 193_690_690_i64
      },
      "position3" => {
        1 => 14_i64,
        2 => 191_i64,
        3 => 2_812_i64,
        4 => 43_238_i64,
        5 => 674_624_i64,
        6 => 11_030_083_i64
      },
      "position4" => {
        1 => 6_i64,
        2 => 264_i64,
        3 => 9_467_i64,
        4 => 422_333_i64,
        5 => 15_833_292_i64
      },
      "position5" => {
        1 => 44_i64,
        2 => 1_486_i64,
        3 => 62_379_i64,
        4 => 2_103_487_i64,
        5 => 89_941_194_i64
      },
      "position6" => {
        1 => 46_i64,
        2 => 2_079_i64,
        3 => 89_890_i64,
        4 => 3_894_594_i64,
        5 => 164_075_551_i64
      }
    }
  end

  def self.validate_position(name : String, fen : String, depth : Int32) : Bool
    expected_results = known_results[name]?
    return false unless expected_results

    expected = expected_results[depth]?
    return false unless expected

    game_state = FEN.parse(fen)
    return false unless game_state

    perft = Perft.new
    actual = perft.perft(game_state, depth)

    actual == expected
  end

  def self.run_validation_suite : Bool
    puts "Running perft validation suite..."
    
    all_passed = true
    total_tests = 0
    passed_tests = 0

    positions = FEN.test_positions
    known = known_results

    positions.each do |name, fen|
      puts "\nTesting #{name}..."
      
      known_results_for_position = known[name]?
      next unless known_results_for_position

      known_results_for_position.each do |depth, expected|
        next if depth > 4  # Skip slow tests for validation

        total_tests += 1
        
        print "  Depth #{depth}: "
        
        game_state = FEN.parse(fen)
        unless game_state
          puts "FAILED (invalid FEN)"
          all_passed = false
          next
        end

        start_time = Time.monotonic
        perft = Perft.new
        actual = perft.perft(game_state, depth)
        time_taken = Time.monotonic - start_time

        if actual == expected
          puts "PASSED (#{actual} nodes, #{time_taken.total_milliseconds.round(1)}ms)"
          passed_tests += 1
        else
          puts "FAILED (expected #{expected}, got #{actual})"
          all_passed = false
        end
      end
    end

    puts "\nValidation Results: #{passed_tests}/#{total_tests} tests passed"
    all_passed
  end

  # Performance benchmark
  def self.benchmark(depth : Int32 = 5) : Nil
    puts "Running perft benchmark (depth #{depth})..."
    
    positions = FEN.test_positions
    
    positions.each do |name, fen|
      next if name == "starting" && depth > 5  # Skip slow starting position
      
      puts "\n--- #{name} ---"
      
      game_state = FEN.parse(fen)
      next unless game_state
      
      perft = Perft.new
      start_time = Time.monotonic
      
      nodes = perft.perft(game_state, depth)
      
      time_taken = Time.monotonic - start_time
      nps = (nodes / time_taken.total_seconds).to_i64
      
      puts "Depth #{depth}: #{nodes} nodes"
      puts "Time: #{time_taken.total_milliseconds.round(1)}ms"
      puts "Speed: #{nps} NPS"
    end
  end
end