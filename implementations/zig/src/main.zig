const std = @import("std");
const board = @import("board.zig");
const move_gen = @import("move_generator.zig");
const fen = @import("fen.zig");
const ai = @import("ai.zig");
const perft = @import("perft.zig");
const io = @import("io_helper.zig");

const ChessEngine = struct {
    allocator: std.mem.Allocator,
    board: board.Board,
    move_generator: move_gen.MoveGenerator,
    fen_parser: fen.FenParser,
    ai: ai.AI,
    perft: perft.Perft,
    move_history: std.ArrayList(board.Move),

    pub fn init(allocator: std.mem.Allocator) ChessEngine {
        return ChessEngine{
            .allocator = allocator,
            .board = board.Board.init(),
            .move_generator = undefined,
            .fen_parser = undefined,
            .ai = undefined,
            .perft = undefined,
            .move_history = std.ArrayList(board.Move).empty,
        };
    }

    pub fn bind(self: *ChessEngine) void {
        self.move_generator = move_gen.MoveGenerator.init(&self.board);
        self.fen_parser = fen.FenParser.init(&self.board);
        self.ai = ai.AI.init(&self.board);
        self.perft = perft.Perft.init(&self.board);
    }

    pub fn deinit(self: *ChessEngine) void {
        self.move_history.deinit(self.allocator);
    }

    pub fn start(self: *ChessEngine) !void {
        const stdout = io.stdoutWriter();

        try self.board.display(stdout);

        while (true) {
            try stdout.print("\n> ", .{});

            var buffer: [256]u8 = undefined;
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

        if (std.mem.eql(u8, cmd, "new")) {
            self.board = board.Board.init();
            self.move_history.clearRetainingCapacity();
            try self.board.display(stdout);
        } else if (std.mem.eql(u8, cmd, "move")) {
            if (tokenizer.next()) |move_str| {
                if (self.parseAndMakeMove(move_str)) |move| {
                    try self.move_history.append(self.allocator, move);
                    try stdout.print("OK: {s}\n", .{move_str});
                    try self.board.display(stdout);

                    // Check for game end
                    if (self.board.isCheckmate()) {
                        const winner = if (self.board.white_to_move) "Black" else "White";
                        try stdout.print("CHECKMATE: {s} wins\n", .{winner});
                    } else if (self.board.isStalemate()) {
                        try stdout.print("STALEMATE: Draw\n", .{});
                    }
                } else |err| {
                    try stdout.print("ERROR: {}\n", .{err});
                }
            } else {
                try stdout.print("ERROR: Move format required\n", .{});
            }
        } else if (std.mem.eql(u8, cmd, "undo")) {
            if (self.move_history.pop()) |last_move| {
                self.board.undoMove(last_move);
                try stdout.print("OK: undo\n", .{});
                try self.board.display(stdout);
            } else {
                try stdout.print("ERROR: No moves to undo\n", .{});
            }
        } else if (std.mem.eql(u8, cmd, "ai")) {
            if (tokenizer.next()) |depth_str| {
                const depth = std.fmt.parseInt(u8, depth_str, 10) catch {
                    try stdout.print("ERROR: Invalid depth\n", .{});
                    return;
                };
                if (depth < 1 or depth > 5) {
                    try stdout.print("ERROR: AI depth must be 1-5\n", .{});
                    return;
                }

                if (self.ai.getBestMove(depth)) |ai_move| {
                    const time_ms: i64 = 0;

                    try self.board.makeMove(ai_move);
                    try self.move_history.append(self.allocator, ai_move);

                    const move_str = self.moveToString(ai_move);
                    const eval_score = self.ai.getLastEvaluation();

                    try stdout.print("AI: {s} (depth={}, eval={}, time={}ms)\n", .{ move_str, depth, eval_score, time_ms });
                    try self.board.display(stdout);

                    // Check for game end
                    if (self.board.isCheckmate()) {
                        const winner = if (self.board.white_to_move) "Black" else "White";
                        try stdout.print("CHECKMATE: {s} wins\n", .{winner});
                    } else if (self.board.isStalemate()) {
                        try stdout.print("STALEMATE: Draw\n", .{});
                    }
                } else {
                    try stdout.print("ERROR: No legal moves available\n", .{});
                }
            } else {
                try stdout.print("ERROR: AI depth required\n", .{});
            }
        } else if (std.mem.eql(u8, cmd, "fen")) {
            const fen_str = tokenizer.rest();
            if (fen_str.len > 0) {
                self.fen_parser.loadFromFen(fen_str) catch {
                    try stdout.print("ERROR: Invalid FEN string\n", .{});
                    return;
                };
                try stdout.print("OK: position loaded\n", .{});
                try self.board.display(stdout);
            } else {
                try stdout.print("ERROR: FEN string required\n", .{});
            }
        } else if (std.mem.eql(u8, cmd, "export")) {
            const fen_str = try self.fen_parser.toFen(self.allocator);
            defer self.allocator.free(fen_str);
            try stdout.print("FEN: {s}\n", .{fen_str});
        } else if (std.mem.eql(u8, cmd, "eval")) {
            const evaluation = self.ai.evaluatePosition();
            try stdout.print("Evaluation: {}\n", .{evaluation});
        } else if (std.mem.eql(u8, cmd, "perft")) {
            if (tokenizer.next()) |depth_str| {
                const depth = std.fmt.parseInt(u8, depth_str, 10) catch {
                    try stdout.print("ERROR: Invalid depth\n", .{});
                    return;
                };

                const nodes = self.perft.perft(depth);
                const time_ms: i64 = 0;

                try stdout.print("Perft({}) = {} nodes ({}ms)\n", .{ depth, nodes, time_ms });
            } else {
                try stdout.print("ERROR: Perft depth required\n", .{});
            }
        } else if (std.mem.eql(u8, cmd, "help")) {
            try stdout.print("Available commands:\n", .{});
            try stdout.print("  new - Start a new game\n", .{});
            try stdout.print("  move <from><to>[promotion] - Make a move (e.g., e2e4, e7e8Q)\n", .{});
            try stdout.print("  undo - Undo the last move\n", .{});
            try stdout.print("  ai <depth> - AI makes a move (depth 1-5)\n", .{});
            try stdout.print("  fen <string> - Load position from FEN\n", .{});
            try stdout.print("  export - Export current position as FEN\n", .{});
            try stdout.print("  eval - Display position evaluation\n", .{});
            try stdout.print("  perft <depth> - Performance test (move count)\n", .{});
            try stdout.print("  help - Display this help\n", .{});
            try stdout.print("  quit - Exit the program\n", .{});
        } else if (std.mem.eql(u8, cmd, "quit")) {
            std.process.exit(0);
        } else {
            try stdout.print("ERROR: Invalid command\n", .{});
        }
    }

    fn parseAndMakeMove(self: *ChessEngine, move_str: []const u8) !board.Move {
        const move = try self.parseMove(move_str);
        try self.board.makeMove(move);
        return move;
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

        const from = @as(u8, from_rank) * 8 + from_file;
        const to = @as(u8, to_rank) * 8 + to_file;

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
            .from = from,
            .to = to,
            .promotion_piece = promotion_piece,
        };
    }

    fn moveToString(self: *ChessEngine, move: board.Move) []const u8 {
        _ = self;
        var buffer: [6]u8 = undefined;

        const from_file = @as(u8, 'a') + (move.from % 8);
        const from_rank = @as(u8, '1') + (move.from / 8);
        const to_file = @as(u8, 'a') + (move.to % 8);
        const to_rank = @as(u8, '1') + (move.to / 8);

        buffer[0] = from_file;
        buffer[1] = from_rank;
        buffer[2] = to_file;
        buffer[3] = to_rank;

        var len: usize = 4;
        if (move.promotion_piece) |piece| {
            buffer[4] = switch (piece) {
                .Queen => 'Q',
                .Rook => 'R',
                .Bishop => 'B',
                .Knight => 'N',
                else => 'Q',
            };
            len = 5;
        }

        return buffer[0..len];
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = ChessEngine.init(allocator);
    engine.bind();
    defer engine.deinit();

    try engine.start();
}
