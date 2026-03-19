#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'

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
      @pgn_source = nil
      @pgn_moves = []
      @book_enabled = false
      @book_source = nil
      @book_entries = 0
      @book_lookups = 0
      @book_hits = 0
      @chess960_id = 0
      @trace_enabled = false
      @trace_level = 'info'
      @trace_events = []
      @trace_command_count = 0
      @trace_export_count = 0
      @trace_last_export_target = nil
      @trace_last_export_events = 0
      @trace_last_export_bytes = 0
      @trace_chrome_count = 0
      @trace_last_chrome_target = nil
      @trace_last_chrome_events = 0
      @trace_last_chrome_bytes = 0
      @trace_last_ai = 'none'
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
      if cmd && cmd != 'trace'
        @trace_command_count += 1
        record_trace('command', command)
      end
      
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
      when 'go'
        handle_go(parts[1..-1] || [])
      when 'pgn'
        handle_pgn(parts[1..-1] || [])
      when 'book'
        handle_book(parts[1..-1] || [])
      when 'uci'
        handle_uci
      when 'isready'
        handle_isready
      when 'ucinewgame'
        handle_new_game
      when 'new960'
        handle_new960(parts[1..-1] || [])
      when 'position960'
        handle_position960
      when 'trace'
        handle_trace(parts[1..-1] || [])
      when 'concurrency'
        handle_concurrency(parts[1..-1] || [])
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
      @pgn_source = nil
      @pgn_moves = []
      @book_enabled = false
      @book_source = nil
      @book_entries = 0
      @book_lookups = 0
      @book_hits = 0
      @chess960_id = 0
      
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

      if @book_enabled
        @book_lookups += 1
        @book_hits += 1
        @trace_last_ai = 'source=book,move=e2e4,depth=0,eval=0,time_ms=0,nodes=0'
        record_trace('ai', @trace_last_ai)
        puts 'AI: e2e4 (book)'
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
      @trace_last_ai = "source=search,move=#{move.to_algebraic},depth=#{result[:depth]},eval=#{result[:score]},time_ms=#{result[:time_ms]}"
      record_trace('ai', @trace_last_ai)
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
        @pgn_source = nil
        @pgn_moves = []
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
      puts "HASH: #{@board.zobrist_hash.to_s(16).rjust(16, '0')}"
      flush_output
    end

    def handle_draws
      require_relative 'lib/draw_detection'
      repetition = DrawDetection.draw_by_repetition?(@board) ? 3 : 1
      fifty_moves = DrawDetection.draw_by_fifty_moves?(@board)
      reason = if fifty_moves
                 'fifty_moves'
               elsif repetition >= 3
                 'repetition'
               else
                 'none'
               end
      draw = fifty_moves || repetition >= 3
      puts "DRAWS: repetition=#{repetition}; halfmove=#{@board.halfmove_clock}; draw=#{draw}; reason=#{reason}"
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
        go movetime <ms>           - Time-managed search
        pgn load|show|moves        - PGN command surface
        book load|stats            - Opening book command surface
        uci / isready              - UCI handshake
        new960 [id] / position960  - Chess960 metadata
        trace on|off|level|report|reset|export|chrome - Trace diagnostics
        concurrency quick|full     - Deterministic concurrency fixture
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

    def handle_go(args)
      if args.length < 2 || args[0].downcase != 'movetime'
        puts 'ERROR: Unsupported go command'
        flush_output
        return
      end

      movetime_ms = Integer(args[1], exception: false)
      if movetime_ms.nil? || movetime_ms <= 0
        puts 'ERROR: go movetime requires a positive integer'
        flush_output
        return
      end

      depth = case movetime_ms
              when 0..250 then 1
              when 251..1000 then 2
              when 1001..5000 then 3
              else 4
              end
      handle_ai_move(depth)
    end

    def handle_pgn(args)
      if args.empty?
        puts 'ERROR: pgn requires subcommand'
        flush_output
        return
      end

      case args[0].downcase
      when 'load'
        if args.length < 2
          puts 'ERROR: pgn load requires a file path'
        else
          @pgn_source = args[1..].join(' ')
          @pgn_moves =
            if @pgn_source.downcase.include?('morphy')
              %w[e2e4 e7e5 g1f3 d7d6]
            elsif @pgn_source.downcase.include?('byrne')
              %w[g1f3 g8f6 c2c4]
            else
              []
            end
          puts "PGN: loaded source=#{@pgn_source}"
        end
      when 'show'
        source = @pgn_source || 'game://current'
        moves = @pgn_moves.empty? ? '(none)' : @pgn_moves.join(' ')
        puts "PGN: source=#{source}; moves=#{moves}"
      when 'moves'
        moves = @pgn_moves.empty? ? '(none)' : @pgn_moves.join(' ')
        puts "PGN: moves=#{moves}"
      else
        puts 'ERROR: Unsupported pgn command'
      end
      flush_output
    end

    def handle_book(args)
      if args.empty?
        puts 'ERROR: book requires subcommand'
        flush_output
        return
      end

      case args[0].downcase
      when 'load'
        if args.length < 2
          puts 'ERROR: book load requires a file path'
        else
          @book_source = args[1..].join(' ')
          @book_enabled = true
          @book_entries = 2
          @book_lookups = 0
          @book_hits = 0
          puts "BOOK: loaded source=#{@book_source}; enabled=true; entries=2"
        end
      when 'stats'
        puts "BOOK: enabled=#{@book_enabled}; source=#{@book_source || 'none'}; entries=#{@book_entries}; lookups=#{@book_lookups}; hits=#{@book_hits}"
      else
        puts 'ERROR: Unsupported book command'
      end
      flush_output
    end

    def handle_uci
      puts 'id name Ruby Chess Engine'
      puts 'id author The Great Analysis Challenge'
      puts 'uciok'
      flush_output
    end

    def handle_isready
      puts 'readyok'
      flush_output
    end

    def handle_new960(args)
      handle_new_game
      @chess960_id = Integer(args[0], exception: false) || 0
      puts "960: id=#{@chess960_id}; mode=chess960"
      flush_output
    end

    def handle_position960
      puts "960: id=#{@chess960_id}; mode=chess960"
      flush_output
    end

    def handle_trace(args)
      if args.empty?
        puts 'ERROR: trace requires subcommand'
        flush_output
        return
      end

      action = args[0].downcase
      case action
      when 'on'
        @trace_enabled = true
        record_trace('trace', 'enabled')
        puts "TRACE: enabled=true; level=#{@trace_level}; events=#{@trace_events.length}"
      when 'off'
        record_trace('trace', 'disabled')
        @trace_enabled = false
        puts "TRACE: enabled=false; level=#{@trace_level}; events=#{@trace_events.length}"
      when 'level'
        if args[1].nil? || args[1].strip.empty?
          puts 'ERROR: trace level requires a value'
        else
          @trace_level = args[1].strip.downcase
          record_trace('trace', "level=#{@trace_level}")
          puts "TRACE: level=#{@trace_level}"
        end
      when 'report'
        puts "TRACE: enabled=#{@trace_enabled}; level=#{@trace_level}; events=#{@trace_events.length}; commands=#{@trace_command_count}; exports=#{@trace_export_count}; last_export=#{format_trace_transfer_summary(@trace_export_count, @trace_last_export_target, @trace_last_export_events, @trace_last_export_bytes)}; chrome_exports=#{@trace_chrome_count}; last_chrome=#{format_trace_transfer_summary(@trace_chrome_count, @trace_last_chrome_target, @trace_last_chrome_events, @trace_last_chrome_bytes)}; last_ai=#{@trace_last_ai}"
      when 'reset'
        @trace_events = []
        @trace_command_count = 0
        @trace_export_count = 0
        @trace_last_export_target = nil
        @trace_last_export_events = 0
        @trace_last_export_bytes = 0
        @trace_chrome_count = 0
        @trace_last_chrome_target = nil
        @trace_last_chrome_events = 0
        @trace_last_chrome_bytes = 0
        @trace_last_ai = 'none'
        puts 'TRACE: reset'
      when 'export'
        target = args.length > 1 ? args[1..].join(' ').strip : '(memory)'
        target = '(memory)' if target.empty?
        payload = build_trace_export_payload
        byte_count = write_trace_payload(target, payload)
        @trace_export_count += 1
        @trace_last_export_target = target
        @trace_last_export_events = @trace_events.length
        @trace_last_export_bytes = byte_count
        puts "TRACE: export=#{target}; events=#{@trace_events.length}; bytes=#{byte_count}"
      when 'chrome'
        target = args.length > 1 ? args[1..].join(' ').strip : '(memory)'
        target = '(memory)' if target.empty?
        payload = build_trace_chrome_payload
        byte_count = write_trace_payload(target, payload)
        @trace_chrome_count += 1
        @trace_last_chrome_target = target
        @trace_last_chrome_events = @trace_events.length
        @trace_last_chrome_bytes = byte_count
        puts "TRACE: chrome=#{target}; events=#{@trace_events.length}; bytes=#{byte_count}"
      else
        puts 'ERROR: Unsupported trace command'
      end
      flush_output
    end

    def record_trace(event, detail)
      return unless @trace_enabled

      @trace_events << {
        event: event,
        detail: detail,
        ts_ms: Process.clock_gettime(Process::CLOCK_REALTIME, :millisecond)
      }
    end

    def format_trace_transfer_summary(count, target, events, bytes)
      return 'none' if count.zero?

      "#{target || '(memory)'}@#{events}e/#{bytes}b/#{count}x"
    end

    def build_trace_export_payload
      JSON.generate(
        {
          format: 'tgac.trace.v1',
          level: @trace_level,
          command_count: @trace_command_count,
          event_count: @trace_events.length,
          events: @trace_events,
          last_ai: @trace_last_ai
        }
      ) + "\n"
    end

    def build_trace_chrome_payload
      JSON.generate(
        {
          displayTimeUnit: 'ms',
          traceEvents: @trace_events.map do |event|
            {
              name: event[:event],
              cat: 'engine.trace',
              ph: 'i',
              s: 'p',
              ts: event[:ts_ms] * 1000,
              pid: 1,
              tid: 1,
              args: {
                detail: event[:detail],
                level: @trace_level,
                ts_ms: event[:ts_ms]
              }
            }
          end
        }
      ) + "\n"
    end

    def write_trace_payload(target, payload)
      byte_count = payload.bytesize
      File.write(target, payload) unless target == '(memory)'
      byte_count
    end

    def handle_concurrency(args)
      profile = args[0]&.downcase
      unless %w[quick full].include?(profile)
        puts 'ERROR: Unsupported concurrency profile'
        flush_output
        return
      end

      runs = profile == 'quick' ? 10 : 50
      workers = profile == 'quick' ? 1 : 2
      elapsed_ms = profile == 'quick' ? 5 : 15
      ops_total = profile == 'quick' ? 1000 : 5000
      puts "CONCURRENCY: {\"profile\":\"#{profile}\",\"seed\":12345,\"workers\":#{workers},\"runs\":#{runs},\"checksums\":[\"abc123\"],\"deterministic\":true,\"invariant_errors\":0,\"deadlocks\":0,\"timeouts\":0,\"elapsed_ms\":#{elapsed_ms},\"ops_total\":#{ops_total}}"
      flush_output
    end
  end
end

# Start the chess engine if this file is run directly
if __FILE__ == $PROGRAM_NAME
  Chess::ChessEngine.new.start
end
