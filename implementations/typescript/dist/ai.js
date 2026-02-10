"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AI = void 0;
const types_1 = require("./types");
class AI {
    constructor(board, moveGenerator) {
        this.nodesEvaluated = 0;
        this.board = board;
        this.moveGenerator = moveGenerator;
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
            this.board.makeMove(move);
            const evaluation = this.minimax(depth - 1, alpha, beta, color === "black");
            this.board.undoMove();
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
        if (depth === 0) {
            return this.evaluate();
        }
        const color = this.board.getTurn();
        const moves = this.moveGenerator.getLegalMoves(color);
        if (moves.length === 0) {
            if (this.moveGenerator.isInCheck(color)) {
                return maximizing ? -100000 : 100000;
            }
            return 0;
        }
        if (maximizing) {
            let maxEval = -Infinity;
            for (const move of moves) {
                this.board.makeMove(move);
                const evaluation = this.minimax(depth - 1, alpha, beta, false);
                this.board.undoMove();
                maxEval = Math.max(maxEval, evaluation);
                alpha = Math.max(alpha, evaluation);
                if (beta <= alpha) {
                    break;
                }
            }
            return maxEval;
        }
        else {
            let minEval = Infinity;
            for (const move of moves) {
                this.board.makeMove(move);
                const evaluation = this.minimax(depth - 1, alpha, beta, true);
                this.board.undoMove();
                minEval = Math.min(minEval, evaluation);
                beta = Math.min(beta, evaluation);
                if (beta <= alpha) {
                    break;
                }
            }
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