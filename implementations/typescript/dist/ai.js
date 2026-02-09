"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AI = void 0;
const types_1 = require("./types");
const transpositionTable_1 = require("./transpositionTable");
class AI {
    constructor(board, moveGenerator) {
        this.nodesEvaluated = 0;
        this.board = board;
        this.moveGenerator = moveGenerator;
        this.tt = new transpositionTable_1.TranspositionTable(16);
    }
    getTranspositionTable() {
        return this.tt;
    }
    findBestMove(depth) {
        const startTime = Date.now();
        this.nodesEvaluated = 0;
        const color = this.board.getTurn();
        const moves = this.moveGenerator.getLegalMoves(color);
        if (moves.length === 0) {
            return { move: null, eval: 0, nodes: 0, time: 0 };
        }
        let bestMove = moves[0];
        let bestEval = color === "white" ? -Infinity : Infinity;
        const alpha = -Infinity;
        const beta = Infinity;
        for (const move of moves) {
            const state = this.board.getState();
            this.board.makeMove(move);
            const evaluation = this.minimax(depth - 1, alpha, beta, color === "black");
            this.board.setState(state);
            if (color === "white" && evaluation > bestEval) {
                bestEval = evaluation;
                bestMove = move;
            }
            else if (color === "black" && evaluation < bestEval) {
                bestEval = evaluation;
                bestMove = move;
            }
        }
        const endTime = Date.now();
        return {
            move: bestMove,
            eval: bestEval,
            nodes: this.nodesEvaluated,
            time: endTime - startTime,
        };
    }
    minimax(depth, alpha, beta, maximizing) {
        this.nodesEvaluated++;
        // Probe transposition table
        const hash = this.board.getHash();
        const originalAlpha = alpha;
        const ttEntry = this.tt.probe(hash);
        if (ttEntry && ttEntry.depth >= depth) {
            if (ttEntry.bound === transpositionTable_1.BoundType.Exact) {
                return ttEntry.score;
            }
            else if (ttEntry.bound === transpositionTable_1.BoundType.LowerBound) {
                alpha = Math.max(alpha, ttEntry.score);
            }
            else if (ttEntry.bound === transpositionTable_1.BoundType.UpperBound) {
                beta = Math.min(beta, ttEntry.score);
            }
            if (alpha >= beta) {
                return ttEntry.score;
            }
        }
        if (depth === 0) {
            const score = this.evaluate();
            this.tt.store(hash, 0, score, transpositionTable_1.BoundType.Exact, null);
            return score;
        }
        const color = this.board.getTurn();
        const moves = this.moveGenerator.getLegalMoves(color);
        if (moves.length === 0) {
            const score = this.moveGenerator.isInCheck(color)
                ? (maximizing ? -100000 : 100000)
                : 0;
            this.tt.store(hash, depth, score, transpositionTable_1.BoundType.Exact, null);
            return score;
        }
        if (maximizing) {
            let maxEval = -Infinity;
            let bestMove = null;
            for (const move of moves) {
                const state = this.board.getState();
                this.board.makeMove(move);
                const evaluation = this.minimax(depth - 1, alpha, beta, false);
                this.board.setState(state);
                if (evaluation > maxEval) {
                    maxEval = evaluation;
                    bestMove = (0, transpositionTable_1.encodeMove)(move.from, move.to);
                }
                alpha = Math.max(alpha, evaluation);
                if (beta <= alpha) {
                    break;
                }
            }
            // Determine bound type
            const bound = maxEval <= originalAlpha
                ? transpositionTable_1.BoundType.UpperBound
                : maxEval >= beta
                    ? transpositionTable_1.BoundType.LowerBound
                    : transpositionTable_1.BoundType.Exact;
            this.tt.store(hash, depth, maxEval, bound, bestMove);
            return maxEval;
        }
        else {
            let minEval = Infinity;
            let bestMove = null;
            for (const move of moves) {
                const state = this.board.getState();
                this.board.makeMove(move);
                const evaluation = this.minimax(depth - 1, alpha, beta, true);
                this.board.setState(state);
                if (evaluation < minEval) {
                    minEval = evaluation;
                    bestMove = (0, transpositionTable_1.encodeMove)(move.from, move.to);
                }
                beta = Math.min(beta, evaluation);
                if (beta <= alpha) {
                    break;
                }
            }
            // Determine bound type
            const bound = minEval <= alpha
                ? transpositionTable_1.BoundType.LowerBound
                : minEval >= beta
                    ? transpositionTable_1.BoundType.UpperBound
                    : transpositionTable_1.BoundType.Exact;
            this.tt.store(hash, depth, minEval, bound, bestMove);
            return minEval;
        }
    }
    evaluate() {
        let score = 0;
        for (let square = 0; square < 64; square++) {
            const piece = this.board.getPiece(square);
            if (piece) {
                const value = types_1.PIECE_VALUES[piece.type];
                const positionBonus = this.getPositionBonus(square, piece.type, piece.color);
                const totalValue = value + positionBonus;
                score += piece.color === "white" ? totalValue : -totalValue;
            }
        }
        return score;
    }
    getPositionBonus(square, pieceType, color) {
        const file = square % 8;
        const rank = Math.floor(square / 8);
        let bonus = 0;
        const centerSquares = [27, 28, 35, 36];
        if (centerSquares.includes(square)) {
            bonus += 10;
        }
        if (pieceType === "P") {
            const advancement = color === "white" ? rank : 7 - rank;
            bonus += advancement * 5;
        }
        if (pieceType === "K") {
            const isEndgame = this.isEndgame();
            if (!isEndgame) {
                const kingSafetyRow = color === "white" ? 0 : 7;
                if (rank === kingSafetyRow && (file <= 2 || file >= 5)) {
                    bonus += 20;
                }
                else {
                    bonus -= 20;
                }
            }
        }
        return bonus;
    }
    isEndgame() {
        let pieceCount = 0;
        let queenCount = 0;
        for (let square = 0; square < 64; square++) {
            const piece = this.board.getPiece(square);
            if (piece) {
                if (piece.type !== "K" && piece.type !== "P") {
                    pieceCount++;
                    if (piece.type === "Q") {
                        queenCount++;
                    }
                }
            }
        }
        return pieceCount <= 4 || (pieceCount <= 6 && queenCount === 0) ? 1 : 0;
    }
}
exports.AI = AI;
//# sourceMappingURL=ai.js.map