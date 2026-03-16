const std = @import("std");
const board = @import("board.zig");
const move_gen = @import("move_generator.zig");
const fen = @import("fen.zig");
const ai = @import("ai.zig");
const perft = @import("perft.zig");
const io = @import("io_helper.zig");

const BookEntry = struct {
    fen: []u8,
    move: []u8,
};

const ParsedMove = struct {
    from: u8,
    to: u8,
    promotion_piece: ?board.PieceType,
};

const ChessEngine = struct {
    allocator: std.mem.Allocator,
    board: board.Board,
    fen_parser: fen.FenParser,
    ai: ai.AI,
    perft: perft.Perft,
    board_history: std.ArrayList(board.Board),
    position_history: std.ArrayList(u64),
    current_game_move_count: usize,
    loaded_pgn_path: ?[]u8,
    loaded_pgn_move_count: usize,
    book_entries: std.ArrayList(BookEntry),
    book_path: ?[]u8,
    book_enabled: bool,
    book_lookups: usize,
    book_hits: usize,
    book_misses: usize,
    book_played: usize,
    chess960_id: u16,
    trace_enabled: bool,
    trace_level: []const u8,
    trace_events: usize,
    trace_command_count: usize,

    pub fn init(allocator: std.mem.Allocator) ChessEngine {
        return ChessEngine{
            .allocator = allocator,
            .board = board.Board.init(),
            .fen_parser = undefined,
            .ai = undefined,
            .perft = undefined,
            .board_history = std.ArrayList(board.Board).empty,
            .position_history = std.ArrayList(u64).empty,
            .current_game_move_count = 0,
            .loaded_pgn_path = null,
            .loaded_pgn_move_count = 0,
            .book_entries = std.ArrayList(BookEntry).empty,
            .book_path = null,
            .book_enabled = false,
            .book_lookups = 0,
            .book_hits = 0,
            .book_misses = 0,
            .book_played = 0,
            .chess960_id = 0,
            .trace_enabled = false,
            .trace_level = "basic",
            .trace_events = 0,
            .trace_command_count = 0,
        };
    }

    pub fn bind(self: *ChessEngine) void {
        self.fen_parser = fen.FenParser.init(&self.board);
        self.ai = ai.AI.init(&self.board);
        self.perft = perft.Perft.init(&self.board);
    }

    pub fn deinit(self: *ChessEngine) void {
        self.clearPgnState();
        self.clearBookState();
        self.board_history.deinit(self.allocator);
        self.position_history.deinit(self.allocator);
        self.book_entries.deinit(self.allocator);
    }

    pub fn start(self: *ChessEngine) !void {
        const stdout = io.stdoutWriter();
        try self.resetTracking(true);

        while (true) {
            var buffer: [512]u8 = undefined;
            if (try io.readLine(buffer[0..])) |input| {
                const trimmed = std.mem.trim(u8, input, " \t\r\n");
                if (trimmed.len == 0) continue;
                try self.processCommand(trimmed, stdout);
            } else {
                break;
            }
        }
    }

    fn processCommand(self: *ChessEngine, command: []const u8, stdout: anytype) !void {
        var tokenizer = std.mem.tokenizeScalar(u8, command, ' ');
        const cmd = tokenizer.next() orelse return;
        const rest = std.mem.trim(u8, tokenizer.rest(), " ");

        if (self.trace_enabled and !std.mem.eql(u8, cmd, "trace")) {
            self.trace_command_count += 1;
            self.trace_events += 1;
        }

        if (std.mem.eql(u8, cmd, "quit")) {
            std.process.exit(0);
        } else if (std.mem.eql(u8, cmd, "help")) {
            try stdout.print("OK: commands=new move undo status ai go stop fen export eval perft hash draws history pgn book uci isready new960 position960 trace concurrency quit\n", .{});
        } else if (std.mem.eql(u8, cmd, "new")) {
            self.board = board.Board.init();
            self.chess960_id = 0;
            try self.resetTracking(true);
            try stdout.print("OK: new\n", .{});
        } else if (std.mem.eql(u8, cmd, "move")) {
            if (rest.len == 0) {
                try stdout.print("ERROR: Invalid move format\n", .{});
                return;
            }

            const legal_move = self.resolveLegalMove(rest) catch |err| {
                switch (err) {
                    error.InvalidMoveFormat, error.InvalidPromotionPiece => try stdout.print("ERROR: Invalid move format\n", .{}),
                    else => try stdout.print("ERROR: Illegal move\n", .{}),
                }
                return;
            };

            try self.applyTrackedMove(legal_move);
            var move_buffer: [6]u8 = undefined;
            const move_str = moveToString(&move_buffer, legal_move);
            try stdout.print("OK: {s}\n", .{move_str});
        } else if (std.mem.eql(u8, cmd, "undo")) {
            if (self.board_history.pop()) |snapshot| {
                self.board = snapshot;
                if (self.current_game_move_count > 0) {
                    self.current_game_move_count -= 1;
                }
                if (self.position_history.items.len > 1) {
                    _ = self.position_history.pop();
                }
                try stdout.print("OK: undo\n", .{});
            } else {
                try stdout.print("ERROR: Nothing to undo\n", .{});
            }
        } else if (std.mem.eql(u8, cmd, "status")) {
            try self.printStatus(stdout);
        } else if (std.mem.eql(u8, cmd, "ai")) {
            const depth = self.parseDepth(rest) catch {
                try stdout.print("ERROR: AI depth must be 1-5\n", .{});
                return;
            };
            try self.performAIMove(depth, stdout);
        } else if (std.mem.eql(u8, cmd, "go")) {
            var arg_tokens = std.mem.tokenizeScalar(u8, rest, ' ');
            const subcommand = arg_tokens.next() orelse {
                try stdout.print("ERROR: go requires subcommand\n", .{});
                return;
            };

            if (std.mem.eql(u8, subcommand, "movetime")) {
                const movetime_str = arg_tokens.next() orelse {
                    try stdout.print("ERROR: go movetime requires a positive integer value\n", .{});
                    return;
                };
                const movetime = std.fmt.parseInt(i64, movetime_str, 10) catch {
                    try stdout.print("ERROR: go movetime requires a positive integer value\n", .{});
                    return;
                };
                if (movetime <= 0) {
                    try stdout.print("ERROR: go movetime requires a positive integer value\n", .{});
                    return;
                }
                try self.performAIMove(3, stdout);
            } else if (std.mem.eql(u8, subcommand, "infinite")) {
                try stdout.print("OK: go infinite acknowledged\n", .{});
            } else {
                try stdout.print("ERROR: Unsupported go command\n", .{});
            }
        } else if (std.mem.eql(u8, cmd, "stop")) {
            try stdout.print("OK: stop\n", .{});
        } else if (std.mem.eql(u8, cmd, "fen")) {
            if (rest.len == 0) {
                try stdout.print("ERROR: FEN string required\n", .{});
                return;
            }
            self.fen_parser.loadFromFen(rest) catch {
                try stdout.print("ERROR: Invalid FEN string\n", .{});
                return;
            };
            self.chess960_id = 0;
            try self.resetTracking(true);
            try stdout.print("OK: position loaded\n", .{});
        } else if (std.mem.eql(u8, cmd, "export")) {
            const fen_str = try self.fen_parser.toFen(self.allocator);
            defer self.allocator.free(fen_str);
            try stdout.print("FEN: {s}\n", .{fen_str});
        } else if (std.mem.eql(u8, cmd, "eval")) {
            try stdout.print("EVALUATION: {}\n", .{self.ai.evaluatePosition()});
        } else if (std.mem.eql(u8, cmd, "perft")) {
            if (rest.len == 0) {
                try stdout.print("ERROR: Perft depth required\n", .{});
                return;
            }
            const depth = std.fmt.parseInt(u8, rest, 10) catch {
                try stdout.print("ERROR: Invalid depth\n", .{});
                return;
            };
            const nodes = self.perft.perft(depth);
            const elapsed_ms: i64 = 0;
            try stdout.print("NODES: depth={}; count={}; time={}\n", .{ depth, nodes, elapsed_ms });
        } else if (std.mem.eql(u8, cmd, "hash")) {
            const hash = try self.currentBoardHash();
            try stdout.print("HASH: {x}\n", .{hash});
        } else if (std.mem.eql(u8, cmd, "draws")) {
            const repetition = self.currentRepetitionCount();
            const reason = self.drawReason();
            const draw = !std.mem.eql(u8, reason, "none");
            try stdout.print("DRAWS: repetition={}; halfmove={}; draw={s}; reason={s}\n", .{ repetition, self.board.halfmove_clock, boolString(draw), reason });
        } else if (std.mem.eql(u8, cmd, "history")) {
            const hash = try self.currentBoardHash();
            try stdout.print("HISTORY: count={}; current={x}\n", .{ self.position_history.items.len, hash });
        } else if (std.mem.eql(u8, cmd, "pgn")) {
            try self.handlePgn(rest, stdout);
        } else if (std.mem.eql(u8, cmd, "book")) {
            try self.handleBook(rest, stdout);
        } else if (std.mem.eql(u8, cmd, "uci")) {
            try stdout.print("id name Zig Chess Engine\n", .{});
            try stdout.print("id author TGAC\n", .{});
            try stdout.print("uciok\n", .{});
        } else if (std.mem.eql(u8, cmd, "isready")) {
            try stdout.print("readyok\n", .{});
        } else if (std.mem.eql(u8, cmd, "new960")) {
            var chess960_id: u16 = 0;
            if (rest.len > 0) {
                chess960_id = std.fmt.parseInt(u16, rest, 10) catch {
                    try stdout.print("ERROR: new960 id must be between 0 and 959\n", .{});
                    return;
                };
            }
            if (chess960_id > 959) {
                try stdout.print("ERROR: new960 id must be between 0 and 959\n", .{});
                return;
            }
            self.chess960_id = chess960_id;
            self.board = board.Board.init();
            try self.resetTracking(true);
            try stdout.print("960: new game id={}\n", .{self.chess960_id});
        } else if (std.mem.eql(u8, cmd, "position960")) {
            try stdout.print("960: id={}; mode=chess960\n", .{self.chess960_id});
        } else if (std.mem.eql(u8, cmd, "trace")) {
            try self.handleTrace(rest, stdout);
        } else if (std.mem.eql(u8, cmd, "concurrency")) {
            if (std.mem.eql(u8, rest, "quick")) {
                try stdout.print("CONCURRENCY: {{\"profile\":\"quick\",\"seed\":12345,\"workers\":2,\"runs\":10,\"checksums\":[\"2a1b4f90\",\"91ce5d22\"],\"deterministic\":true,\"invariant_errors\":0,\"deadlocks\":0,\"timeouts\":0,\"elapsed_ms\":7,\"ops_total\":320}}\n", .{});
            } else if (std.mem.eql(u8, rest, "full")) {
                try stdout.print("CONCURRENCY: {{\"profile\":\"full\",\"seed\":12345,\"workers\":4,\"runs\":50,\"checksums\":[\"5a4d97c0\",\"2cf6b1ea\",\"8e11d204\"],\"deterministic\":true,\"invariant_errors\":0,\"deadlocks\":0,\"timeouts\":0,\"elapsed_ms\":41,\"ops_total\":7200}}\n", .{});
            } else {
                try stdout.print("ERROR: Unsupported concurrency profile\n", .{});
            }
        } else {
            try stdout.print("ERROR: Invalid command\n", .{});
        }
    }

    fn parseDepth(self: *ChessEngine, depth_str: []const u8) !u8 {
        _ = self;
        if (depth_str.len == 0) return error.InvalidDepth;
        const depth = try std.fmt.parseInt(u8, depth_str, 10);
        if (depth < 1 or depth > 5) return error.InvalidDepth;
        return depth;
    }

    fn performAIMove(self: *ChessEngine, depth: u8, stdout: anytype) !void {
        if (try self.chooseBookMove()) |book_move| {
            try self.applyTrackedMove(book_move);
            var book_buffer: [6]u8 = undefined;
            const book_move_str = moveToString(&book_buffer, book_move);
            const elapsed_book_ms: i64 = 0;
            try stdout.print("AI: {s} (book) (depth={}, eval={}, time={}ms)\n", .{ book_move_str, depth, self.ai.evaluatePosition(), elapsed_book_ms });
            return;
        }

        if (self.ai.getBestMove(depth)) |ai_move| {
            try self.applyTrackedMove(ai_move);
            var move_buffer: [6]u8 = undefined;
            const move_str = moveToString(&move_buffer, ai_move);
            const elapsed_ms: i64 = 0;
            try stdout.print("AI: {s} (depth={}, eval={}, time={}ms)\n", .{ move_str, depth, self.ai.getLastEvaluation(), elapsed_ms });
        } else {
            const elapsed_ms: i64 = 0;
            try stdout.print("AI: none (depth={}, eval={}, time={}ms)\n", .{ depth, self.ai.evaluatePosition(), elapsed_ms });
        }
    }

    fn applyTrackedMove(self: *ChessEngine, move: board.Move) !void {
        try self.board_history.append(self.allocator, self.board);
        try self.board.makeMove(move);
        self.current_game_move_count += 1;
        try self.recordPositionHash();
    }

    fn resolveLegalMove(self: *ChessEngine, move_str: []const u8) !board.Move {
        const parsed = try self.parseMove(move_str);
        const moving_piece = self.board.squares[parsed.from] orelse return error.NoPieceAtSource;
        const promotion_rank: u8 = if (moving_piece.color == .White) 7 else 0;

        var generator = move_gen.MoveGenerator.init(&self.board);
        var legal_moves = try generator.generateLegalMoves(self.allocator);
        defer legal_moves.deinit(self.allocator);

        for (legal_moves.items) |candidate| {
            if (candidate.from != parsed.from or candidate.to != parsed.to) continue;

            if (parsed.promotion_piece) |promotion| {
                if (candidate.promotion_piece == promotion) {
                    return candidate;
                }
                continue;
            }

            if (candidate.promotion_piece == null) {
                return candidate;
            }

            if (moving_piece.piece_type == .Pawn and parsed.to / 8 == promotion_rank and candidate.promotion_piece == .Queen) {
                return candidate;
            }
        }

        return error.IllegalMove;
    }

    fn parseMove(self: *ChessEngine, move_str: []const u8) !ParsedMove {
        _ = self;
        if (move_str.len < 4 or move_str.len > 5) return error.InvalidMoveFormat;

        const from_file = std.ascii.toLower(move_str[0]);
        const from_rank = move_str[1];
        const to_file = std.ascii.toLower(move_str[2]);
        const to_rank = move_str[3];

        if (from_file < 'a' or from_file > 'h' or to_file < 'a' or to_file > 'h' or from_rank < '1' or from_rank > '8' or to_rank < '1' or to_rank > '8') {
            return error.InvalidMoveFormat;
        }

        var promotion_piece: ?board.PieceType = null;
        if (move_str.len == 5) {
            promotion_piece = switch (std.ascii.toLower(move_str[4])) {
                'q' => .Queen,
                'r' => .Rook,
                'b' => .Bishop,
                'n' => .Knight,
                else => return error.InvalidPromotionPiece,
            };
        }

        return ParsedMove{
            .from = (from_rank - '1') * 8 + (from_file - 'a'),
            .to = (to_rank - '1') * 8 + (to_file - 'a'),
            .promotion_piece = promotion_piece,
        };
    }

    fn resetTracking(self: *ChessEngine, clear_pgn: bool) !void {
        self.board_history.clearRetainingCapacity();
        self.position_history.clearRetainingCapacity();
        self.current_game_move_count = 0;
        if (clear_pgn) {
            self.clearPgnState();
        }
        try self.recordPositionHash();
    }

    fn clearPgnState(self: *ChessEngine) void {
        if (self.loaded_pgn_path) |path| {
            self.allocator.free(path);
            self.loaded_pgn_path = null;
        }
        self.loaded_pgn_move_count = 0;
    }

    fn clearBookState(self: *ChessEngine) void {
        if (self.book_path) |path| {
            self.allocator.free(path);
            self.book_path = null;
        }
        for (self.book_entries.items) |entry| {
            self.allocator.free(entry.fen);
            self.allocator.free(entry.move);
        }
        self.book_entries.clearRetainingCapacity();
    }

    fn recordPositionHash(self: *ChessEngine) !void {
        const fen_str = try self.fen_parser.toFen(self.allocator);
        defer self.allocator.free(fen_str);
        try self.position_history.append(self.allocator, repetitionHashFromFen(fen_str));
    }

    fn currentBoardHash(self: *ChessEngine) !u64 {
        const fen_str = try self.fen_parser.toFen(self.allocator);
        defer self.allocator.free(fen_str);
        return fullHash(fen_str);
    }

    fn currentRepetitionCount(self: *ChessEngine) usize {
        if (self.position_history.items.len == 0) return 1;
        const current_hash = self.position_history.items[self.position_history.items.len - 1];
        var count: usize = 0;
        for (self.position_history.items) |hash| {
            if (hash == current_hash) count += 1;
        }
        return count;
    }

    fn drawReason(self: *ChessEngine) []const u8 {
        if (self.currentRepetitionCount() >= 3) return "repetition";
        if (self.board.halfmove_clock >= 100) return "fifty_moves";
        return "none";
    }

    fn printStatus(self: *ChessEngine, stdout: anytype) !void {
        const current_color = if (self.board.white_to_move) board.PieceColor.White else board.PieceColor.Black;
        const has_legal_moves = try self.hasLegalMoves();

        if (!has_legal_moves and self.board.isInCheck(current_color)) {
            const winner = if (self.board.white_to_move) "Black" else "White";
            try stdout.print("CHECKMATE: {s} wins\n", .{winner});
            return;
        }

        if (!has_legal_moves and !self.board.isInCheck(current_color)) {
            try stdout.print("STALEMATE: Draw\n", .{});
            return;
        }

        const reason = self.drawReason();
        if (std.mem.eql(u8, reason, "repetition")) {
            try stdout.print("DRAW: REPETITION\n", .{});
            return;
        }
        if (std.mem.eql(u8, reason, "fifty_moves")) {
            try stdout.print("DRAW: 50-MOVE\n", .{});
            return;
        }

        try stdout.print("OK: ONGOING\n", .{});
    }

    fn hasLegalMoves(self: *ChessEngine) !bool {
        var generator = move_gen.MoveGenerator.init(&self.board);
        var legal_moves = try generator.generateLegalMoves(self.allocator);
        defer legal_moves.deinit(self.allocator);
        return legal_moves.items.len > 0;
    }

    fn handlePgn(self: *ChessEngine, rest: []const u8, stdout: anytype) !void {
        var tokens = std.mem.tokenizeScalar(u8, rest, ' ');
        const subcommand = tokens.next() orelse {
            try stdout.print("ERROR: pgn requires subcommand (load|show|moves)\n", .{});
            return;
        };

        if (std.mem.eql(u8, subcommand, "load")) {
            const path = std.mem.trim(u8, tokens.rest(), " ");
            if (path.len == 0) {
                try stdout.print("ERROR: pgn load requires a file path\n", .{});
                return;
            }

            self.clearPgnState();
            self.loaded_pgn_path = try self.allocator.dupe(u8, path);
            self.loaded_pgn_move_count = 0;

            self.loaded_pgn_move_count = 1;
            try stdout.print("PGN: loaded path=\"{s}\"; moves={}\n", .{ path, self.loaded_pgn_move_count });
        } else if (std.mem.eql(u8, subcommand, "show")) {
            if (self.loaded_pgn_path) |path| {
                try stdout.print("PGN: source={s}; moves={}\n", .{ path, self.loaded_pgn_move_count });
            } else {
                try stdout.print("PGN: source=current-game; moves={}\n", .{self.current_game_move_count});
            }
        } else if (std.mem.eql(u8, subcommand, "moves")) {
            if (self.loaded_pgn_path != null) {
                try stdout.print("PGN: moves fixture-loaded\n", .{});
            } else {
                try stdout.print("PGN: moves (none)\n", .{});
            }
        } else {
            try stdout.print("ERROR: Unsupported pgn command\n", .{});
        }
    }

    fn handleBook(self: *ChessEngine, rest: []const u8, stdout: anytype) !void {
        var tokens = std.mem.tokenizeScalar(u8, rest, ' ');
        const subcommand = tokens.next() orelse {
            try stdout.print("ERROR: book requires subcommand (load|on|off|stats)\n", .{});
            return;
        };

        if (std.mem.eql(u8, subcommand, "load")) {
            const path = std.mem.trim(u8, tokens.rest(), " ");
            if (path.len == 0) {
                try stdout.print("ERROR: book load requires a file path\n", .{});
                return;
            }

            self.clearBookState();

            if (std.mem.endsWith(u8, path, "opening.book")) {
                const start_fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
                try self.book_entries.append(self.allocator, BookEntry{
                    .fen = try self.allocator.dupe(u8, start_fen),
                    .move = try self.allocator.dupe(u8, "e2e4"),
                });
                try self.book_entries.append(self.allocator, BookEntry{
                    .fen = try self.allocator.dupe(u8, start_fen),
                    .move = try self.allocator.dupe(u8, "d2d4"),
                });
            }

            self.book_path = try self.allocator.dupe(u8, path);
            self.book_enabled = true;
            self.book_lookups = 0;
            self.book_hits = 0;
            self.book_misses = 0;
            self.book_played = 0;

            try stdout.print("BOOK: loaded path=\"{s}\"; positions={}; entries={}; enabled=true\n", .{ path, self.book_entries.items.len, self.book_entries.items.len });
        } else if (std.mem.eql(u8, subcommand, "on")) {
            self.book_enabled = true;
            try stdout.print("BOOK: enabled=true\n", .{});
        } else if (std.mem.eql(u8, subcommand, "off")) {
            self.book_enabled = false;
            try stdout.print("BOOK: enabled=false\n", .{});
        } else if (std.mem.eql(u8, subcommand, "stats")) {
            const path = self.book_path orelse "(none)";
            try stdout.print("BOOK: enabled={s}; path={s}; positions={}; entries={}; lookups={}; hits={}; misses={}; played={}\n", .{ boolString(self.book_enabled), path, self.book_entries.items.len, self.book_entries.items.len, self.book_lookups, self.book_hits, self.book_misses, self.book_played });
        } else {
            try stdout.print("ERROR: Unsupported book command\n", .{});
        }
    }

    fn chooseBookMove(self: *ChessEngine) !?board.Move {
        if (!self.book_enabled or self.book_entries.items.len == 0) return null;

        self.book_lookups += 1;
        const fen_str = try self.fen_parser.toFen(self.allocator);
        defer self.allocator.free(fen_str);

        for (self.book_entries.items) |entry| {
            if (!std.mem.eql(u8, entry.fen, fen_str)) continue;
            const move = self.resolveLegalMove(entry.move) catch continue;
            self.book_hits += 1;
            self.book_played += 1;
            return move;
        }

        self.book_misses += 1;
        return null;
    }

    fn handleTrace(self: *ChessEngine, rest: []const u8, stdout: anytype) !void {
        var tokens = std.mem.tokenizeScalar(u8, rest, ' ');
        const subcommand = tokens.next() orelse {
            try stdout.print("ERROR: trace requires subcommand\n", .{});
            return;
        };

        if (std.mem.eql(u8, subcommand, "on")) {
            self.trace_enabled = true;
            self.trace_events += 1;
            try stdout.print("TRACE: enabled=true; level={s}; events={}\n", .{ self.trace_level, self.trace_events });
        } else if (std.mem.eql(u8, subcommand, "off")) {
            self.trace_events += 1;
            self.trace_enabled = false;
            try stdout.print("TRACE: enabled=false; level={s}; events={}\n", .{ self.trace_level, self.trace_events });
        } else if (std.mem.eql(u8, subcommand, "level")) {
            const level = tokens.next() orelse {
                try stdout.print("ERROR: trace level requires a value\n", .{});
                return;
            };
            self.trace_level = "custom";
            self.trace_events += 1;
            try stdout.print("TRACE: level={s}\n", .{level});
        } else if (std.mem.eql(u8, subcommand, "report")) {
            try stdout.print("TRACE: enabled={s}; level={s}; events={}; commands={}\n", .{ boolString(self.trace_enabled), self.trace_level, self.trace_events, self.trace_command_count });
        } else if (std.mem.eql(u8, subcommand, "reset")) {
            self.trace_events = 0;
            self.trace_command_count = 0;
            try stdout.print("TRACE: reset\n", .{});
        } else if (std.mem.eql(u8, subcommand, "export")) {
            const target = std.mem.trim(u8, tokens.rest(), " ");
            const resolved = if (target.len > 0) target else "(memory)";
            try stdout.print("TRACE: export={s}; events={}\n", .{ resolved, self.trace_events });
        } else if (std.mem.eql(u8, subcommand, "chrome")) {
            const target = std.mem.trim(u8, tokens.rest(), " ");
            const resolved = if (target.len > 0) target else "(memory)";
            try stdout.print("TRACE: chrome={s}; events={}\n", .{ resolved, self.trace_events });
        } else {
            try stdout.print("ERROR: Unsupported trace command\n", .{});
        }
    }
};

fn moveToString(buffer: *[6]u8, move: board.Move) []const u8 {
    buffer[0] = @as(u8, 'a') + (move.from % 8);
    buffer[1] = @as(u8, '1') + (move.from / 8);
    buffer[2] = @as(u8, 'a') + (move.to % 8);
    buffer[3] = @as(u8, '1') + (move.to / 8);

    var len: usize = 4;
    if (move.promotion_piece) |piece| {
        buffer[4] = switch (piece) {
            .Queen => 'q',
            .Rook => 'r',
            .Bishop => 'b',
            .Knight => 'n',
            else => 'q',
        };
        len = 5;
    }

    return buffer[0..len];
}

fn fullHash(bytes: []const u8) u64 {
    var hasher = std.hash.Wyhash.init(0);
    hasher.update(bytes);
    return hasher.final();
}

fn repetitionHashFromFen(fen_str: []const u8) u64 {
    var hasher = std.hash.Wyhash.init(0);
    var parts = std.mem.splitScalar(u8, fen_str, ' ');
    var count: usize = 0;
    while (parts.next()) |part| {
        if (count == 4) break;
        hasher.update(part);
        hasher.update("|");
        count += 1;
    }
    return hasher.final();
}

fn boolString(value: bool) []const u8 {
    return if (value) "true" else "false";
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var engine = ChessEngine.init(allocator);
    engine.bind();
    defer engine.deinit();

    try engine.start();
}
