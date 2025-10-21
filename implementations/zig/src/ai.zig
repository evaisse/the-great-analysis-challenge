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
        
        var allocator = std.heap.page_allocator;
        var move_generator = move_gen.MoveGenerator.init(self.board_ref);
        
        const legal_moves = move_generator.generateLegalMoves(allocator) catch return null;
        defer legal_moves.deinit();
        
        if (legal_moves.items.len == 0) return null;
        
        var best_move = legal_moves.items[0];
        var best_score: i32 = if (self.board_ref.white_to_move) -999999 else 999999;
        
        for (legal_moves.items) |move| {
            // Make the move
            const original_state = self.saveGameState();
            self.board_ref.makeMove(move) catch continue;
            
            // Evaluate the position after the move
            const score = self.minimax(depth - 1, -999999, 999999, !self.board_ref.white_to_move);
            
            // Restore the original position
            self.restoreGameState(original_state);
            self.board_ref.undoMove(move);
            
            // Update best move
            if (self.board_ref.white_to_move) {
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

    fn minimax(self: *AI, depth: u8, alpha: i32, beta: i32, maximizing: bool) i32 {
        self.nodes_searched += 1;
        
        if (depth == 0) {
            return self.evaluatePosition();
        }
        
        // Check for game end
        if (self.board_ref.isCheckmate()) {
            return if (maximizing) -100000 else 100000;
        }
        
        if (self.board_ref.isStalemate()) {
            return 0;
        }
        
        var allocator = std.heap.page_allocator;
        var move_generator = move_gen.MoveGenerator.init(self.board_ref);
        
        const legal_moves = move_generator.generateLegalMoves(allocator) catch return 0;
        defer legal_moves.deinit();
        
        if (legal_moves.items.len == 0) {
            return 0; // Stalemate
        }
        
        var current_alpha = alpha;
        var current_beta = beta;
        
        if (maximizing) {
            var max_eval: i32 = -999999;
            
            for (legal_moves.items) |move| {
                const original_state = self.saveGameState();
                self.board_ref.makeMove(move) catch continue;
                
                const eval = self.minimax(depth - 1, current_alpha, current_beta, false);
                
                self.restoreGameState(original_state);
                self.board_ref.undoMove(move);
                
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
                const original_state = self.saveGameState();
                self.board_ref.makeMove(move) catch continue;
                
                const eval = self.minimax(depth - 1, current_alpha, current_beta, true);
                
                self.restoreGameState(original_state);
                self.board_ref.undoMove(move);
                
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

    // Helper functions for game state management
    const GameState = struct {
        white_to_move: bool,
        castling_rights: board.CastlingRights,
        en_passant_target: ?u8,
        halfmove_clock: u16,
        fullmove_number: u16,
    };

    fn saveGameState(self: *AI) GameState {
        return GameState{
            .white_to_move = self.board_ref.white_to_move,
            .castling_rights = self.board_ref.castling_rights,
            .en_passant_target = self.board_ref.en_passant_target,
            .halfmove_clock = self.board_ref.halfmove_clock,
            .fullmove_number = self.board_ref.fullmove_number,
        };
    }

    fn restoreGameState(self: *AI, state: GameState) void {
        self.board_ref.white_to_move = state.white_to_move;
        self.board_ref.castling_rights = state.castling_rights;
        self.board_ref.en_passant_target = state.en_passant_target;
        self.board_ref.halfmove_clock = state.halfmove_clock;
        self.board_ref.fullmove_number = state.fullmove_number;
    }
};