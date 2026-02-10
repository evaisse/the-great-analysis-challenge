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

function evaluate() {
    let score = 0;
    const values = { p: 100, n: 320, b: 330, r: 500, q: 900, k: 20000 };
    for (const piece of engine.state.board) {
        if (piece) {
            score += (piece.color === 'w' ? 1 : -1) * values[piece.type];
        }
    }
    return score;
}

/**
 * @param {number} depth
 * @returns {{move: Move, score: number}}
 */
function search(depth) {
    const moves = engine.generateMoves();
    if (moves.length === 0) return { move: null, score: engine.isInCheck(engine.state.turn) ? -100000 : 0 };
    
    // Simple minimax for demo purposes
    let bestMove = moves[0];
    let bestScore = -Infinity;

    for (const move of moves) {
        engine.makeMove(move);
        const score = -evaluate(); // Simplified
        engine.undo();
        if (score > bestScore) {
            bestScore = score;
            bestMove = move;
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
    const parts = line.trim().split(' ');
    const cmd = parts[0];

    switch (cmd) {
        case 'new':
            engine.state = engine.parseFen(INITIAL_FEN);
            printBoard();
            break;
        case 'move':
            const move = engine.parseMove(parts[1]);
            if (move) {
                engine.makeMove(move);
                printBoard();
                process.stdout.write(`OK: ${parts[1]}\n`);
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
                const moveStr = engine.indexToAlgebraic(result.move.from) + engine.indexToAlgebraic(result.move.to);
                engine.makeMove(result.move);
                printBoard();
                process.stdout.write(`AI: ${moveStr} (depth=${depth}, eval=${result.score}, time=${Date.now() - start})\n`);
            }
            break;
        case 'help':
            process.stdout.write('Commands: new, move, undo, fen, export, ai, help, quit\n');
            break;
        case 'quit':
            process.exit(0);
            break;
        default:
            if (line.trim()) process.stdout.write('ERROR: Invalid command\n');
    }
});
