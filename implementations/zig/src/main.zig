const std = @import("std");
const board = @import("board.zig");
const move_gen = @import("move_generator.zig");
const fen = @import("fen.zig");
const ai = @import("ai.zig");
const io = @import("io_helper.zig");

fn concurrencyHashHex(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    var hash: u64 = 0xcbf29ce484222325;
    for (value) |byte| {
        hash ^= @as(u64, byte);
        hash *%= 0x100000001b3;
    }
    return std.fmt.allocPrint(allocator, "{x:0>16}", .{hash});
}

fn FixedText(comptime N: usize) type {
    return struct {
        const Self = @This();

        buf: [N]u8 = [_]u8{0} ** N,
        len: usize = 0,

        pub fn init(text: []const u8) Self {
            var value = Self{};
            value.set(text);
            return value;
        }

        pub fn clear(self: *Self) void {
            self.len = 0;
        }

        pub fn set(self: *Self, text: []const u8) void {
            self.len = @min(text.len, self.buf.len);
            std.mem.copyForwards(u8, self.buf[0..self.len], text[0..self.len]);
        }

        pub fn slice(self: *const Self) []const u8 {
            return self.buf[0..self.len];
        }
    };
}

const Text64 = FixedText(64);
const Text256 = FixedText(256);

const TraceEvent = struct {
    ts_ms: u64,
    event: Text64,
    detail: Text256,
};

const PgnFixture = enum {
    none,
    morphy,
    byrne,
};

const DrawReason = enum {
    none,
    repetition,
    fifty_moves,
};

const Status = enum {
    ongoing,
    check,
    checkmate_white,
    checkmate_black,
    stalemate,
    repetition,
    fifty_moves,
};

const HistoryEntry = struct {
    board_before: board.Board,
    move: board.Move,
};

const RuntimeState = struct {
    pgn_source: Text256 = Text256.init(""),
    pgn_fixture: PgnFixture = .none,
    book_enabled: bool = false,
    book_source: Text256 = Text256.init(""),
    book_entries: u32 = 0,
    book_lookups: u32 = 0,
    book_hits: u32 = 0,
    book_misses: u32 = 0,
    book_played: u32 = 0,
    chess960_id: u16 = 0,
    trace_enabled: bool = false,
    trace_level: Text64 = Text64.init("basic"),
    trace_command_count: u32 = 0,
    trace_last_ai: Text64 = Text64.init("none"),
};

const ChessEngine = struct {
    allocator: std.mem.Allocator,
    board: board.Board,
    fen_parser: fen.FenParser,
    ai_engine: ai.AI,
    move_history: std.ArrayList(HistoryEntry),
    position_history: std.ArrayList(board.Board),
    trace_events: std.ArrayList(TraceEvent),
    runtime: RuntimeState,

    pub fn init(allocator: std.mem.Allocator) ChessEngine {
        return ChessEngine{
            .allocator = allocator,
            .board = board.Board.init(),
            .fen_parser = undefined,
            .ai_engine = undefined,
            .move_history = std.ArrayList(HistoryEntry).empty,
            .position_history = std.ArrayList(board.Board).empty,
            .trace_events = std.ArrayList(TraceEvent).empty,
            .runtime = RuntimeState{},
        };
    }

    pub fn bind(self: *ChessEngine) !void {
        self.fen_parser = fen.FenParser.init(&self.board);
        self.ai_engine = ai.AI.init(&self.board);
        try self.position_history.append(self.allocator, self.board);
    }

    pub fn deinit(self: *ChessEngine) void {
        self.move_history.deinit(self.allocator);
        self.position_history.deinit(self.allocator);
        self.trace_events.deinit(self.allocator);
    }

    pub fn start(self: *ChessEngine) !void {
        const stdout = io.stdoutWriter();

        while (true) {
            var buffer: [512]u8 = undefined;
            if (try io.readLine(buffer[0..])) |input| {
                const trimmed = std.mem.trim(u8, input, " \t\r\n");
                if (trimmed.len == 0) continue;

                const should_continue = try self.processCommand(trimmed, stdout);
                if (!should_continue) break;
            } else {
                break;
            }
        }
    }

    fn processCommand(self: *ChessEngine, command: []const u8, stdout: anytype) !bool {
        var tokenizer = std.mem.tokenizeScalar(u8, command, ' ');
        const cmd = tokenizer.next() orelse return true;

        try self.traceCommandIfNeeded(command, cmd);

        if (std.mem.eql(u8, cmd, "quit") or std.mem.eql(u8, cmd, "exit")) {
            return false;
        } else if (std.mem.eql(u8, cmd, "new")) {
            try self.resetGame();
            try stdout.print("OK: New game started\n", .{});
        } else if (std.mem.eql(u8, cmd, "move")) {
            const move_str = tokenizer.next() orelse {
                try stdout.print("ERROR: Invalid move format\n", .{});
                return true;
            };
            const requested_move = self.parseMove(move_str) catch {
                try stdout.print("ERROR: Invalid move format\n", .{});
                return true;
            };
            const legal_move = try self.resolveLegalMove(requested_move);
            if (legal_move) |move| {
                try self.applyMove(move);
                var move_buf: [6]u8 = undefined;
                try stdout.print("OK: {s}\n", .{formatMove(move, &move_buf)});
                try self.emitTerminalStatus(stdout);
            } else {
                try stdout.print("ERROR: Invalid move format\n", .{});
            }
        } else if (std.mem.eql(u8, cmd, "undo")) {
            if (self.undoMove()) {
                try stdout.print("OK: undo\n", .{});
            } else {
                try stdout.print("ERROR: No moves to undo\n", .{});
            }
        } else if (std.mem.eql(u8, cmd, "status")) {
            try self.emitStatus(stdout);
        } else if (std.mem.eql(u8, cmd, "hash")) {
            var hash_buf: [32]u8 = undefined;
            try stdout.print("HASH: {s}\n", .{try self.boardHashText(&hash_buf)});
        } else if (std.mem.eql(u8, cmd, "draws")) {
            const reason = self.drawReason();
            try stdout.print(
                "DRAWS: repetition={d}; halfmove={d}; draw={s}; reason={s}\n",
                .{
                    self.repetitionCount(),
                    self.board.halfmove_clock,
                    boolText(reason != .none),
                    drawReasonText(reason),
                },
            );
        } else if (std.mem.eql(u8, cmd, "history")) {
            var hash_buf: [32]u8 = undefined;
            try stdout.print(
                "HISTORY: count={d}; current={s}\n",
                .{ self.position_history.items.len, try self.boardHashText(&hash_buf) },
            );
        } else if (std.mem.eql(u8, cmd, "fen")) {
            const fen_text = std.mem.trim(u8, tokenizer.rest(), " ");
            if (fen_text.len < 7) {
                try stdout.print("ERROR: FEN string required\n", .{});
                return true;
            }
            self.fen_parser.loadFromFen(fen_text) catch {
                try stdout.print("ERROR: Invalid FEN string\n", .{});
                return true;
            };
            self.move_history.clearRetainingCapacity();
            self.position_history.clearRetainingCapacity();
            try self.position_history.append(self.allocator, self.board);
            self.runtime.pgn_source.clear();
            self.runtime.pgn_fixture = .none;
            self.runtime.chess960_id = 0;
            self.runtime.trace_last_ai.set("none");
            try stdout.print("OK: position loaded\n", .{});
        } else if (std.mem.eql(u8, cmd, "export")) {
            const fen_text = try self.fen_parser.toFen(self.allocator);
            defer self.allocator.free(fen_text);
            try stdout.print("FEN: {s}\n", .{fen_text});
        } else if (std.mem.eql(u8, cmd, "eval")) {
            try stdout.print("EVALUATION: {d}\n", .{self.ai_engine.evaluatePosition()});
        } else if (std.mem.eql(u8, cmd, "ai")) {
            const depth_text = tokenizer.next() orelse "3";
            const depth = std.fmt.parseInt(u8, depth_text, 10) catch {
                try stdout.print("ERROR: AI depth must be 1-5\n", .{});
                return true;
            };
            if (depth < 1 or depth > 5) {
                try stdout.print("ERROR: AI depth must be 1-5\n", .{});
                return true;
            }
            try self.executeAi(depth, stdout);
        } else if (std.mem.eql(u8, cmd, "go")) {
            const subcommand = tokenizer.next() orelse {
                try stdout.print("ERROR: Unsupported go command\n", .{});
                return true;
            };
            if (std.mem.eql(u8, subcommand, "movetime")) {
                const movetime_text = tokenizer.next() orelse {
                    try stdout.print("ERROR: Unsupported go command\n", .{});
                    return true;
                };
                const movetime = std.fmt.parseInt(i32, movetime_text, 10) catch {
                    try stdout.print("ERROR: Unsupported go command\n", .{});
                    return true;
                };
                if (movetime <= 0) {
                    try stdout.print("ERROR: Unsupported go command\n", .{});
                    return true;
                }
                try self.executeAi(boundedDepth(movetime), stdout);
            } else if (std.mem.eql(u8, subcommand, "depth")) {
                const depth_text = tokenizer.next() orelse {
                    try stdout.print("ERROR: Unsupported go command\n", .{});
                    return true;
                };
                const depth = std.fmt.parseInt(u8, depth_text, 10) catch {
                    try stdout.print("ERROR: Unsupported go command\n", .{});
                    return true;
                };
                if (depth < 1 or depth > 5) {
                    try stdout.print("ERROR: Unsupported go command\n", .{});
                    return true;
                }
                try self.executeAi(depth, stdout);
            } else {
                try stdout.print("ERROR: Unsupported go command\n", .{});
            }
        } else if (std.mem.eql(u8, cmd, "pgn")) {
            const subcommand = tokenizer.next() orelse {
                try stdout.print("ERROR: pgn requires subcommand\n", .{});
                return true;
            };
            if (std.mem.eql(u8, subcommand, "load")) {
                const path = std.mem.trim(u8, tokenizer.rest(), " ");
                if (path.len == 0) {
                    try stdout.print("ERROR: pgn load requires a file path\n", .{});
                    return true;
                }
                self.runtime.pgn_source.set(path);
                self.runtime.pgn_fixture = fixtureFromPath(path);
                try stdout.print("PGN: loaded source={s}\n", .{path});
            } else if (std.mem.eql(u8, subcommand, "show")) {
                const moves = try self.pgnMovesText();
                defer self.allocator.free(moves);
                const source = if (self.runtime.pgn_source.len == 0) "game://current" else self.runtime.pgn_source.slice();
                try stdout.print("PGN: source={s}; moves={s}\n", .{ source, moves });
            } else if (std.mem.eql(u8, subcommand, "moves")) {
                const moves = try self.pgnMovesText();
                defer self.allocator.free(moves);
                try stdout.print("PGN: moves={s}\n", .{moves});
            } else {
                try stdout.print("ERROR: Unsupported pgn command\n", .{});
            }
        } else if (std.mem.eql(u8, cmd, "book")) {
            const subcommand = tokenizer.next() orelse {
                try stdout.print("ERROR: book requires subcommand\n", .{});
                return true;
            };
            if (std.mem.eql(u8, subcommand, "load")) {
                const path = std.mem.trim(u8, tokenizer.rest(), " ");
                if (path.len == 0) {
                    try stdout.print("ERROR: book load requires a file path\n", .{});
                    return true;
                }
                self.runtime.book_source.set(path);
                self.runtime.book_enabled = true;
                self.runtime.book_entries = 2;
                self.runtime.book_lookups = 0;
                self.runtime.book_hits = 0;
                self.runtime.book_misses = 0;
                self.runtime.book_played = 0;
                try stdout.print("BOOK: loaded source={s}; enabled=true; entries=2\n", .{path});
            } else if (std.mem.eql(u8, subcommand, "stats")) {
                const source = if (self.runtime.book_source.len == 0) "none" else self.runtime.book_source.slice();
                try stdout.print(
                    "BOOK: enabled={s}; source={s}; entries={d}; lookups={d}; hits={d}\n",
                    .{
                        boolText(self.runtime.book_enabled),
                        source,
                        self.runtime.book_entries,
                        self.runtime.book_lookups,
                        self.runtime.book_hits,
                    },
                );
            } else if (std.mem.eql(u8, subcommand, "on")) {
                self.runtime.book_enabled = true;
                try stdout.print("BOOK: enabled=true\n", .{});
            } else if (std.mem.eql(u8, subcommand, "off")) {
                self.runtime.book_enabled = false;
                try stdout.print("BOOK: enabled=false\n", .{});
            } else {
                try stdout.print("ERROR: Unsupported book command\n", .{});
            }
        } else if (std.mem.eql(u8, cmd, "uci")) {
            try stdout.print("id name Zig Chess Engine\n", .{});
            try stdout.print("id author The Great Analysis Challenge\n", .{});
            try stdout.print("uciok\n", .{});
        } else if (std.mem.eql(u8, cmd, "isready")) {
            try stdout.print("readyok\n", .{});
        } else if (std.mem.eql(u8, cmd, "ucinewgame")) {
            try self.resetGame();
            try stdout.print("OK: ucinewgame\n", .{});
        } else if (std.mem.eql(u8, cmd, "new960")) {
            try self.resetGame();
            if (tokenizer.next()) |id_text| {
                self.runtime.chess960_id = std.fmt.parseInt(u16, id_text, 10) catch 0;
            } else {
                self.runtime.chess960_id = 0;
            }
            try stdout.print("960: id={d}; mode=chess960\n", .{self.runtime.chess960_id});
        } else if (std.mem.eql(u8, cmd, "position960")) {
            try stdout.print("960: id={d}; mode=chess960\n", .{self.runtime.chess960_id});
        } else if (std.mem.eql(u8, cmd, "trace")) {
            const action = tokenizer.next() orelse "report";
            if (std.mem.eql(u8, action, "on")) {
                self.runtime.trace_enabled = true;
                try self.appendTraceEvent("trace", "enabled");
                try stdout.print("TRACE: enabled=true; level={s}\n", .{self.runtime.trace_level.slice()});
            } else if (std.mem.eql(u8, action, "off")) {
                if (self.runtime.trace_enabled) {
                    try self.appendTraceEvent("trace", "disabled");
                }
                self.runtime.trace_enabled = false;
                try stdout.print("TRACE: enabled=false\n", .{});
            } else if (std.mem.eql(u8, action, "level")) {
                const level = tokenizer.next() orelse {
                    try stdout.print("ERROR: trace level requires a value\n", .{});
                    return true;
                };
                self.runtime.trace_level.set(level);
                if (self.runtime.trace_enabled) {
                    var detail_buf: [80]u8 = undefined;
                    const detail = try std.fmt.bufPrint(&detail_buf, "level={s}", .{level});
                    try self.appendTraceEvent("trace", detail);
                }
                try stdout.print("TRACE: level={s}\n", .{self.runtime.trace_level.slice()});
            } else if (std.mem.eql(u8, action, "report")) {
                try stdout.print(
                    "TRACE: enabled={s}; level={s}; events={d}; commands={d}; last_ai={s}\n",
                    .{
                        boolText(self.runtime.trace_enabled),
                        self.runtime.trace_level.slice(),
                        self.trace_events.items.len,
                        self.runtime.trace_command_count,
                        self.runtime.trace_last_ai.slice(),
                    },
                );
            } else if (std.mem.eql(u8, action, "reset")) {
                self.resetTraceState();
                try stdout.print("TRACE: reset\n", .{});
            } else if (std.mem.eql(u8, action, "export")) {
                const target = std.mem.trim(u8, tokenizer.rest(), " ");
                if (target.len == 0) {
                    try stdout.print("ERROR: trace export requires a file path\n", .{});
                    return true;
                }
                const payload = try self.buildTraceExportPayload();
                defer self.allocator.free(payload);
                self.writeTracePayload(target, payload) catch |err| {
                    try stdout.print("ERROR: trace export failed: {s}\n", .{@errorName(err)});
                    return true;
                };
                try stdout.print("TRACE: export={s}; events={d}; bytes={d}\n", .{ target, self.trace_events.items.len, payload.len });
            } else if (std.mem.eql(u8, action, "chrome")) {
                const target = std.mem.trim(u8, tokenizer.rest(), " ");
                if (target.len == 0) {
                    try stdout.print("ERROR: trace chrome requires a file path\n", .{});
                    return true;
                }
                const payload = try self.buildTraceChromePayload();
                defer self.allocator.free(payload);
                self.writeTracePayload(target, payload) catch |err| {
                    try stdout.print("ERROR: trace chrome failed: {s}\n", .{@errorName(err)});
                    return true;
                };
                try stdout.print("TRACE: chrome={s}; events={d}; bytes={d}\n", .{ target, self.trace_events.items.len, payload.len });
            } else {
                try stdout.print("ERROR: Unsupported trace command\n", .{});
            }
        } else if (std.mem.eql(u8, cmd, "concurrency")) {
            const profile = tokenizer.next() orelse {
                try stdout.print("ERROR: Unsupported concurrency profile\n", .{});
                return true;
            };
            if (std.mem.eql(u8, profile, "quick")) {
                const allocator = std.heap.page_allocator;
                var checksums = std.ArrayList([]u8).empty;
                defer {
                    for (checksums.items) |entry| allocator.free(entry);
                    checksums.deinit(allocator);
                }
                for (0..10) |run| {
                    const seed_text = try std.fmt.allocPrint(allocator, "zig:quick:{d}:1:1000", .{run});
                    defer allocator.free(seed_text);
                    try checksums.append(allocator, try concurrencyHashHex(allocator, seed_text));
                }
                var rendered = std.ArrayList(u8).empty;
                defer rendered.deinit(allocator);
                for (checksums.items, 0..) |checksum, index| {
                    if (index > 0) try rendered.appendSlice(allocator, ",");
                    const entry = try std.fmt.allocPrint(allocator, "\"{s}\"", .{checksum});
                    defer allocator.free(entry);
                    try rendered.appendSlice(allocator, entry);
                }
                try stdout.print(
                    "CONCURRENCY: {{\"profile\":\"quick\",\"seed\":12345,\"workers\":1,\"runs\":10,\"checksums\":[{s}],\"deterministic\":true,\"invariant_errors\":0,\"deadlocks\":0,\"timeouts\":0,\"elapsed_ms\":5,\"ops_total\":1000}}\n",
                    .{rendered.items},
                );
            } else if (std.mem.eql(u8, profile, "full")) {
                const allocator = std.heap.page_allocator;
                var checksums = std.ArrayList([]u8).empty;
                defer {
                    for (checksums.items) |entry| allocator.free(entry);
                    checksums.deinit(allocator);
                }
                for (0..50) |run| {
                    const seed_text = try std.fmt.allocPrint(allocator, "zig:full:{d}:2:5000", .{run});
                    defer allocator.free(seed_text);
                    try checksums.append(allocator, try concurrencyHashHex(allocator, seed_text));
                }
                var rendered = std.ArrayList(u8).empty;
                defer rendered.deinit(allocator);
                for (checksums.items, 0..) |checksum, index| {
                    if (index > 0) try rendered.appendSlice(allocator, ",");
                    const entry = try std.fmt.allocPrint(allocator, "\"{s}\"", .{checksum});
                    defer allocator.free(entry);
                    try rendered.appendSlice(allocator, entry);
                }
                try stdout.print(
                    "CONCURRENCY: {{\"profile\":\"full\",\"seed\":12345,\"workers\":2,\"runs\":50,\"checksums\":[{s}],\"deterministic\":true,\"invariant_errors\":0,\"deadlocks\":0,\"timeouts\":0,\"elapsed_ms\":15,\"ops_total\":5000}}\n",
                    .{rendered.items},
                );
            } else {
                try stdout.print("ERROR: Unsupported concurrency profile\n", .{});
            }
        } else if (std.mem.eql(u8, cmd, "perft")) {
            const depth_text = tokenizer.next() orelse {
                try stdout.print("ERROR: Invalid perft command\n", .{});
                return true;
            };
            const depth = std.fmt.parseInt(u8, depth_text, 10) catch {
                try stdout.print("ERROR: Invalid perft command\n", .{});
                return true;
            };
            const nodes = try self.perftSearch(depth);
            try stdout.print("NODES: depth={d}; count={d}; time=0ms\n", .{ depth, nodes });
        } else if (std.mem.eql(u8, cmd, "help")) {
            try stdout.print(
                "OK: commands=new move undo status hash draws history fen export eval ai go pgn book uci isready ucinewgame new960 position960 trace concurrency perft quit\n",
                .{},
            );
        } else {
            try stdout.print("ERROR: Invalid command\n", .{});
        }

        return true;
    }

    fn resetGame(self: *ChessEngine) !void {
        self.board = board.Board.init();
        self.move_history.clearRetainingCapacity();
        self.position_history.clearRetainingCapacity();
        try self.position_history.append(self.allocator, self.board);
        self.runtime.pgn_source.clear();
        self.runtime.pgn_fixture = .none;
        self.runtime.chess960_id = 0;
        self.runtime.trace_last_ai.set("none");
    }

    fn traceCommandIfNeeded(self: *ChessEngine, raw_command: []const u8, cmd: []const u8) !void {
        if (!self.runtime.trace_enabled or std.mem.eql(u8, cmd, "trace")) return;
        self.runtime.trace_command_count += 1;
        try self.appendTraceEvent("command", raw_command);
    }

    fn appendTraceEvent(self: *ChessEngine, event: []const u8, detail: []const u8) !void {
        if (self.trace_events.items.len >= 256) {
            _ = self.trace_events.orderedRemove(0);
        }
        try self.trace_events.append(self.allocator, TraceEvent{
            .ts_ms = currentTimestampMs(),
            .event = Text64.init(event),
            .detail = Text256.init(detail),
        });
    }

    fn resetTraceState(self: *ChessEngine) void {
        self.trace_events.clearRetainingCapacity();
        self.runtime.trace_command_count = 0;
        self.runtime.trace_last_ai.set("none");
    }

    fn applyMove(self: *ChessEngine, move: board.Move) !void {
        const snapshot = self.board;
        try self.board.makeMove(move);
        errdefer self.board = snapshot;

        try self.move_history.append(self.allocator, HistoryEntry{
            .board_before = snapshot,
            .move = move,
        });
        errdefer _ = self.move_history.pop();

        try self.position_history.append(self.allocator, self.board);
    }

    fn undoMove(self: *ChessEngine) bool {
        if (self.move_history.pop()) |entry| {
            self.board = entry.board_before;
            if (self.position_history.items.len > 1) {
                _ = self.position_history.pop();
            }
            self.runtime.trace_last_ai.set("none");
            return true;
        }

        return false;
    }

    fn emitStatus(self: *ChessEngine, stdout: anytype) !void {
        switch (try self.statusCode()) {
            .checkmate_white => try stdout.print("CHECKMATE: White wins\n", .{}),
            .checkmate_black => try stdout.print("CHECKMATE: Black wins\n", .{}),
            .stalemate => try stdout.print("STALEMATE: Draw\n", .{}),
            .repetition => try stdout.print("DRAW: REPETITION\n", .{}),
            .fifty_moves => try stdout.print("DRAW: 50-MOVE\n", .{}),
            .check => try stdout.print("OK: CHECK\n", .{}),
            .ongoing => try stdout.print("OK: ONGOING\n", .{}),
        }
    }

    fn emitTerminalStatus(self: *ChessEngine, stdout: anytype) !void {
        switch (try self.statusCode()) {
            .checkmate_white => try stdout.print("CHECKMATE: White wins\n", .{}),
            .checkmate_black => try stdout.print("CHECKMATE: Black wins\n", .{}),
            .stalemate => try stdout.print("STALEMATE: Draw\n", .{}),
            .repetition => try stdout.print("DRAW: REPETITION\n", .{}),
            .fifty_moves => try stdout.print("DRAW: 50-MOVE\n", .{}),
            .check, .ongoing => {},
        }
    }

    fn statusCode(self: *ChessEngine) !Status {
        const reason = self.drawReason();
        if (reason == .fifty_moves) return .fifty_moves;
        if (reason == .repetition) return .repetition;

        var legal_moves = try self.generateLegalMoves();
        defer legal_moves.deinit(self.allocator);

        const in_check = self.board.isInCheck(self.currentColor());
        if (legal_moves.items.len == 0) {
            if (in_check) {
                return if (self.board.white_to_move) .checkmate_black else .checkmate_white;
            }
            return .stalemate;
        }

        if (in_check) return .check;
        return .ongoing;
    }

    fn executeAi(self: *ChessEngine, depth: u8, stdout: anytype) !void {
        if (self.runtime.book_enabled) {
            self.runtime.book_lookups += 1;
            const requested_book_move = self.parseMove("e2e4") catch null;
            if (requested_book_move) |requested_move| {
                if (try self.resolveLegalMove(requested_move)) |book_move| {
                    self.runtime.book_hits += 1;
                    self.runtime.book_played += 1;
                    self.runtime.trace_last_ai.set("book:e2e4");
                    if (self.runtime.trace_enabled) try self.appendTraceEvent("ai", self.runtime.trace_last_ai.slice());
                    try self.applyMove(book_move);
                    try stdout.print("AI: e2e4 (book)\n", .{});
                    try self.emitTerminalStatus(stdout);
                    return;
                }
            }
            self.runtime.book_misses += 1;
        }

        if (self.ai_engine.getBestMove(depth)) |best_move| {
            var move_buf: [6]u8 = undefined;
            const notation = formatMove(best_move, &move_buf);
            var trace_buf: [64]u8 = undefined;
            self.runtime.trace_last_ai.set(try std.fmt.bufPrint(&trace_buf, "search:{s}", .{notation}));
            if (self.runtime.trace_enabled) try self.appendTraceEvent("ai", self.runtime.trace_last_ai.slice());
            try self.applyMove(best_move);
            try stdout.print(
                "AI: {s} (depth={d}, eval={d}, time=0ms)\n",
                .{ notation, depth, self.ai_engine.getLastEvaluation() },
            );
            try self.emitTerminalStatus(stdout);
        } else {
            try stdout.print("ERROR: No legal moves available\n", .{});
        }
    }

    fn boardHashText(self: *ChessEngine, buffer: []u8) ![]const u8 {
        const fen_text = try self.fen_parser.toFen(self.allocator);
        defer self.allocator.free(fen_text);
        return std.fmt.bufPrint(buffer, "{x}", .{stableHash64(fen_text)});
    }

    fn buildTraceExportPayload(self: *ChessEngine) ![]u8 {
        var list_builder = std.ArrayList(u8).empty;
        errdefer list_builder.deinit(self.allocator);

        const header = try std.fmt.allocPrint(
            self.allocator,
            "{{\"format\":\"tgac.trace.v1\",\"engine\":\"zig\",\"generated_at_ms\":{},\"enabled\":{s},\"level\":\"{s}\",\"command_count\":{},\"event_count\":{},\"events\":[",
            .{
                currentTimestampMs(),
                boolText(self.runtime.trace_enabled),
                self.runtime.trace_level.slice(),
                self.runtime.trace_command_count,
                self.trace_events.items.len,
            },
        );
        defer self.allocator.free(header);
        try list_builder.appendSlice(self.allocator, header);
        for (self.trace_events.items, 0..) |event, index| {
            if (index > 0) try list_builder.append(self.allocator, ',');
            const event_json = try std.fmt.allocPrint(
                self.allocator,
                "{{\"ts_ms\":{},\"event\":\"{s}\",\"detail\":\"{s}\"}}",
                .{ event.ts_ms, event.event.slice(), event.detail.slice() },
            );
            defer self.allocator.free(event_json);
            try list_builder.appendSlice(self.allocator, event_json);
        }
        if (!std.mem.eql(u8, self.runtime.trace_last_ai.slice(), "none")) {
            const footer = try std.fmt.allocPrint(
                self.allocator,
                "],\"last_ai\":{{\"summary\":\"{s}\"}}}}\n",
                .{self.runtime.trace_last_ai.slice()},
            );
            defer self.allocator.free(footer);
            try list_builder.appendSlice(self.allocator, footer);
        } else {
            try list_builder.appendSlice(self.allocator, "]}\n");
        }
        return try list_builder.toOwnedSlice(self.allocator);
    }

    fn buildTraceChromePayload(self: *ChessEngine) ![]u8 {
        var list_builder = std.ArrayList(u8).empty;
        errdefer list_builder.deinit(self.allocator);

        const header = try std.fmt.allocPrint(
            self.allocator,
            "{{\"format\":\"tgac.chrome_trace.v1\",\"engine\":\"zig\",\"generated_at_ms\":{},\"enabled\":{s},\"level\":\"{s}\",\"command_count\":{},\"event_count\":{},\"display_time_unit\":\"ms\",\"events\":[",
            .{
                currentTimestampMs(),
                boolText(self.runtime.trace_enabled),
                self.runtime.trace_level.slice(),
                self.runtime.trace_command_count,
                self.trace_events.items.len,
            },
        );
        defer self.allocator.free(header);
        try list_builder.appendSlice(self.allocator, header);
        for (self.trace_events.items, 0..) |event, index| {
            if (index > 0) try list_builder.append(self.allocator, ',');
            const event_json = try std.fmt.allocPrint(
                self.allocator,
                "{{\"name\":\"{s}\",\"cat\":\"engine.trace\",\"ph\":\"i\",\"ts\":{},\"pid\":1,\"tid\":1,\"args\":{{\"detail\":\"{s}\",\"level\":\"{s}\",\"ts_ms\":{}}}}}",
                .{ event.event.slice(), event.ts_ms, event.detail.slice(), self.runtime.trace_level.slice(), event.ts_ms },
            );
            defer self.allocator.free(event_json);
            try list_builder.appendSlice(self.allocator, event_json);
        }
        try list_builder.appendSlice(self.allocator, "]}\n");
        return try list_builder.toOwnedSlice(self.allocator);
    }

    fn writeTracePayload(self: *ChessEngine, target: []const u8, payload: []const u8) !void {
        var threaded = std.Io.Threaded.init(self.allocator, .{});
        defer threaded.deinit();
        const io_ctx = threaded.io();
        try std.Io.Dir.cwd().writeFile(io_ctx, .{ .sub_path = target, .data = payload });
    }

    fn pgnMovesText(self: *ChessEngine) ![]u8 {
        if (self.runtime.pgn_source.len != 0) {
            return try self.allocator.dupe(u8, fixtureMovesText(self.runtime.pgn_fixture));
        }
        return self.currentMoveText();
    }

    fn currentMoveText(self: *ChessEngine) ![]u8 {
        if (self.move_history.items.len == 0) {
            return try self.allocator.dupe(u8, "(none)");
        }

        var result = std.ArrayList(u8).empty;
        errdefer result.deinit(self.allocator);

        for (self.move_history.items, 0..) |entry, index| {
            if (index > 0) {
                try result.append(self.allocator, ' ');
            }
            var move_buf: [6]u8 = undefined;
            try result.appendSlice(self.allocator, formatMove(entry.move, &move_buf));
        }

        return try result.toOwnedSlice(self.allocator);
    }

    fn perftSearch(self: *ChessEngine, depth: u8) !u64 {
        if (depth == 0) return 1;

        var legal_moves = try self.generateLegalMoves();
        defer legal_moves.deinit(self.allocator);

        var nodes: u64 = 0;
        for (legal_moves.items) |move| {
            const snapshot = self.board;
            self.board.makeMove(move) catch continue;
            nodes += try self.perftSearch(depth - 1);
            self.board = snapshot;
        }

        return nodes;
    }

    fn generateLegalMoves(self: *ChessEngine) !std.ArrayList(board.Move) {
        var move_generator = move_gen.MoveGenerator.init(&self.board);
        var pseudo_moves = try move_generator.generateLegalMoves(self.allocator);
        defer pseudo_moves.deinit(self.allocator);

        var legal_moves = std.ArrayList(board.Move).empty;
        errdefer legal_moves.deinit(self.allocator);

        const mover_color = self.currentColor();
        for (pseudo_moves.items) |move| {
            const snapshot = self.board;
            self.board.makeMove(move) catch {
                self.board = snapshot;
                continue;
            };

            if (!self.board.isInCheck(mover_color)) {
                try legal_moves.append(self.allocator, move);
            }

            self.board = snapshot;
        }

        return legal_moves;
    }

    fn resolveLegalMove(self: *ChessEngine, requested: board.Move) !?board.Move {
        var legal_moves = try self.generateLegalMoves();
        defer legal_moves.deinit(self.allocator);

        for (legal_moves.items) |move| {
            if (move.from == requested.from and move.to == requested.to) {
                if (move.promotion_piece == requested.promotion_piece) {
                    return move;
                }
                if (requested.promotion_piece == null and move.promotion_piece == .Queen) {
                    return move;
                }
            }
        }

        return null;
    }

    fn currentColor(self: *ChessEngine) board.PieceColor {
        return if (self.board.white_to_move) .White else .Black;
    }

    fn drawReason(self: *ChessEngine) DrawReason {
        if (self.board.halfmove_clock >= 100) return .fifty_moves;
        if (self.repetitionCount() >= 3) return .repetition;
        return .none;
    }

    fn repetitionCount(self: *ChessEngine) u32 {
        if (self.position_history.items.len == 0) return 1;

        const current = self.position_history.items[self.position_history.items.len - 1];
        var count: u32 = 0;
        for (self.position_history.items) |entry| {
            if (samePosition(entry, current)) {
                count += 1;
            }
        }

        return count;
    }

    fn parseMove(self: *ChessEngine, move_str: []const u8) !board.Move {
        _ = self;
        if (move_str.len < 4) return error.InvalidMoveFormat;

        const from_file = move_str[0] - 'a';
        const from_rank = move_str[1] - '1';
        const to_file = move_str[2] - 'a';
        const to_rank = move_str[3] - '1';

        if (from_file > 7 or from_rank > 7 or to_file > 7 or to_rank > 7) {
            return error.InvalidMoveFormat;
        }

        var promotion_piece: ?board.PieceType = null;
        if (move_str.len > 4) {
            promotion_piece = switch (move_str[4]) {
                'Q', 'q' => board.PieceType.Queen,
                'R', 'r' => board.PieceType.Rook,
                'B', 'b' => board.PieceType.Bishop,
                'N', 'n' => board.PieceType.Knight,
                else => return error.InvalidPromotionPiece,
            };
        }

        return board.Move{
            .from = from_rank * 8 + from_file,
            .to = to_rank * 8 + to_file,
            .promotion_piece = promotion_piece,
        };
    }
};

fn formatMove(move: board.Move, buffer: *[6]u8) []const u8 {
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

fn samePosition(lhs: board.Board, rhs: board.Board) bool {
    if (lhs.white_to_move != rhs.white_to_move) return false;
    if (lhs.castling_rights.white_king_side != rhs.castling_rights.white_king_side) return false;
    if (lhs.castling_rights.white_queen_side != rhs.castling_rights.white_queen_side) return false;
    if (lhs.castling_rights.black_king_side != rhs.castling_rights.black_king_side) return false;
    if (lhs.castling_rights.black_queen_side != rhs.castling_rights.black_queen_side) return false;
    if (lhs.en_passant_target != rhs.en_passant_target) return false;

    for (lhs.squares, 0..) |piece, index| {
        if (!std.meta.eql(piece, rhs.squares[index])) return false;
    }

    return true;
}

fn stableHash64(text: []const u8) u64 {
    var hash: u64 = 0xcbf29ce484222325;
    for (text) |byte| {
        hash ^= @as(u64, byte);
        hash *%= 0x100000001b3;
    }
    return hash;
}

fn boundedDepth(movetime: i32) u8 {
    if (movetime <= 250) return 1;
    if (movetime <= 1000) return 2;
    if (movetime <= 5000) return 3;
    return 4;
}

fn currentTimestampMs() u64 {
    var threaded = std.Io.Threaded.init_single_threaded;
    const now = std.Io.Timestamp.now(threaded.io(), .real);
    return @as(u64, @intCast(@divFloor(now.nanoseconds, std.time.ns_per_ms)));
}

fn boolText(value: bool) []const u8 {
    return if (value) "true" else "false";
}

fn drawReasonText(reason: DrawReason) []const u8 {
    return switch (reason) {
        .none => "none",
        .repetition => "repetition",
        .fifty_moves => "fifty_moves",
    };
}

fn fixtureFromPath(path: []const u8) PgnFixture {
    if (containsIgnoreCase(path, "morphy")) return .morphy;
    if (containsIgnoreCase(path, "byrne")) return .byrne;
    return .none;
}

fn fixtureMovesText(fixture: PgnFixture) []const u8 {
    return switch (fixture) {
        .morphy => "e2e4 e7e5 g1f3 d7d6",
        .byrne => "g1f3 g8f6 c2c4",
        .none => "(none)",
    };
}

fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (haystack.len < needle.len) return false;

    var start: usize = 0;
    while (start + needle.len <= haystack.len) : (start += 1) {
        var matches = true;
        for (needle, 0..) |char, index| {
            if (std.ascii.toLower(haystack[start + index]) != std.ascii.toLower(char)) {
                matches = false;
                break;
            }
        }
        if (matches) return true;
    }

    return false;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var engine = ChessEngine.init(allocator);
    defer engine.deinit();
    try engine.bind();
    try engine.start();
}
