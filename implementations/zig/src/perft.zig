const std = @import("std");
const board = @import("board.zig");
const move_gen = @import("move_generator.zig");

pub const Perft = struct {
    board_ref: *board.Board,

    pub fn init(board_ref: *board.Board) Perft {
        return Perft{
            .board_ref = board_ref,
        };
    }

    pub fn perft(self: *Perft, depth: u8) u64 {
        if (depth == 0) return 1;
        
        var allocator = std.heap.page_allocator;
        var move_generator = move_gen.MoveGenerator.init(self.board_ref);
        
        const legal_moves = move_generator.generateLegalMoves(allocator) catch return 0;
        defer legal_moves.deinit();
        
        var nodes: u64 = 0;
        
        for (legal_moves.items) |move| {
            // Save game state
            const original_state = self.saveGameState();
            
            // Make the move
            self.board_ref.makeMove(move) catch continue;
            
            // Recursively count nodes
            nodes += self.perft(depth - 1);
            
            // Restore game state
            self.restoreGameState(original_state);
            self.board_ref.undoMove(move);
        }
        
        return nodes;
    }

    pub fn perftDivide(self: *Perft, depth: u8) !void {
        var allocator = std.heap.page_allocator;
        var move_generator = move_gen.MoveGenerator.init(self.board_ref);
        
        const legal_moves = move_generator.generateLegalMoves(allocator) catch return;
        defer legal_moves.deinit();
        
        var total_nodes: u64 = 0;
        const stdout = std.io.getStdOut().writer();
        
        for (legal_moves.items) |move| {
            // Save game state
            const original_state = self.saveGameState();
            
            // Make the move
            self.board_ref.makeMove(move) catch continue;
            
            // Count nodes for this move
            const nodes = if (depth > 1) self.perft(depth - 1) else 1;
            total_nodes += nodes;
            
            // Print move and node count
            const move_str = self.moveToString(move);
            try stdout.print("{s}: {}\n", .{ move_str, nodes });
            
            // Restore game state
            self.restoreGameState(original_state);
            self.board_ref.undoMove(move);
        }
        
        try stdout.print("\nTotal: {}\n", .{total_nodes});
    }

    fn moveToString(self: *Perft, move: board.Move) []const u8 {
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

    // Helper functions for game state management
    const GameState = struct {
        squares: [64]?board.Piece,
        white_to_move: bool,
        castling_rights: board.CastlingRights,
        en_passant_target: ?u8,
        halfmove_clock: u16,
        fullmove_number: u16,
    };

    fn saveGameState(self: *Perft) GameState {
        return GameState{
            .squares = self.board_ref.squares,
            .white_to_move = self.board_ref.white_to_move,
            .castling_rights = self.board_ref.castling_rights,
            .en_passant_target = self.board_ref.en_passant_target,
            .halfmove_clock = self.board_ref.halfmove_clock,
            .fullmove_number = self.board_ref.fullmove_number,
        };
    }

    fn restoreGameState(self: *Perft, state: GameState) void {
        self.board_ref.squares = state.squares;
        self.board_ref.white_to_move = state.white_to_move;
        self.board_ref.castling_rights = state.castling_rights;
        self.board_ref.en_passant_target = state.en_passant_target;
        self.board_ref.halfmove_clock = state.halfmove_clock;
        self.board_ref.fullmove_number = state.fullmove_number;
    }
};