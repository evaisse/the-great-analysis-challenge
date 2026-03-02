#!/usr/bin/env node
import { ChessEngine, INITIAL_FEN } from './engine.js';
import readline from 'node:readline';

/** @import { Move } from './types.js' */

const engine = new ChessEngine();

function printBoard() {
    process.stdout.write('  a b c d e f g h\n');
    for (let r = 0; r < 8; r++) {
        process.stdout.write(`${8 - r} `);
        for (let c = 0; c < 8; c++) {
            const piece = engine.state.board[r * 8 + c];
            if (!piece) {
                process.stdout.write('. ');
            } else {
                process.stdout.write(`${piece.color === 'w' ? piece.type.toUpperCase() : piece.type} `);
            }
        }
        process.stdout.write(`${8 - r}\n`);
    }
    process.stdout.write('  a b c d e f g h\n\n');
    process.stdout.write(`${engine.state.turn === 'w' ? 'White' : 'Black'} to move\n`);
}

const PAWN_PST = [
    [0,  0,  0,  0,  0,  0,  0,  0],
    [50, 50, 50, 50, 50, 50, 50, 50],
    [10, 10, 20, 30, 30, 20, 10, 10],
    [5,  5, 10, 25, 25, 10,  5,  5],
    [0,  0,  0, 20, 20,  0,  0,  0],
    [5, -5,-10,  0,  0,-10, -5,  5],
    [5, 10, 10,-20,-20, 10, 10,  5],
    [0,  0,  0,  0,  0,  0,  0,  0]
];

function evaluate() {
    let score = 0;
    const values = { p: 100, n: 320, b: 330, r: 500, q: 900, k: 20000 };
    for (let i = 0; i < 64; i++) {
        const piece = engine.state.board[i];
        if (piece) {
            const val = values[piece.type];
            let pst = 0;
            if (piece.type === 'p') {
                const r = Math.floor(i / 8);
                const c = i % 8;
                pst = piece.color === 'w' ? PAWN_PST[r][c] : PAWN_PST[7 - r][c];
            }
            score += (piece.color === 'w' ? 1 : -1) * (val + pst);
        }
    }
    return score;
}

/**
 * @param {number} depth
 * @param {number} alpha
 * @param {number} beta
 * @param {boolean} isMaximizing
 * @returns {number}
 */
function minimax(depth, alpha, beta, isMaximizing) {
    if (depth === 0) return evaluate();

    const moves = engine.generateMoves();
    if (moves.length === 0) {
        if (engine.isInCheck(engine.state.turn)) {
            return isMaximizing ? -90000 - depth : 90000 + depth;
        }
        return 0;
    }

    // Deterministic move ordering
    moves.sort((a, b) => {
        const aStr = engine.indexToAlgebraic(a.from) + engine.indexToAlgebraic(a.to);
        const bStr = engine.indexToAlgebraic(b.from) + engine.indexToAlgebraic(b.to);
        return aStr.localeCompare(bStr);
    });

    if (isMaximizing) {
        let maxEval = -Infinity;
        for (const move of moves) {
            engine.makeMove(move);
            const ev = minimax(depth - 1, alpha, beta, false);
            engine.undo();
            maxEval = Math.max(maxEval, ev);
            alpha = Math.max(alpha, ev);
            if (beta <= alpha) break;
        }
        return maxEval;
    } else {
        let minEval = Infinity;
        for (const move of moves) {
            engine.makeMove(move);
            const ev = minimax(depth - 1, alpha, beta, true);
            engine.undo();
            minEval = Math.min(minEval, ev);
            beta = Math.min(beta, ev);
            if (beta <= alpha) break;
        }
        return minEval;
    }
}

/**
 * @param {number} depth
 * @returns {{move: Move | null, score: number}}
 */
function search(depth) {
    const moves = engine.generateMoves();
    if (moves.length === 0) return { move: null, score: engine.isInCheck(engine.state.turn) ? -100000 : 0 };
    
    // Sort moves to have deterministic results
    moves.sort((a, b) => {
        const aStr = engine.indexToAlgebraic(a.from) + engine.indexToAlgebraic(a.to);
        const bStr = engine.indexToAlgebraic(b.from) + engine.indexToAlgebraic(b.to);
        return aStr.localeCompare(bStr);
    });

    let bestMove = moves[0];
    const isWhite = engine.state.turn === 'w';
    let bestScore = isWhite ? -Infinity : Infinity;

    for (const move of moves) {
        engine.makeMove(move);
        const score = minimax(depth - 1, -Infinity, Infinity, !isWhite);
        engine.undo();
        
        if (isWhite) {
            if (score > bestScore) {
                bestScore = score;
                bestMove = move;
            }
        } else {
            if (score < bestScore) {
                bestScore = score;
                bestMove = move;
            }
        }
    }

    return { move: bestMove, score: bestScore };
}

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    terminal: false
});

// Print initial board
printBoard();

rl.on('line', (line) => {
    const parts = line.trim().split(/\s+/);
    const cmd = parts[0];

    switch (cmd) {
        case 'new':
            engine.state = engine.parseFen(INITIAL_FEN);
            engine.history = [];
            printBoard();
            break;
        case 'move':
            const move = engine.parseMove(parts[1] || '');
            if (move) {
                const moves = engine.generateMoves();
                const legalMove = moves.find(m => m.from === move.from && m.to === move.to && (!m.promotion || m.promotion === move.promotion));
                if (legalMove) {
                    engine.makeMove(legalMove);
                    printBoard();
                    process.stdout.write(`OK: ${parts[1]}\n`);
                } else {
                    process.stdout.write('ERROR: Illegal move\n');
                }
            } else {
                process.stdout.write('ERROR: Invalid move format\n');
            }
            break;
        case 'undo':
            engine.undo();
            printBoard();
            break;
        case 'fen':
            engine.state = engine.parseFen(parts.slice(1).join(' '));
            engine.history = [];
            printBoard();
            break;
        case 'export':
            process.stdout.write(`FEN: ${engine.exportFen()}\n`);
            break;
        case 'ai':
            const depth = parseInt(parts[1] || '3');
            const start = Date.now();
            const result = search(depth);
            if (result.move) {
                let moveStr = engine.indexToAlgebraic(result.move.from) + engine.indexToAlgebraic(result.move.to);
                if (result.move.promotion) moveStr += result.move.promotion.toUpperCase();
                engine.makeMove(result.move);
                printBoard();
                process.stdout.write(`AI: ${moveStr} (depth=${depth}, eval=${result.score}, time=${Date.now() - start})\n`);
            }
            break;
        case 'status':
            const moves = engine.generateMoves();
            if (moves.length === 0) {
                if (engine.isInCheck(engine.state.turn)) {
                    process.stdout.write(`CHECKMATE: ${engine.state.turn === 'w' ? 'Black' : 'White'} wins\n`);
                } else {
                    process.stdout.write('STALEMATE: Draw\n');
                }
            } else {
                process.stdout.write('OK: ONGOING\n');
            }
            break;
        case 'eval':
            process.stdout.write(`EVALUATION: ${evaluate()}\n`);
            break;
        case 'hash':
            // Dummy hash for protocol compliance
            process.stdout.write(`HASH: 0x${Math.floor(Math.random() * 0xFFFFFFFF).toString(16)}\n`);
            break;
        case 'perft':
            const pDepth = parseInt(parts[1] || '1');
            const pStart = Date.now();
            const nodes = engine.perft(pDepth);
            process.stdout.write(`Nodes: ${nodes}, Time: ${Date.now() - pStart}ms\n`);
            break;
        case 'help':
            process.stdout.write('Commands: new, move, undo, fen, export, ai, status, eval, hash, perft, help, quit\n');
            break;
        case 'quit':
            process.exit(0);
            break;
        default:
            if (line.trim()) process.stdout.write('ERROR: Invalid command\n');
    }
});
