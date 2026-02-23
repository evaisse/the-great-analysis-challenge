const std = @import("std");
const board = @import("board.zig");

pub const FenParser = struct {
    board_ref: *board.Board,

    pub fn init(board_ref: *board.Board) FenParser {
        return FenParser{
            .board_ref = board_ref,
        };
    }

    pub fn loadFromFen(self: *FenParser, fen_string: []const u8) !void {
        var parts = std.mem.splitScalar(u8, fen_string, ' ');

        // Parse piece placement
        const piece_data = parts.next() orelse return error.InvalidFen;
        try self.parsePiecePlacement(piece_data);

        // Parse active color
        const active_color = parts.next() orelse return error.InvalidFen;
        self.board_ref.white_to_move = std.mem.eql(u8, active_color, "w");

        // Parse castling availability
        const castling_data = parts.next() orelse return error.InvalidFen;
        try self.parseCastlingRights(castling_data);

        // Parse en passant target square
        const en_passant_data = parts.next() orelse return error.InvalidFen;
        try self.parseEnPassantTarget(en_passant_data);

        // Parse halfmove clock
        const halfmove_data = parts.next() orelse return error.InvalidFen;
        self.board_ref.halfmove_clock = std.fmt.parseInt(u16, halfmove_data, 10) catch return error.InvalidFen;

        // Parse fullmove number
        const fullmove_data = parts.next() orelse return error.InvalidFen;
        self.board_ref.fullmove_number = std.fmt.parseInt(u16, fullmove_data, 10) catch return error.InvalidFen;
    }

    fn parsePiecePlacement(self: *FenParser, piece_data: []const u8) !void {
        // Clear the board
        for (&self.board_ref.squares) |*square| {
            square.* = null;
        }

        var ranks = std.mem.splitScalar(u8, piece_data, '/');
        var rank: u8 = 7; // Start from rank 8 (index 7)

        while (ranks.next()) |rank_data| {
            var file: u8 = 0;

            for (rank_data) |char| {
                if (std.ascii.isDigit(char)) {
                    // Empty squares
                    const empty_count = char - '0';
                    file += empty_count;
                } else {
                    // Piece
                    if (file >= 8) return error.InvalidFen;

                    const piece = board.Piece.fromChar(char) orelse return error.InvalidFen;
                    const square_index = rank * 8 + file;
                    self.board_ref.squares[square_index] = piece;
                    file += 1;
                }
            }

            if (file != 8) return error.InvalidFen;
            if (rank == 0) break;
            rank -= 1;
        }
    }

    fn parseCastlingRights(self: *FenParser, castling_data: []const u8) !void {
        self.board_ref.castling_rights = board.CastlingRights{
            .white_king_side = false,
            .white_queen_side = false,
            .black_king_side = false,
            .black_queen_side = false,
        };

        if (std.mem.eql(u8, castling_data, "-")) {
            return; // No castling rights
        }

        for (castling_data) |char| {
            switch (char) {
                'K' => self.board_ref.castling_rights.white_king_side = true,
                'Q' => self.board_ref.castling_rights.white_queen_side = true,
                'k' => self.board_ref.castling_rights.black_king_side = true,
                'q' => self.board_ref.castling_rights.black_queen_side = true,
                else => return error.InvalidFen,
            }
        }
    }

    fn parseEnPassantTarget(self: *FenParser, en_passant_data: []const u8) !void {
        if (std.mem.eql(u8, en_passant_data, "-")) {
            self.board_ref.en_passant_target = null;
            return;
        }

        if (en_passant_data.len != 2) return error.InvalidFen;

        const file = en_passant_data[0] - 'a';
        const rank = en_passant_data[1] - '1';

        if (file > 7 or rank > 7) return error.InvalidFen;

        self.board_ref.en_passant_target = rank * 8 + file;
    }

    pub fn toFen(self: *FenParser, allocator: std.mem.Allocator) ![]u8 {
        var fen_parts = std.ArrayList([]const u8).empty;
        defer fen_parts.deinit(allocator);

        // Piece placement
        const piece_placement = try self.getPiecePlacement(allocator);
        try fen_parts.append(allocator, piece_placement);

        // Active color
        const active_color = if (self.board_ref.white_to_move) "w" else "b";
        try fen_parts.append(allocator, active_color);

        // Castling availability
        const castling = try self.getCastlingString(allocator);
        try fen_parts.append(allocator, castling);

        // En passant target square
        const en_passant = try self.getEnPassantString(allocator);
        try fen_parts.append(allocator, en_passant);

        // Halfmove clock
        const halfmove = try std.fmt.allocPrint(allocator, "{}", .{self.board_ref.halfmove_clock});
        try fen_parts.append(allocator, halfmove);

        // Fullmove number
        const fullmove = try std.fmt.allocPrint(allocator, "{}", .{self.board_ref.fullmove_number});
        try fen_parts.append(allocator, fullmove);

        // Join all parts with spaces
        return std.mem.join(allocator, " ", fen_parts.items);
    }

    fn getPiecePlacement(self: *FenParser, allocator: std.mem.Allocator) ![]u8 {
        var rank_strings = std.ArrayList([]const u8).empty;
        defer rank_strings.deinit(allocator);

        var rank: i8 = 7; // Start from rank 8
        while (rank >= 0) : (rank -= 1) {
            var rank_string = std.ArrayList(u8).empty;
            defer rank_string.deinit(allocator);

            var file: u8 = 0;
            while (file < 8) {
                var empty_count: u8 = 0;

                // Count consecutive empty squares
                while (file < 8 and self.board_ref.squares[@as(u8, @intCast(rank)) * 8 + file] == null) {
                    empty_count += 1;
                    file += 1;
                }

                // Add empty count to string if any
                if (empty_count > 0) {
                    try rank_string.append(allocator, '0' + empty_count);
                }

                // Add piece if present
                if (file < 8) {
                    if (self.board_ref.squares[@as(u8, @intCast(rank)) * 8 + file]) |piece| {
                        try rank_string.append(allocator, piece.toChar());
                    }
                    file += 1;
                }
            }

            try rank_strings.append(allocator, try rank_string.toOwnedSlice(allocator));
        }

        return std.mem.join(allocator, "/", rank_strings.items);
    }

    fn getCastlingString(self: *FenParser, allocator: std.mem.Allocator) ![]const u8 {
        var castling = std.ArrayList(u8).empty;
        defer castling.deinit(allocator);

        if (self.board_ref.castling_rights.white_king_side) try castling.append(allocator, 'K');
        if (self.board_ref.castling_rights.white_queen_side) try castling.append(allocator, 'Q');
        if (self.board_ref.castling_rights.black_king_side) try castling.append(allocator, 'k');
        if (self.board_ref.castling_rights.black_queen_side) try castling.append(allocator, 'q');

        if (castling.items.len == 0) {
            return try allocator.dupe(u8, "-");
        }

        return try castling.toOwnedSlice(allocator);
    }

    fn getEnPassantString(self: *FenParser, allocator: std.mem.Allocator) ![]const u8 {
        if (self.board_ref.en_passant_target) |target| {
            const file = @as(u8, 'a') + (target % 8);
            const rank = @as(u8, '1') + (target / 8);
            return try std.fmt.allocPrint(allocator, "{c}{c}", .{ file, rank });
        } else {
            return try allocator.dupe(u8, "-");
        }
    }
};
