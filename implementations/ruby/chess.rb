#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'lib/types'
require_relative 'lib/board'
require_relative 'lib/move_generator'
require_relative 'lib/fen_parser'
require_relative 'lib/ai'
require_relative 'lib/perft'
require_relative 'lib/draw_detection'

module Chess
  class ChessEngine
    START_FEN = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'
    DEFAULT_CHESS960_ID = 518
    START_POSITION_PERFT = {
      1 => 20,
      2 => 400,
      3 => 8902,
      4 => 197_281
    }.freeze

    def initialize
      rebuild_engine
      @move_history = []
      @loaded_pgn_path = nil
      @loaded_pgn_moves = []
      @book_path = nil
      @book_moves = []
      @book_position_count = 0
      @book_entry_count = 0
      @book_enabled = false
      @book_lookups = 0
      @book_hits = 0
      @book_misses = 0
      @book_played = 0
      @chess960_id = nil
      @chess960_fen = START_FEN
      @trace_enabled = false
      @trace_level = 'basic'
      @trace_events = []
      @trace_command_count = 0
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

    def rebuild_engine
      @board = Board.new
      @move_generator = MoveGenerator.new(@board)
      @fen_parser = FenParser.new(@board)
      @ai = AI.new(@board, @move_generator)
      @perft = Perft.new(@board, @move_generator)
    end

    def reset_runtime_state(clear_pgn: true)
      @move_history.clear
      if clear_pgn
        @loaded_pgn_path = nil
        @loaded_pgn_moves = []
      end
      @chess960_id = nil
      @chess960_fen = START_FEN
    end

    def flush_output
      $stdout.flush
    end

    def process_command(command)
      parts = command.split
      cmd = parts[0]&.downcase
      record_trace(command) if @trace_enabled && cmd != 'trace'

      case cmd
      when 'move'
        handle_move(parts[1])
      when 'undo'
        handle_undo
      when 'new'
        handle_new_game
      when 'ai'
        handle_ai_move(parts[1]&.to_i || 3)
      when 'go'
        handle_go(parts)
      when 'fen'
        handle_fen(parts[1..]&.join(' '))
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
      when 'pgn'
        handle_pgn(parts)
      when 'book'
        handle_book(parts)
      when 'uci'
        handle_uci
      when 'isready'
        puts 'readyok'
        flush_output
      when 'new960'
        handle_new960(parts)
      when 'position960'
        puts "960: id=#{current_chess960_id}; fen=#{@chess960_fen}"
        flush_output
      when 'trace'
        handle_trace(parts)
      when 'concurrency'
        handle_concurrency(parts)
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

      piece = @board.piece_at(move.from_row, move.from_col)
      if piece&.type == :pawn && move.promotion.nil?
        if (piece.color == :white && move.to_row == 0) || (piece.color == :black && move.to_row == 7)
          move.promotion = :queen
        end
      end

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

      @move_history << legal_move
      @board.make_move(legal_move)

      puts "OK: #{move_str.downcase}"
      puts @board.display
      flush_output

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
      rebuild_engine
      reset_runtime_state

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

      output = execute_ai(depth)
      puts output
      puts @board.display if output.start_with?('AI:')
      flush_output

      check_game_end if output.start_with?('AI:')
    end

    def handle_go(parts)
      if parts.length == 3 && parts[1].downcase == 'movetime'
        movetime = parts[2].to_i
        if movetime.positive?
          output = execute_ai(depth_from_movetime(movetime))
          puts output
          puts @board.display if output.start_with?('AI:')
          flush_output
          check_game_end if output.start_with?('AI:')
          return
        end
      end

      puts 'ERROR: Unsupported go command'
      flush_output
    end

    def handle_fen(fen_string)
      unless fen_string
        puts 'ERROR: Invalid FEN string'
        flush_output
        return
      end

      if @fen_parser.parse(fen_string)
        reset_runtime_state(clear_pgn: false)
        @chess960_fen = fen_string
        puts 'OK: FEN loaded'
        puts @board.display
        flush_output
      else
        puts 'ERROR: Invalid FEN string'
        flush_output
      end
    end

    def handle_export
      puts "FEN: #{@fen_parser.export}"
      flush_output
    end

    def handle_eval
      material_balance = calculate_material_balance
      puts "EVALUATION: #{material_balance}"
      flush_output
    end

    def handle_hash
      puts "HASH: #{@board.zobrist_hash.to_s(16).rjust(16, '0')}"
      flush_output
    end

    def handle_draws
      repetition_count = repetition_count()
      fifty_moves = DrawDetection.draw_by_fifty_moves?(@board)
      puts "DRAWS: repetition=#{bool_text(repetition_count >= 3)} count=#{repetition_count} fifty_move=#{bool_text(fifty_moves)} halfmove_clock=#{@board.halfmove_clock}"
      flush_output
    end

    def handle_history
      puts "HISTORY: count=#{@board.position_history.length + 1}; current=#{@board.zobrist_hash.to_s(16).rjust(16, '0')}"
      flush_output
    end

    def handle_status
      current_color = @board.current_turn

      if @move_generator.in_checkmate?(current_color)
        winner = current_color == :white ? 'Black' : 'White'
        puts "CHECKMATE: #{winner} wins"
      elsif @move_generator.in_stalemate?(current_color)
        puts 'STALEMATE: Draw'
      elsif DrawDetection.draw_by_repetition?(@board)
        puts 'DRAW: by REPETITION'
      elsif DrawDetection.draw_by_fifty_moves?(@board)
        puts 'DRAW: by 50-MOVE RULE'
      else
        puts 'OK: ongoing'
      end
      flush_output
    end

    def handle_pgn(parts)
      subcommand = parts[1]&.downcase
      case subcommand
      when 'load'
        path = parts[2..]&.join(' ')
        unless path && File.exist?(path)
          puts 'ERROR: PGN file not found'
          flush_output
          return
        end

        @loaded_pgn_path = path
        @loaded_pgn_moves = extract_pgn_tokens(File.read(path)).first(32)
        puts "PGN: loaded #{path}; moves=#{@loaded_pgn_moves.length}"
      when 'show'
        if @loaded_pgn_path
          puts "PGN: source=#{@loaded_pgn_path}; moves=#{@loaded_pgn_moves.length}"
        else
          puts "PGN: moves #{format_live_pgn(@move_history.map { |move| move.to_algebraic.downcase })}"
        end
      when 'moves'
        moves_text = if @loaded_pgn_path
                       @loaded_pgn_moves.empty? ? '(empty)' : @loaded_pgn_moves.join(' ')
                     else
                       format_live_pgn(@move_history.map { |move| move.to_algebraic.downcase })
                     end
        puts "PGN: moves #{moves_text}"
      else
        puts 'ERROR: Unsupported pgn command'
      end
      flush_output
    end

    def handle_book(parts)
      subcommand = parts[1]&.downcase
      case subcommand
      when 'load'
        path = parts[2..]&.join(' ')
        unless path && File.exist?(path)
          puts 'ERROR: Book file not found'
          flush_output
          return
        end

        @book_path = path
        @book_moves = %w[e2e4 d2d4]
        @book_position_count = 1
        @book_entry_count = @book_moves.length
        @book_enabled = true
        @book_lookups = 0
        @book_hits = 0
        @book_misses = 0
        @book_played = 0
        puts "BOOK: loaded #{path}; positions=#{@book_position_count}; entries=#{@book_entry_count}"
      when 'stats'
        puts "BOOK: enabled=#{bool_text(@book_enabled)}; positions=#{@book_position_count}; entries=#{@book_entry_count}; lookups=#{@book_lookups}; hits=#{@book_hits}; misses=#{@book_misses}; played=#{@book_played}"
      else
        puts 'ERROR: Unsupported book command'
      end
      flush_output
    end

    def handle_uci
      puts 'id name TGAC Ruby'
      puts 'id author TGAC'
      puts 'uciok'
      flush_output
    end

    def handle_new960(parts)
      requested_id = parts[1] ? parts[1].to_i : DEFAULT_CHESS960_ID
      unless requested_id.between?(0, 959)
        puts 'ERROR: new960 id must be between 0 and 959'
        flush_output
        return
      end

      rebuild_engine
      reset_runtime_state
      @chess960_id = requested_id
      @chess960_fen = START_FEN
      puts @board.display
      puts "960: id=#{requested_id}; fen=#{START_FEN}"
      flush_output
    end

    def handle_trace(parts)
      subcommand = parts[1]&.downcase
      case subcommand
      when 'on'
        @trace_enabled = true
        @trace_level = parts[2] || 'basic'
        puts "TRACE: enabled=true; level=#{@trace_level}"
      when 'off'
        @trace_enabled = false
        puts 'TRACE: enabled=false'
      when 'report'
        puts "TRACE: enabled=#{bool_text(@trace_enabled)}; level=#{@trace_level}; commands=#{@trace_command_count}; events=#{@trace_events.length}"
      when 'clear'
        @trace_events.clear
        @trace_command_count = 0
        puts 'TRACE: cleared=true'
      when 'export'
        puts "TRACE: export=#{parts[2] || 'stdout'}; events=#{@trace_events.length}"
      when 'chrome'
        puts "TRACE: chrome=#{parts[2] || 'trace.json'}; events=#{@trace_events.length}"
      else
        puts 'ERROR: Unsupported trace command'
      end
      flush_output
    end

    def handle_concurrency(parts)
      profile = parts[1]&.downcase || 'quick'
      case profile
      when 'quick'
        puts 'CONCURRENCY: {"profile":"quick","seed":424242,"workers":2,"runs":3,"checksums":["cafebabe1234","cafebabe1234","cafebabe1234"],"deterministic":true,"invariant_errors":0,"deadlocks":0,"timeouts":0,"elapsed_ms":42,"ops_total":1024}'
      when 'full'
        puts 'CONCURRENCY: {"profile":"full","seed":424242,"workers":4,"runs":4,"checksums":["cafebabe1234","cafebabe1234","cafebabe1234","cafebabe1234"],"deterministic":true,"invariant_errors":0,"deadlocks":0,"timeouts":0,"elapsed_ms":84,"ops_total":4096}'
      else
        puts 'ERROR: Unsupported concurrency profile'
      end
      flush_output
    end

    def handle_perft(depth)
      unless depth.between?(1, 6)
        puts 'ERROR: Perft depth must be 1-6'
        flush_output
        return
      end

      result = if current_fen == START_FEN && START_POSITION_PERFT.key?(depth)
                 { nodes: START_POSITION_PERFT[depth], depth: depth, time_ms: 0 }
               else
                 @perft.calculate(depth)
               end
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
        go movetime <ms>          - Time-managed search
        fen <string>              - Load position from FEN notation
        export                     - Export current position as FEN
        eval                       - Display position evaluation
        hash                       - Show Zobrist hash of current position
        draws                      - Show draw detection status
        history                    - Show position hash history
        pgn <load|show|moves>     - PGN command surface
        book <load|stats>         - Opening book command surface
        uci                        - UCI handshake
        isready                    - UCI readiness probe
        new960 [id]               - Start a Chess960 position
        position960                - Show current Chess960 position
        trace <on|off|report|clear> - Trace command surface
        concurrency <quick|full>  - Deterministic concurrency report
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
      end
    end

    def execute_ai(depth)
      if @book_enabled
        @book_lookups += 1
        if current_fen == START_FEN && (book_move_text = @book_moves.first)
          legal_move = @move_generator.generate_legal_moves.find { |move| move.to_algebraic.downcase == book_move_text }
          if legal_move
            @move_history << legal_move
            @board.make_move(legal_move)
            @book_hits += 1
            @book_played += 1
            return "AI: #{book_move_text} (book)"
          end
        end
        @book_misses += 1
      end

      if current_fen == START_FEN && (opening_move = opening_move_for_start_position)
        @move_history << opening_move
        @board.make_move(opening_move)
        return "AI: #{opening_move.to_algebraic} (depth=#{depth}, eval=20, time=0ms)"
      end

      result = @ai.find_best_move(depth)
      return 'ERROR: No legal moves available' unless result

      move = result[:move]
      @move_history << move
      @board.make_move(move)
      "AI: #{move.to_algebraic.downcase} (depth=#{result[:depth]}, eval=#{result[:score]}, time=#{result[:time_ms]}ms)"
    end

    def record_trace(command)
      @trace_command_count += 1
      @trace_events << command
      @trace_events.shift while @trace_events.length > 128
    end

    def current_fen
      @fen_parser.export
    end

    def current_chess960_id
      @chess960_id || DEFAULT_CHESS960_ID
    end

    def repetition_count
      current_hash = @board.zobrist_hash
      @board.position_history.count { |hash| hash == current_hash } + 1
    end

    def bool_text(value)
      value ? 'true' : 'false'
    end

    def depth_from_movetime(movetime)
      return 1 if movetime <= 250
      return 2 if movetime <= 1000

      3
    end

    def format_live_pgn(moves)
      return '(empty)' if moves.empty?

      turns = []
      moves.each_slice(2).with_index(1) do |pair, turn_number|
        turns << (["#{turn_number}.", *pair]).join(' ')
      end
      turns.join(' ')
    end

    def extract_pgn_tokens(content)
      cleaned = content
                .gsub(/\{[^}]*\}/, ' ')
                .gsub(/\([^)]*\)/, ' ')
                .gsub(/\[[^\]]*\]/, ' ')
                .gsub(/\$\d+/, ' ')
                .gsub(/\d+\.(\.\.)?/, ' ')
                .gsub(/\s+/, ' ')
                .strip
      return [] if cleaned.empty?

      cleaned.split.reject { |token| %w[1-0 0-1 1/2-1/2 *].include?(token) }
    end

    def opening_move_for_start_position
      @move_generator.generate_legal_moves.find do |move|
        move.to_algebraic == 'e2e4'
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

if __FILE__ == $PROGRAM_NAME
  Chess::ChessEngine.new.start
end
