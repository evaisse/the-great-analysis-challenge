"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.extractPV = extractPV;
exports.iterativeDeepening = iterativeDeepening;
const board_1 = require("./board");
const transpositionTable_1 = require("./transpositionTable");
const MATE_SCORE = 100000;
const MAX_DEPTH = 100;
function extractPV(board, tt, depth) {
    const pv = [];
    const seen = new Set();
    const boardCopy = new board_1.Board();
    boardCopy.setState(board.getState());
    let currentDepth = depth;
    while (currentDepth > 0) {
        const hash = boardCopy.getHash();
        const hashStr = hash.toString();
        if (seen.has(hashStr)) {
            break;
        }
        const entry = tt.probe(hash);
        if (!entry || entry.bestMove === null) {
            break;
        }
        seen.add(hashStr);
        const [from, to] = (0, transpositionTable_1.decodeMove)(entry.bestMove);
        const moveStr = boardCopy.squareToAlgebraic(from) + boardCopy.squareToAlgebraic(to);
        pv.push(moveStr);
        // Try to make the move
        const legalMoves = boardCopy.getLegalMovesForPV();
        let found = false;
        for (const move of legalMoves) {
            if (move.from === from && move.to === to) {
                boardCopy.makeMove(move);
                found = true;
                break;
            }
        }
        if (!found) {
            break;
        }
        currentDepth--;
    }
    return pv;
}
function iterativeDeepening(board, maxDepth, timeManager, ai) {
    let bestMove = null;
    let bestScore = 0;
    let depthReached = 0;
    for (let depth = 1; depth <= maxDepth; depth++) {
        if (timeManager.shouldStop()) {
            break;
        }
        // Check if we should start this iteration
        if (!timeManager.shouldContinueIteration(depth - 1)) {
            break;
        }
        const result = ai.findBestMove(depth);
        // Check if search was interrupted
        if (timeManager.searchWasInterrupted()) {
            break;
        }
        // Update best move and score
        if (result.move !== null) {
            bestMove = result.move;
            bestScore = result.eval;
            depthReached = depth;
            // Extract PV
            const pv = extractPV(board, ai.getTranspositionTable(), depth);
            const pvStr = pv.join(" ");
            // Print info line
            console.log(`info depth ${depth} score cp ${bestScore} nodes ${result.nodes} time ${timeManager.elapsedMs()} pv ${pvStr}`);
            // Report to time manager
            const bestMoveEncoded = (bestMove.from | (bestMove.to << 6));
            timeManager.reportIteration(depth, bestScore, bestMoveEncoded);
            // Early exit if mate found
            if (Math.abs(bestScore) >= MATE_SCORE - MAX_DEPTH) {
                break;
            }
        }
        else {
            // No legal moves
            break;
        }
    }
    return {
        bestMove,
        bestScore,
        depthReached,
    };
}
//# sourceMappingURL=iterativeDeepening.js.map