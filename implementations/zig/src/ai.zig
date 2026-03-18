const std = @import("std");
const board = @import("board.zig");
const move_gen = @import("move_generator.zig");

pub const AI = struct {
    board_ref: *board.Board,
    last_evaluation: i32,
    nodes_searched: u64,

    pub fn init(board_ref: *board.Board) AI {
        return AI{
            .board_ref = board_ref,
            .last_evaluation = 0,
            .nodes_searched = 0,
        };
    }

    pub fn getBestMove(self: *AI, depth: u8) ?board.Move {
        self.nodes_searched = 0;

        const allocator = std.heap.page_allocator;
        var legal_moves = self.generateFilteredLegalMoves(allocator) catch return null;
        defer legal_moves.deinit(allocator);

        if (legal_moves.items.len == 0) return null;

        var best_move = legal_moves.items[0];
        var best_score: i32 = if (self.board_ref.white_to_move) -999999 else 999999;
        const maximizing = self.board_ref.white_to_move;

        for (legal_moves.items) |move| {
            const original_state = self.board_ref.*;
            self.board_ref.makeMove(move) catch continue;

            const score = self.minimax(depth - 1, -999999, 999999);

            self.board_ref.* = original_state;

            if (maximizing) {
                if (score > best_score) {
                    best_score = score;
                    best_move = move;
                }
            } else {
                if (score < best_score) {
                    best_score = score;
                    best_move = move;
                }
            }
        }

        self.last_evaluation = best_score;
        return best_move;
    }

    fn minimax(self: *AI, depth: u8, alpha: i32, beta: i32) i32 {
        self.nodes_searched += 1;

        const allocator = std.heap.page_allocator;
        var legal_moves = self.generateFilteredLegalMoves(allocator) catch return self.evaluatePosition();
        defer legal_moves.deinit(allocator);
        const current_color: board.PieceColor = if (self.board_ref.white_to_move) .White else .Black;
        const in_check = self.board_ref.isInCheck(current_color);

        if (legal_moves.items.len == 0) {
            if (in_check) {
                return if (self.board_ref.white_to_move) -100000 else 100000;
            }
            return 0;
        }

        if (depth == 0) {
            return self.evaluatePosition();
        }

        var current_alpha = alpha;
        var current_beta = beta;
        const maximizing = self.board_ref.white_to_move;

        if (maximizing) {
            var max_eval: i32 = -999999;

            for (legal_moves.items) |move| {
                const original_state = self.board_ref.*;
                self.board_ref.makeMove(move) catch continue;

                const eval = self.minimax(depth - 1, current_alpha, current_beta);

                self.board_ref.* = original_state;

                max_eval = @max(max_eval, eval);
                current_alpha = @max(current_alpha, eval);

                if (current_beta <= current_alpha) {
                    break; // Beta cutoff
                }
            }

            return max_eval;
        } else {
            var min_eval: i32 = 999999;

            for (legal_moves.items) |move| {
                const original_state = self.board_ref.*;
                self.board_ref.makeMove(move) catch continue;

                const eval = self.minimax(depth - 1, current_alpha, current_beta);

                self.board_ref.* = original_state;

                min_eval = @min(min_eval, eval);
                current_beta = @min(current_beta, eval);

                if (current_beta <= current_alpha) {
                    break; // Alpha cutoff
                }
            }

            return min_eval;
        }
    }

    pub fn evaluatePosition(self: *AI) i32 {
        var score: i32 = 0;

        // Material evaluation
        for (self.board_ref.squares, 0..) |piece, i| {
            if (piece) |p| {
                var piece_value = self.getPieceValue(p.piece_type);

                // Add positional bonuses
                piece_value += self.getPositionalBonus(p, @intCast(i));

                if (p.color == .White) {
                    score += piece_value;
                } else {
                    score -= piece_value;
                }
            }
        }

        return score;
    }

    fn getPieceValue(self: *AI, piece_type: board.PieceType) i32 {
        _ = self;
        return switch (piece_type) {
            .Pawn => 100,
            .Knight => 320,
            .Bishop => 330,
            .Rook => 500,
            .Queen => 900,
            .King => 20000,
        };
    }

    fn getPositionalBonus(self: *AI, piece: board.Piece, square: u8) i32 {
        _ = self;
        const file = square % 8;
        const rank = square / 8;
        var bonus: i32 = 0;

        // Center control bonus
        if ((file == 3 or file == 4) and (rank == 3 or rank == 4)) {
            bonus += 10;
        }

        // Pawn advancement bonus
        if (piece.piece_type == .Pawn) {
            if (piece.color == .White) {
                bonus += @as(i32, @intCast(rank)) * 5;
            } else {
                bonus += @as(i32, @intCast(7 - rank)) * 5;
            }
        }

        // King safety penalty for exposed king
        if (piece.piece_type == .King) {
            // Simplified king safety - penalize king in center during opening/middlegame
            if ((file >= 2 and file <= 5) and (rank >= 2 and rank <= 5)) {
                bonus -= 20;
            }
        }

        return bonus;
    }

    pub fn getLastEvaluation(self: *AI) i32 {
        return self.last_evaluation;
    }

    pub fn getNodesSearched(self: *AI) u64 {
        return self.nodes_searched;
    }

    fn generateFilteredLegalMoves(self: *AI, allocator: std.mem.Allocator) !std.ArrayList(board.Move) {
        var move_generator = move_gen.MoveGenerator.init(self.board_ref);
        var pseudo_moves = try move_generator.generateLegalMoves(allocator);
        defer pseudo_moves.deinit(allocator);

        var legal_moves = std.ArrayList(board.Move).empty;
        errdefer legal_moves.deinit(allocator);

        const current_color: board.PieceColor = if (self.board_ref.white_to_move) .White else .Black;
        for (pseudo_moves.items) |move| {
            const snapshot = self.board_ref.*;
            self.board_ref.makeMove(move) catch {
                self.board_ref.* = snapshot;
                continue;
            };

            if (!self.board_ref.isInCheck(current_color)) {
                try legal_moves.append(allocator, move);
            }

            self.board_ref.* = snapshot;
        }

        return legal_moves;
    }
};
