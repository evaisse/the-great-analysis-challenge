const std = @import("std");
const board = @import("board.zig");

pub const MoveGenerator = struct {
    board_ref: *board.Board,

    pub fn init(board_ref: *board.Board) MoveGenerator {
        return MoveGenerator{
            .board_ref = board_ref,
        };
    }

    pub fn generateLegalMoves(self: *MoveGenerator, allocator: std.mem.Allocator) !std.ArrayList(board.Move) {
        var moves = std.ArrayList(board.Move).init(allocator);
        
        const current_color = if (self.board_ref.white_to_move) board.PieceColor.White else board.PieceColor.Black;
        
        for (self.board_ref.squares, 0..) |piece, i| {
            if (piece) |p| {
                if (p.color == current_color) {
                    try self.generatePieceMoves(@intCast(i), p, &moves);
                }
            }
        }
        
        return moves;
    }

    fn generatePieceMoves(self: *MoveGenerator, from: u8, piece: board.Piece, moves: *std.ArrayList(board.Move)) !void {
        switch (piece.piece_type) {
            .Pawn => try self.generatePawnMoves(from, piece.color, moves),
            .Knight => try self.generateKnightMoves(from, piece.color, moves),
            .Bishop => try self.generateBishopMoves(from, piece.color, moves),
            .Rook => try self.generateRookMoves(from, piece.color, moves),
            .Queen => try self.generateQueenMoves(from, piece.color, moves),
            .King => try self.generateKingMoves(from, piece.color, moves),
        }
    }

    fn generatePawnMoves(self: *MoveGenerator, from: u8, color: board.PieceColor, moves: *std.ArrayList(board.Move)) !void {
        const from_rank = from / 8;
        const from_file = from % 8;
        const direction: i8 = if (color == .White) 1 else -1;
        const starting_rank = if (color == .White) 1 else 6;
        const promotion_rank = if (color == .White) 7 else 0;

        // Forward moves
        const one_forward = @as(i8, @intCast(from)) + direction * 8;
        if (one_forward >= 0 and one_forward < 64) {
            const to_square = @as(u8, @intCast(one_forward));
            if (self.board_ref.squares[to_square] == null) {
                if (to_square / 8 == promotion_rank) {
                    // Promotion moves
                    try moves.append(board.Move{ .from = from, .to = to_square, .promotion_piece = .Queen });
                    try moves.append(board.Move{ .from = from, .to = to_square, .promotion_piece = .Rook });
                    try moves.append(board.Move{ .from = from, .to = to_square, .promotion_piece = .Bishop });
                    try moves.append(board.Move{ .from = from, .to = to_square, .promotion_piece = .Knight });
                } else {
                    try moves.append(board.Move{ .from = from, .to = to_square });
                }

                // Two squares forward from starting position
                if (from_rank == starting_rank) {
                    const two_forward = @as(i8, @intCast(from)) + direction * 16;
                    if (two_forward >= 0 and two_forward < 64) {
                        const to_square_two = @as(u8, @intCast(two_forward));
                        if (self.board_ref.squares[to_square_two] == null) {
                            try moves.append(board.Move{ .from = from, .to = to_square_two });
                        }
                    }
                }
            }
        }

        // Captures
        const capture_moves = [_]i8{ direction * 8 - 1, direction * 8 + 1 };
        for (capture_moves) |move_offset| {
            const target = @as(i8, @intCast(from)) + move_offset;
            if (target >= 0 and target < 64) {
                const to_square = @as(u8, @intCast(target));
                const to_file = to_square % 8;
                
                // Check file bounds for diagonal captures
                if ((move_offset == direction * 8 - 1 and from_file > 0) or
                    (move_offset == direction * 8 + 1 and from_file < 7)) {
                    
                    if (self.board_ref.squares[to_square]) |target_piece| {
                        if (target_piece.color != color) {
                            if (to_square / 8 == promotion_rank) {
                                // Promotion captures
                                try moves.append(board.Move{ .from = from, .to = to_square, .promotion_piece = .Queen });
                                try moves.append(board.Move{ .from = from, .to = to_square, .promotion_piece = .Rook });
                                try moves.append(board.Move{ .from = from, .to = to_square, .promotion_piece = .Bishop });
                                try moves.append(board.Move{ .from = from, .to = to_square, .promotion_piece = .Knight });
                            } else {
                                try moves.append(board.Move{ .from = from, .to = to_square });
                            }
                        }
                    } else if (self.board_ref.en_passant_target == to_square) {
                        // En passant capture
                        try moves.append(board.Move{ .from = from, .to = to_square, .en_passant = true });
                    }
                }
            }
        }
    }

    fn generateKnightMoves(self: *MoveGenerator, from: u8, color: board.PieceColor, moves: *std.ArrayList(board.Move)) !void {
        const from_rank = @as(i8, @intCast(from / 8));
        const from_file = @as(i8, @intCast(from % 8));
        
        const knight_moves = [_][2]i8{
            .{ 2, 1 }, .{ 2, -1 }, .{ -2, 1 }, .{ -2, -1 },
            .{ 1, 2 }, .{ 1, -2 }, .{ -1, 2 }, .{ -1, -2 }
        };

        for (knight_moves) |move| {
            const to_rank = from_rank + move[0];
            const to_file = from_file + move[1];

            if (to_rank >= 0 and to_rank < 8 and to_file >= 0 and to_file < 8) {
                const to_square = @as(u8, @intCast(to_rank)) * 8 + @as(u8, @intCast(to_file));
                
                if (self.board_ref.squares[to_square]) |target_piece| {
                    if (target_piece.color != color) {
                        try moves.append(board.Move{ .from = from, .to = to_square });
                    }
                } else {
                    try moves.append(board.Move{ .from = from, .to = to_square });
                }
            }
        }
    }

    fn generateBishopMoves(self: *MoveGenerator, from: u8, color: board.PieceColor, moves: *std.ArrayList(board.Move)) !void {
        const directions = [_][2]i8{ .{ 1, 1 }, .{ 1, -1 }, .{ -1, 1 }, .{ -1, -1 } };
        try self.generateSlidingMoves(from, color, &directions, moves);
    }

    fn generateRookMoves(self: *MoveGenerator, from: u8, color: board.PieceColor, moves: *std.ArrayList(board.Move)) !void {
        const directions = [_][2]i8{ .{ 1, 0 }, .{ -1, 0 }, .{ 0, 1 }, .{ 0, -1 } };
        try self.generateSlidingMoves(from, color, &directions, moves);
    }

    fn generateQueenMoves(self: *MoveGenerator, from: u8, color: board.PieceColor, moves: *std.ArrayList(board.Move)) !void {
        const directions = [_][2]i8{
            .{ 1, 1 }, .{ 1, -1 }, .{ -1, 1 }, .{ -1, -1 },
            .{ 1, 0 }, .{ -1, 0 }, .{ 0, 1 }, .{ 0, -1 }
        };
        try self.generateSlidingMoves(from, color, &directions, moves);
    }

    fn generateSlidingMoves(self: *MoveGenerator, from: u8, color: board.PieceColor, directions: []const [2]i8, moves: *std.ArrayList(board.Move)) !void {
        const from_rank = @as(i8, @intCast(from / 8));
        const from_file = @as(i8, @intCast(from % 8));

        for (directions) |direction| {
            var rank = from_rank + direction[0];
            var file = from_file + direction[1];

            while (rank >= 0 and rank < 8 and file >= 0 and file < 8) {
                const to_square = @as(u8, @intCast(rank)) * 8 + @as(u8, @intCast(file));

                if (self.board_ref.squares[to_square]) |target_piece| {
                    if (target_piece.color != color) {
                        try moves.append(board.Move{ .from = from, .to = to_square });
                    }
                    break; // Can't move past any piece
                } else {
                    try moves.append(board.Move{ .from = from, .to = to_square });
                }

                rank += direction[0];
                file += direction[1];
            }
        }
    }

    fn generateKingMoves(self: *MoveGenerator, from: u8, color: board.PieceColor, moves: *std.ArrayList(board.Move)) !void {
        const from_rank = @as(i8, @intCast(from / 8));
        const from_file = @as(i8, @intCast(from % 8));

        const king_moves = [_][2]i8{
            .{ 1, 1 }, .{ 1, -1 }, .{ -1, 1 }, .{ -1, -1 },
            .{ 1, 0 }, .{ -1, 0 }, .{ 0, 1 }, .{ 0, -1 }
        };

        for (king_moves) |move| {
            const to_rank = from_rank + move[0];
            const to_file = from_file + move[1];

            if (to_rank >= 0 and to_rank < 8 and to_file >= 0 and to_file < 8) {
                const to_square = @as(u8, @intCast(to_rank)) * 8 + @as(u8, @intCast(to_file));
                
                if (self.board_ref.squares[to_square]) |target_piece| {
                    if (target_piece.color != color) {
                        try moves.append(board.Move{ .from = from, .to = to_square });
                    }
                } else {
                    try moves.append(board.Move{ .from = from, .to = to_square });
                }
            }
        }

        // Castling moves
        try self.generateCastlingMoves(from, color, moves);
    }

    fn generateCastlingMoves(self: *MoveGenerator, from: u8, color: board.PieceColor, moves: *std.ArrayList(board.Move)) !void {
        if (self.board_ref.isInCheck(color)) return; // Can't castle out of check

        if (color == .White and from == 4) {
            // White castling
            if (self.board_ref.castling_rights.white_king_side and
                self.board_ref.squares[5] == null and
                self.board_ref.squares[6] == null and
                self.board_ref.squares[7] != null and
                self.board_ref.squares[7].?.piece_type == .Rook) {
                
                // Check that king doesn't pass through check
                if (!self.wouldBeInCheck(4, 5, color) and !self.wouldBeInCheck(4, 6, color)) {
                    try moves.append(board.Move{ .from = from, .to = 6, .castle_king_side = true });
                }
            }

            if (self.board_ref.castling_rights.white_queen_side and
                self.board_ref.squares[3] == null and
                self.board_ref.squares[2] == null and
                self.board_ref.squares[1] == null and
                self.board_ref.squares[0] != null and
                self.board_ref.squares[0].?.piece_type == .Rook) {
                
                // Check that king doesn't pass through check
                if (!self.wouldBeInCheck(4, 3, color) and !self.wouldBeInCheck(4, 2, color)) {
                    try moves.append(board.Move{ .from = from, .to = 2, .castle_queen_side = true });
                }
            }
        } else if (color == .Black and from == 60) {
            // Black castling
            if (self.board_ref.castling_rights.black_king_side and
                self.board_ref.squares[61] == null and
                self.board_ref.squares[62] == null and
                self.board_ref.squares[63] != null and
                self.board_ref.squares[63].?.piece_type == .Rook) {
                
                // Check that king doesn't pass through check
                if (!self.wouldBeInCheck(60, 61, color) and !self.wouldBeInCheck(60, 62, color)) {
                    try moves.append(board.Move{ .from = from, .to = 62, .castle_king_side = true });
                }
            }

            if (self.board_ref.castling_rights.black_queen_side and
                self.board_ref.squares[59] == null and
                self.board_ref.squares[58] == null and
                self.board_ref.squares[57] == null and
                self.board_ref.squares[56] != null and
                self.board_ref.squares[56].?.piece_type == .Rook) {
                
                // Check that king doesn't pass through check
                if (!self.wouldBeInCheck(60, 59, color) and !self.wouldBeInCheck(60, 58, color)) {
                    try moves.append(board.Move{ .from = from, .to = 58, .castle_queen_side = true });
                }
            }
        }
    }

    fn wouldBeInCheck(self: *MoveGenerator, from: u8, to: u8, color: board.PieceColor) bool {
        // Temporarily make the move and check if in check
        const original_piece = self.board_ref.squares[from];
        const captured_piece = self.board_ref.squares[to];
        
        self.board_ref.squares[from] = null;
        self.board_ref.squares[to] = original_piece;
        
        const in_check = self.board_ref.isInCheck(color);
        
        // Restore original position
        self.board_ref.squares[from] = original_piece;
        self.board_ref.squares[to] = captured_piece;
        
        return in_check;
    }

    pub fn isMoveLegal(self: *MoveGenerator, move: board.Move) bool {
        _ = self;
        _ = move;
        // Simplified legal move check - would implement full validation
        return true;
    }
};