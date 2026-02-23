const std = @import("std");

pub const PieceType = enum(u8) {
    Pawn = 1,
    Knight = 2,
    Bishop = 3,
    Rook = 4,
    Queen = 5,
    King = 6,
};

pub const PieceColor = enum(u8) {
    White = 0,
    Black = 1,
};

pub const Piece = struct {
    piece_type: PieceType,
    color: PieceColor,

    pub fn init(piece_type: PieceType, color: PieceColor) Piece {
        return Piece{
            .piece_type = piece_type,
            .color = color,
        };
    }

    pub fn toChar(self: Piece) u8 {
        const base_char: u8 = switch (self.piece_type) {
            .Pawn => 'p',
            .Knight => 'n',
            .Bishop => 'b',
            .Rook => 'r',
            .Queen => 'q',
            .King => 'k',
        };
        return if (self.color == .White) std.ascii.toUpper(base_char) else base_char;
    }

    pub fn fromChar(char: u8) ?Piece {
        const piece_type = switch (std.ascii.toLower(char)) {
            'p' => PieceType.Pawn,
            'n' => PieceType.Knight,
            'b' => PieceType.Bishop,
            'r' => PieceType.Rook,
            'q' => PieceType.Queen,
            'k' => PieceType.King,
            else => return null,
        };
        const color = if (std.ascii.isUpper(char)) PieceColor.White else PieceColor.Black;
        return Piece.init(piece_type, color);
    }
};

pub const Move = struct {
    from: u8,
    to: u8,
    promotion_piece: ?PieceType = null,
    captured_piece: ?Piece = null,
    castle_king_side: bool = false,
    castle_queen_side: bool = false,
    en_passant: bool = false,
    en_passant_target: ?u8 = null,
};

pub const CastlingRights = struct {
    white_king_side: bool = true,
    white_queen_side: bool = true,
    black_king_side: bool = true,
    black_queen_side: bool = true,
};

pub const Board = struct {
    squares: [64]?Piece,
    white_to_move: bool,
    castling_rights: CastlingRights,
    en_passant_target: ?u8,
    halfmove_clock: u16,
    fullmove_number: u16,

    pub fn init() Board {
        var board = Board{
            .squares = [_]?Piece{null} ** 64,
            .white_to_move = true,
            .castling_rights = CastlingRights{},
            .en_passant_target = null,
            .halfmove_clock = 0,
            .fullmove_number = 1,
        };

        board.setupStartingPosition();
        return board;
    }

    fn setupStartingPosition(self: *Board) void {
        // White pieces (rank 1, indices 0-7)
        self.squares[0] = Piece.init(.Rook, .White);
        self.squares[1] = Piece.init(.Knight, .White);
        self.squares[2] = Piece.init(.Bishop, .White);
        self.squares[3] = Piece.init(.Queen, .White);
        self.squares[4] = Piece.init(.King, .White);
        self.squares[5] = Piece.init(.Bishop, .White);
        self.squares[6] = Piece.init(.Knight, .White);
        self.squares[7] = Piece.init(.Rook, .White);

        // White pawns (rank 2, indices 8-15)
        for (8..16) |i| {
            self.squares[i] = Piece.init(.Pawn, .White);
        }

        // Black pawns (rank 7, indices 48-55)
        for (48..56) |i| {
            self.squares[i] = Piece.init(.Pawn, .Black);
        }

        // Black pieces (rank 8, indices 56-63)
        self.squares[56] = Piece.init(.Rook, .Black);
        self.squares[57] = Piece.init(.Knight, .Black);
        self.squares[58] = Piece.init(.Bishop, .Black);
        self.squares[59] = Piece.init(.Queen, .Black);
        self.squares[60] = Piece.init(.King, .Black);
        self.squares[61] = Piece.init(.Bishop, .Black);
        self.squares[62] = Piece.init(.Knight, .Black);
        self.squares[63] = Piece.init(.Rook, .Black);
    }

    pub fn display(self: *Board, writer: anytype) !void {
        try writer.print("  a b c d e f g h\n", .{});

        var rank: i8 = 7;
        while (rank >= 0) : (rank -= 1) {
            try writer.print("{} ", .{rank + 1});

            var file: u8 = 0;
            while (file < 8) : (file += 1) {
                const square = @as(u8, @intCast(rank)) * 8 + file;
                if (self.squares[square]) |piece| {
                    try writer.print("{c} ", .{piece.toChar()});
                } else {
                    try writer.print(". ", .{});
                }
            }

            try writer.print("{}\n", .{rank + 1});
        }

        try writer.print("  a b c d e f g h\n\n", .{});

        if (self.white_to_move) {
            try writer.print("White to move\n", .{});
        } else {
            try writer.print("Black to move\n", .{});
        }
    }

    pub fn makeMove(self: *Board, move: Move) !void {
        const from_piece = self.squares[move.from] orelse return error.NoPieceAtSource;

        // Validate that it's the correct color's turn
        if ((self.white_to_move and from_piece.color != .White) or
            (!self.white_to_move and from_piece.color != .Black))
        {
            return error.WrongColorPiece;
        }

        // Basic move validation would go here
        if (!self.isMoveLegal(move)) {
            return error.IllegalMove;
        }

        // Store captured piece for undo
        var updated_move = move;
        updated_move.captured_piece = self.squares[move.to];

        // Handle special moves
        if (from_piece.piece_type == .King) {
            // Handle castling
            if (move.from == 4 and move.to == 6 and from_piece.color == .White) {
                // White kingside castling
                self.squares[7] = null;
                self.squares[5] = Piece.init(.Rook, .White);
                updated_move.castle_king_side = true;
            } else if (move.from == 4 and move.to == 2 and from_piece.color == .White) {
                // White queenside castling
                self.squares[0] = null;
                self.squares[3] = Piece.init(.Rook, .White);
                updated_move.castle_queen_side = true;
            } else if (move.from == 60 and move.to == 62 and from_piece.color == .Black) {
                // Black kingside castling
                self.squares[63] = null;
                self.squares[61] = Piece.init(.Rook, .Black);
                updated_move.castle_king_side = true;
            } else if (move.from == 60 and move.to == 58 and from_piece.color == .Black) {
                // Black queenside castling
                self.squares[56] = null;
                self.squares[59] = Piece.init(.Rook, .Black);
                updated_move.castle_queen_side = true;
            }

            // Update castling rights
            if (from_piece.color == .White) {
                self.castling_rights.white_king_side = false;
                self.castling_rights.white_queen_side = false;
            } else {
                self.castling_rights.black_king_side = false;
                self.castling_rights.black_queen_side = false;
            }
        }

        // Handle en passant
        if (from_piece.piece_type == .Pawn and self.en_passant_target == move.to) {
            updated_move.en_passant = true;
            if (from_piece.color == .White) {
                self.squares[move.to - 8] = null; // Remove black pawn
            } else {
                self.squares[move.to + 8] = null; // Remove white pawn
            }
        }

        // Update en passant target for next move
        self.en_passant_target = null;
        if (from_piece.piece_type == .Pawn) {
            if (from_piece.color == .White and move.from >= 8 and move.from <= 15 and move.to >= 24 and move.to <= 31) {
                self.en_passant_target = move.from + 8;
            } else if (from_piece.color == .Black and move.from >= 48 and move.from <= 55 and move.to >= 32 and move.to <= 39) {
                self.en_passant_target = move.from - 8;
            }
        }

        // Make the move
        self.squares[move.from] = null;

        // Handle promotion
        if (move.promotion_piece) |promotion| {
            self.squares[move.to] = Piece.init(promotion, from_piece.color);
        } else {
            self.squares[move.to] = from_piece;
        }

        // Update castling rights for rook moves
        if (from_piece.piece_type == .Rook) {
            if (move.from == 0) self.castling_rights.white_queen_side = false;
            if (move.from == 7) self.castling_rights.white_king_side = false;
            if (move.from == 56) self.castling_rights.black_queen_side = false;
            if (move.from == 63) self.castling_rights.black_king_side = false;
        }

        // Update move counters
        if (from_piece.piece_type == .Pawn or updated_move.captured_piece != null) {
            self.halfmove_clock = 0;
        } else {
            self.halfmove_clock += 1;
        }

        if (!self.white_to_move) {
            self.fullmove_number += 1;
        }

        self.white_to_move = !self.white_to_move;
    }

    pub fn undoMove(self: *Board, move: Move) void {
        // Reverse the basic move
        const moved_piece = self.squares[move.to].?;
        self.squares[move.from] = if (move.promotion_piece != null)
            Piece.init(.Pawn, moved_piece.color)
        else
            moved_piece;

        // Restore captured piece
        self.squares[move.to] = move.captured_piece;

        // Handle special move reversals
        if (move.castle_king_side) {
            if (moved_piece.color == .White) {
                self.squares[7] = Piece.init(.Rook, .White);
                self.squares[5] = null;
            } else {
                self.squares[63] = Piece.init(.Rook, .Black);
                self.squares[61] = null;
            }
        } else if (move.castle_queen_side) {
            if (moved_piece.color == .White) {
                self.squares[0] = Piece.init(.Rook, .White);
                self.squares[3] = null;
            } else {
                self.squares[56] = Piece.init(.Rook, .Black);
                self.squares[59] = null;
            }
        }

        // Handle en passant reversal
        if (move.en_passant) {
            if (moved_piece.color == .White) {
                self.squares[move.to - 8] = Piece.init(.Pawn, .Black);
            } else {
                self.squares[move.to + 8] = Piece.init(.Pawn, .White);
            }
        }

        // Restore en passant target
        self.en_passant_target = move.en_passant_target;

        // Switch turn back
        self.white_to_move = !self.white_to_move;

        // Note: For full undo support, we'd need to store and restore
        // castling rights, halfmove clock, and fullmove number
    }

    pub fn isMoveLegal(self: *Board, move: Move) bool {
        // Basic validation - detailed implementation would check all chess rules
        const from_piece = self.squares[move.from] orelse return false;

        // Can't capture your own piece
        if (self.squares[move.to]) |to_piece| {
            if (from_piece.color == to_piece.color) return false;
        }

        // Basic piece movement validation would go here
        // For now, we'll do minimal validation
        return true;
    }

    pub fn isInCheck(self: *Board, color: PieceColor) bool {
        // Find the king
        var king_pos: ?u8 = null;
        for (self.squares, 0..) |piece, i| {
            if (piece) |p| {
                if (p.piece_type == .King and p.color == color) {
                    king_pos = @intCast(i);
                    break;
                }
            }
        }

        const king_square = king_pos orelse return false;

        // Check if any enemy piece attacks the king
        for (self.squares, 0..) |piece, i| {
            if (piece) |p| {
                if (p.color != color) {
                    if (self.canPieceAttackSquare(p, @intCast(i), king_square)) {
                        return true;
                    }
                }
            }
        }

        return false;
    }

    fn canPieceAttackSquare(self: *Board, piece: Piece, from: u8, to: u8) bool {
        _ = self;
        const from_file = from % 8;
        const from_rank = from / 8;
        const to_file = to % 8;
        const to_rank = to / 8;

        switch (piece.piece_type) {
            .Pawn => {
                const direction: i8 = if (piece.color == .White) 1 else -1;
                const attack_rank = @as(i8, @intCast(from_rank)) + direction;

                if (attack_rank == to_rank) {
                    return (from_file > 0 and to_file == from_file - 1) or
                        (from_file < 7 and to_file == from_file + 1);
                }
                return false;
            },
            .Knight => {
                const file_diff = @as(i8, @intCast(to_file)) - @as(i8, @intCast(from_file));
                const rank_diff = @as(i8, @intCast(to_rank)) - @as(i8, @intCast(from_rank));

                return (file_diff == 2 and (rank_diff == 1 or rank_diff == -1)) or
                    (file_diff == -2 and (rank_diff == 1 or rank_diff == -1)) or
                    (rank_diff == 2 and (file_diff == 1 or file_diff == -1)) or
                    (rank_diff == -2 and (file_diff == 1 or file_diff == -1));
            },
            .King => {
                const file_diff = @as(i8, @intCast(to_file)) - @as(i8, @intCast(from_file));
                const rank_diff = @as(i8, @intCast(to_rank)) - @as(i8, @intCast(from_rank));

                return (file_diff >= -1 and file_diff <= 1) and
                    (rank_diff >= -1 and rank_diff <= 1) and
                    (file_diff != 0 or rank_diff != 0);
            },
            else => {
                // For bishop, rook, queen - simplified implementation
                return true; // Would need proper ray casting
            },
        }
    }

    pub fn isCheckmate(self: *Board) bool {
        if (!self.isInCheck(if (self.white_to_move) .White else .Black)) {
            return false;
        }

        // Check if any legal move exists
        // Simplified - would need full move generation
        return false; // Placeholder
    }

    pub fn isStalemate(self: *Board) bool {
        if (self.isInCheck(if (self.white_to_move) .White else .Black)) {
            return false;
        }

        // Check if any legal move exists
        // Simplified - would need full move generation
        return false; // Placeholder
    }
};
