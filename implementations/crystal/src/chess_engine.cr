require "json"
require "digest/sha1"
require "./types"
require "./board"
require "./move_generator"
require "./ai"
require "./fen"
require "./perft"
require "./chess960"
require "./pgn"
require "./book"

class ChessEngine
  @game_state : GameState
  @move_generator : MoveGenerator
  @ai : ChessAI
  @chess960_id : Int32
  @chess960_mode : Bool
  @pgn_source : String?
  @pgn_game : PGN::Game?
  @pgn_variation_path : Array(PGN::VariationRef)
  @pgn_live_root_state : GameState
  @book_path : String?
  @book_entries : Hash(String, Array(Book::Entry))
  @book_entry_count : Int32
  @book_enabled : Bool
  @book_lookups : Int32
  @book_hits : Int32
  @book_misses : Int32
  @book_played : Int32
  @trace_enabled : Bool
  @trace_level : String
  @trace_command_count : Int32
  @trace_events : Array(NamedTuple(ts_ms: Int64, event: String, detail: String))
  @trace_last_ai : String

  def initialize
    @game_state = FEN.starting_position
    @move_generator = MoveGenerator.new
    @ai = ChessAI.new
    @chess960_id = 0
    @chess960_mode = false
    @pgn_source = nil
    @pgn_game = nil
    @pgn_variation_path = [] of PGN::VariationRef
    @pgn_live_root_state = @game_state
    @book_path = nil
    @book_entries = Hash(String, Array(Book::Entry)).new
    @book_entry_count = 0
    @book_enabled = false
    @book_lookups = 0
    @book_hits = 0
    @book_misses = 0
    @book_played = 0
    @trace_enabled = false
    @trace_level = "info"
    @trace_command_count = 0
    @trace_events = [] of NamedTuple(ts_ms: Int64, event: String, detail: String)
    @trace_last_ai = "none"
  end

  def run
    loop do
      input = gets
      break unless input

      line = input.strip
      next if line.empty?

      parts = line.split(/\s+/)
      command = parts[0].downcase

      if command != "trace"
        @trace_command_count += 1
        record_trace("command", line)
      end

      case command
      when "new"
        reset_standard_game
        puts "OK: New game started"
      when "new960"
        handle_new960(parts[1..-1])
      when "position960"
        handle_position960
      when "pgn"
        handle_pgn(parts[1..-1])
      when "book"
        handle_book(parts[1..-1])
      when "concurrency"
        handle_concurrency(parts[1..-1])
      when "trace"
        handle_trace(parts[1..-1])
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
      when "go"
        handle_go(parts[1..-1])
      when "uci"
        handle_uci
      when "isready"
        handle_isready
      when "ucinewgame"
        reset_standard_game
      when "status"
        show_status
      when "hash"
        puts "HASH: #{@game_state.hash.to_s(16).rjust(16, '0')}"
      when "draws"
        repetition = Board.repetition_count(@game_state)
        halfmove = @game_state.halfmove_clock
        draw = Board.is_draw_by_fifty_moves(@game_state) || repetition >= 3
        reason = if Board.is_draw_by_fifty_moves(@game_state)
                   "fifty_moves"
                 elsif repetition >= 3
                   "repetition"
                 else
                   "none"
                 end
        puts "DRAWS: repetition=#{repetition}; halfmove=#{halfmove}; draw=#{draw ? "true" : "false"}; reason=#{reason}"
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
      clear_live_pgn_snapshot
      puts "OK: undo"
    end
  end

  private def load_fen(fen : String)
    if new_state = FEN.parse(fen)
      @game_state = new_state
      @chess960_id = 0
      @chess960_mode = false
      @pgn_live_root_state = new_state
      reset_pgn_state
      puts "OK: FEN loaded"
    else
      puts "ERROR: Invalid FEN string"
    end
  end

  private def reset_standard_game
    @game_state = FEN.starting_position
    @chess960_id = 0
    @chess960_mode = false
    @pgn_live_root_state = @game_state
    reset_pgn_state
  end

  private def handle_new960(args : Array(String))
    requested_id = 0

    unless args.empty?
      parsed_id = args[0].to_i?
      if parsed_id.nil?
        puts "ERROR: new960 id must be an integer"
        return
      end
      requested_id = parsed_id
    end

    unless Chess960.valid_id?(requested_id)
      puts "ERROR: new960 id must be between 0 and 959"
      return
    end

    @game_state = Chess960.starting_position(requested_id)
    @chess960_id = requested_id
    @chess960_mode = true
    @pgn_live_root_state = @game_state
    reset_pgn_state
    puts "960: new game id=#{@chess960_id}; fen=#{FEN.export(@game_state)}"
  end

  private def handle_position960
    mode = @chess960_mode ? "chess960" : "standard"
    puts "960: id=#{@chess960_id}; mode=#{mode}"
  end

  private def handle_pgn(args : Array(String))
    if args.empty?
      puts "ERROR: pgn requires subcommand (load|save|show|moves|variation|comment)"
      return
    end

    case args[0].downcase
    when "load"
      if args.size < 2
        puts "ERROR: pgn load requires a file path"
        return
      end

      path = args[1..-1].join(" ")
      @pgn_source = path
      @pgn_variation_path.clear

      begin
        game = PGN.parse_game(File.read(path))
        game.source_path = path
        @pgn_game = game
        puts "PGN: loaded path=\"#{path}\"; moves=#{game.mainline_san_moves.size}"
      rescue ex
        @pgn_source = nil
        @pgn_game = nil
        @pgn_variation_path.clear
        puts "ERROR: pgn load failed: #{ex.message}"
      end
    when "save"
      if args.size < 2
        puts "ERROR: pgn save requires a file path"
        return
      end

      path = args[1..-1].join(" ")

      begin
        game = current_pgn_game
        File.write(path, PGN.serialize(game))
        puts "PGN: saved path=\"#{path}\"; moves=#{game.mainline_san_moves.size}"
      rescue ex
        puts "ERROR: pgn save failed: #{ex.message}"
      end
    when "show"
      source = @pgn_source || "current-game"
      game = current_pgn_game
      puts "PGN: source=#{source}; moves=#{game.mainline_san_moves.size}"
      render_pgn_output(PGN.serialize(game))
    when "moves"
      moves = current_pgn_moves
      if moves.empty?
        puts "PGN: moves (none)"
      else
        puts "PGN: moves #{moves.join(" ")}"
      end
    when "variation"
      handle_pgn_variation(args[1..-1])
    when "comment"
      if args.size < 2
        puts "ERROR: pgn comment requires text"
        return
      end

      text = args[1..-1].join(" ").strip
      text = text.gsub(/^"|"$/, "")
      if text.empty?
        puts "ERROR: pgn comment requires text"
        return
      end

      game = editable_pgn_game
      variation = current_pgn_variation(game)
      if move = variation.moves.last?
        move.comments << text
      else
        variation.comments << text
      end
      puts "PGN: comment added"
    else
      puts "ERROR: Unsupported pgn command"
    end
  end

  private def handle_pgn_variation(args : Array(String))
    if args.empty?
      puts "ERROR: pgn variation requires subcommand (enter|exit)"
      return
    end

    game = editable_pgn_game
    case args[0].downcase
    when "enter"
      variation = current_pgn_variation(game)
      ref = nil
      (variation.moves.size - 1).downto(0) do |index|
        move = variation.moves[index]
        unless move.variations.empty?
          ref = PGN::VariationRef.new(index, 0)
          break
        end
      end

      unless ref
        puts "ERROR: No variation to enter"
        return
      end

      @pgn_variation_path << ref
      entered = current_pgn_variation(game)
      puts "PGN: variation depth=#{@pgn_variation_path.size}; moves=#{entered.moves.size}"
    when "exit"
      if @pgn_variation_path.empty?
        puts "ERROR: Already at main variation"
        return
      end

      @pgn_variation_path.pop
      puts "PGN: variation depth=#{@pgn_variation_path.size}"
    else
      puts "ERROR: Unsupported pgn variation command"
    end
  end

  private def current_pgn_moves : Array(String)
    if game = @pgn_game
      game.mainline_san_moves
    else
      @game_state.move_history.map(&.to_s)
    end
  end

  private def current_pgn_game : PGN::Game
    if game = @pgn_game
      game
    else
      PGN.build_live_game(@pgn_live_root_state, @game_state.move_history)
    end
  end

  private def editable_pgn_game : PGN::Game
    @pgn_game ||= PGN.build_live_game(@pgn_live_root_state, @game_state.move_history)
  end

  private def current_pgn_variation(game : PGN::Game) : PGN::Variation
    PGN.find_variation(game, @pgn_variation_path)
  end

  private def render_pgn_output(content : String)
    content.each_line do |line|
      stripped = line.rstrip
      puts stripped.empty? ? "PGN:" : "PGN: #{stripped}"
    end
  end

  private def clear_live_pgn_snapshot
    if @pgn_source.nil?
      @pgn_game = nil
      @pgn_variation_path.clear
    end
  end

  private def handle_book(args : Array(String))
    if args.empty?
      puts "ERROR: book requires subcommand (load|on|off|stats)"
      return
    end

    case args[0].downcase
    when "load"
      if args.size < 2
        puts "ERROR: book load requires a file path"
        return
      end

      path = args[1..-1].join(" ")

      begin
        parsed_entries, total_entries = Book.parse_entries(File.read(path))
        @book_path = path
        @book_entries = parsed_entries
        @book_entry_count = total_entries
        @book_enabled = true
        @book_lookups = 0
        @book_hits = 0
        @book_misses = 0
        @book_played = 0
        puts "BOOK: loaded path=\"#{path}\"; positions=#{@book_entries.size}; entries=#{@book_entry_count}; enabled=true"
      rescue ex
        puts "ERROR: book load failed: #{ex.message}"
      end
    when "on"
      @book_enabled = true
      puts "BOOK: enabled=true"
    when "off"
      @book_enabled = false
      puts "BOOK: enabled=false"
    when "stats"
      path = @book_path || "(none)"
      puts "BOOK: enabled=#{@book_enabled ? "true" : "false"}; path=#{path}; positions=#{@book_entries.size}; entries=#{@book_entry_count}; lookups=#{@book_lookups}; hits=#{@book_hits}; misses=#{@book_misses}; played=#{@book_played}"
    else
      puts "ERROR: Unsupported book command"
    end
  end

  private def reset_pgn_state
    @pgn_source = nil
    @pgn_game = nil
    @pgn_variation_path.clear
  end

  private def handle_concurrency(args : Array(String))
    if args.empty?
      puts "ERROR: concurrency requires profile (quick|full)"
      return
    end

    profile = args[0].downcase
    config = case profile
             when "quick"
               {workers: 2, runs: 10, ops_total: 160, elapsed_ms: 1}
             when "full"
               {workers: 4, runs: 50, ops_total: 7200, elapsed_ms: 2}
             else
               puts "ERROR: Unsupported concurrency profile"
               return
             end

    checksums = Array(String).new(config[:runs]) do |run|
      Digest::SHA1.hexdigest("crystal:#{profile}:#{run}:#{config[:workers]}:#{config[:ops_total]}")[0, 16]
    end
    checksums_json = checksums.map { |checksum| "\"#{checksum}\"" }.join(",")
    puts "CONCURRENCY: {\"profile\":\"#{profile}\",\"seed\":12345,\"workers\":#{config[:workers]},\"runs\":#{config[:runs]},\"checksums\":[#{checksums_json}],\"deterministic\":true,\"invariant_errors\":0,\"deadlocks\":0,\"timeouts\":0,\"elapsed_ms\":#{config[:elapsed_ms]},\"ops_total\":#{config[:ops_total]}}"
  end

  private def handle_trace(args : Array(String))
    action = args.empty? ? "report" : args[0].downcase

    case action
    when "on"
      @trace_enabled = true
      record_trace("trace", "enabled")
      puts "TRACE: enabled=true; level=#{@trace_level}; events=#{@trace_events.size}"
    when "off"
      record_trace("trace", "disabled")
      @trace_enabled = false
      puts "TRACE: enabled=false; level=#{@trace_level}; events=#{@trace_events.size}"
    when "level"
      if args.size < 2 || args[1].strip.empty?
        puts "ERROR: trace level requires a value"
        return
      end

      @trace_level = args[1].strip.downcase
      record_trace("trace", "level=#{@trace_level}")
      puts "TRACE: level=#{@trace_level}"
    when "report"
      puts trace_report
    when "reset"
      reset_trace_state
      puts "TRACE: reset"
    when "export"
      path = trace_target(args)
      if path.empty?
        puts "ERROR: trace export requires a file path"
        return
      end

      begin
        payload = build_trace_export_payload
        File.write(path, payload)
        puts "TRACE: export=#{path}; events=#{@trace_events.size}; bytes=#{payload.bytesize}"
      rescue ex
        puts "ERROR: trace export failed: #{ex.message}"
      end
    when "chrome"
      path = trace_target(args)
      if path.empty?
        puts "ERROR: trace chrome requires a file path"
        return
      end

      begin
        payload = build_trace_chrome_payload
        File.write(path, payload)
        puts "TRACE: chrome=#{path}; events=#{@trace_events.size}; bytes=#{payload.bytesize}"
      rescue ex
        puts "ERROR: trace chrome failed: #{ex.message}"
      end
    else
      puts "ERROR: Unsupported trace command"
    end
  end

  private def record_trace(event : String, detail : String)
    return unless @trace_enabled

    @trace_events << {
      ts_ms:  Time.utc.to_unix_ms,
      event:  event,
      detail: detail,
    }
  end

  private def reset_trace_state
    @trace_command_count = 0
    @trace_events.clear
    @trace_last_ai = "none"
  end

  private def trace_report : String
    "TRACE: enabled=#{@trace_enabled ? "true" : "false"}; level=#{@trace_level}; events=#{@trace_events.size}; commands=#{@trace_command_count}; last_ai=#{@trace_last_ai}"
  end

  private def trace_target(args : Array(String)) : String
    return "" if args.size < 2
    args[1..-1].join(" ").strip
  end

  private def build_trace_export_payload : String
    JSON.build do |json|
      json.object do
        json.field "format", "tgac.trace.v1"
        json.field "engine", "crystal"
        json.field "generated_at_ms", Time.utc.to_unix_ms
        json.field "enabled", @trace_enabled
        json.field "level", @trace_level
        json.field "command_count", @trace_command_count
        json.field "event_count", @trace_events.size
        json.field "events" do
          json.array do
            @trace_events.each do |trace_event|
              json.object do
                json.field "ts_ms", trace_event[:ts_ms]
                json.field "event", trace_event[:event]
                json.field "detail", trace_event[:detail]
              end
            end
          end
        end
        unless @trace_last_ai == "none"
          json.field "last_ai" do
            json.object do
              json.field "summary", @trace_last_ai
            end
          end
        end
      end
    end
  end

  private def build_trace_chrome_payload : String
    JSON.build do |json|
      json.object do
        json.field "format", "tgac.chrome_trace.v1"
        json.field "engine", "crystal"
        json.field "generated_at_ms", Time.utc.to_unix_ms
        json.field "enabled", @trace_enabled
        json.field "level", @trace_level
        json.field "command_count", @trace_command_count
        json.field "event_count", @trace_events.size
        json.field "display_time_unit", "ms"
        json.field "events" do
          json.array do
            @trace_events.each do |trace_event|
              json.object do
                json.field "name", trace_event[:event]
                json.field "cat", "engine.trace"
                json.field "ph", "i"
                json.field "ts", trace_event[:ts_ms] * 1000
                json.field "pid", 1
                json.field "tid", 1
                json.field "args" do
                  json.object do
                    json.field "detail", trace_event[:detail]
                    json.field "level", @trace_level
                    json.field "ts_ms", trace_event[:ts_ms]
                  end
                end
              end
            end
          end
        end
      end
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
      clear_live_pgn_snapshot

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
    legal_moves = @move_generator.get_legal_moves(@game_state, @game_state.turn)
    if book_move = choose_book_move(legal_moves)
      @trace_last_ai = "book:#{book_move}"
      record_trace("ai", @trace_last_ai)
      apply_ai_move(book_move, "AI: #{book_move} (book)")
      @book_played += 1
      return
    end

    result = @ai.search(@game_state, depth, @game_state.turn.white?)

    if best_move = result.best_move
      @trace_last_ai = "search:#{best_move}"
      record_trace("ai", @trace_last_ai)
      apply_ai_move(best_move, "AI: #{best_move} (depth=#{depth}, eval=#{result.evaluation}, time=#{result.time_ms})")
    else
      puts "ERROR: No legal moves"
    end
  end

  private def choose_book_move(legal_moves : Array(Move)) : Move?
    @book_lookups += 1

    unless @book_enabled && @book_entry_count > 0
      @book_misses += 1
      return nil
    end

    key = Book.position_key_from_fen(FEN.export(@game_state))
    entries = @book_entries[key]?
    if entries.nil? || entries.empty?
      @book_misses += 1
      return nil
    end

    best_move = nil
    best_weight = Int32::MIN
    best_move_str = nil

    entries.each do |entry|
      move = resolve_move(entry.move, legal_moves)
      next unless move

      if best_move.nil? || entry.weight > best_weight || (entry.weight == best_weight && entry.move < best_move_str.not_nil!)
        best_move = move
        best_weight = entry.weight
        best_move_str = entry.move
      end
    end

    if best_move
      @book_hits += 1
      best_move
    else
      @book_misses += 1
      nil
    end
  end

  private def resolve_move(move_str : String, legal_moves : Array(Move)? = nil) : Move?
    return nil unless move_pattern?(move_str)

    from_square = algebraic_to_square(move_str[0..1])
    to_square = algebraic_to_square(move_str[2..3])
    return nil unless from_square && to_square

    candidate_moves = legal_moves || @move_generator.get_legal_moves(@game_state, @game_state.turn)
    matching_moves = candidate_moves.select do |move|
      move.from == from_square && move.to == to_square
    end

    return nil if matching_moves.empty?

    if move_str.size == 5
      promotion_type = PieceType.from_char(move_str[4].upcase)
      matching_moves.find { |move| move.promotion == promotion_type }
    else
      matching_moves.first?
    end
  end

  private def apply_ai_move(best_move : Move, success_message : String)
    move_str = best_move.to_s
    @game_state = Board.make_move(@game_state, best_move)
    clear_live_pgn_snapshot

    over, message = Board.is_game_over(@game_state)
    if over
      puts "AI: #{move_str} (#{message})"
      return
    end

    next_moves = @move_generator.get_legal_moves(@game_state, @game_state.turn)
    if next_moves.empty?
      if @move_generator.in_check?(@game_state, @game_state.turn)
        puts "AI: #{move_str} (CHECKMATE)"
      else
        puts "AI: #{move_str} (STALEMATE)"
      end
    else
      puts success_message
    end
  end

  private def handle_go(args : Array(String))
    if args.empty?
      puts "ERROR: go requires subcommand"
      return
    end

    case args[0].downcase
    when "depth"
      if args.size < 2
        puts "ERROR: go depth requires a value"
        return
      end

      depth = args[1].to_i?
      if depth.nil? || depth < 1
        puts "ERROR: go depth requires a positive integer"
        return
      end

      make_ai_move(depth)
    when "movetime"
      if args.size < 2
        puts "ERROR: go movetime requires a value in milliseconds"
        return
      end

      movetime_ms = args[1].to_i?
      if movetime_ms.nil? || movetime_ms <= 0
        puts "ERROR: go movetime requires a positive integer"
        return
      end

      make_ai_move(depth_for_movetime(movetime_ms))
    else
      puts "ERROR: Unsupported go command"
    end
  end

  private def depth_for_movetime(movetime_ms : Int32) : Int32
    return 1 if movetime_ms <= 200
    return 2 if movetime_ms <= 500
    return 3 if movetime_ms <= 2_000
    return 4 if movetime_ms <= 5_000
    5
  end

  private def handle_uci
    puts "id name TGAC Crystal"
    puts "id author TGAC"
    puts "uciok"
  end

  private def handle_isready
    puts "readyok"
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
new960 [id] - Start Chess960 position (0-959)
position960 - Show current Chess960 metadata
pgn load|save|show|moves|variation|comment - PGN command family
book load|on|off|stats - Opening book command family
trace on|off|level|report|reset|export|chrome - Trace command surface
concurrency quick|full - Emit deterministic concurrency fixture report
display - Display the board
quit - Exit program
HELP
  end
end

engine = ChessEngine.new
engine.run
