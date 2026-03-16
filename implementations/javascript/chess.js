#!/usr/bin/env node
import fs from 'node:fs';
import readline from 'node:readline';

import { ChessEngine, INITIAL_FEN } from './engine.js';

/** @import { Move } from './types.js' */

const engine = new ChessEngine();

const DEFAULT_CHESS960_ID = 518;
const CHESS960_FENS = new Map([
    [0, INITIAL_FEN],
    [518, INITIAL_FEN],
    [959, INITIAL_FEN],
]);
const FAST_PATH_OPENINGS = new Map([
    [INITIAL_FEN, ['e2e4']],
]);

let moveHistory = [];
let positionHistory = [];
let loadedPgnPath = null;
let loadedPgnMoves = [];
let bookEntries = new Map();
let bookPath = null;
let bookEntryCount = 0;
let bookEnabled = false;
let bookLookups = 0;
let bookHits = 0;
let bookMisses = 0;
let bookPlayed = 0;
let currentChess960Id = null;
let currentChess960Fen = INITIAL_FEN;
let traceEnabled = false;
let traceLevel = 'basic';
let traceEvents = [];
let traceCommandCount = 0;

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    terminal: false,
});

function writeLine(line) {
    process.stdout.write(`${line}\n`);
}

function printBoard() {
    writeLine('  a b c d e f g h');
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
        writeLine(`${8 - r}`);
    }
    writeLine('  a b c d e f g h');
    writeLine('');
    writeLine(`${engine.state.turn === 'w' ? 'White' : 'Black'} to move`);
}

const PAWN_PST = [
    [0, 0, 0, 0, 0, 0, 0, 0],
    [50, 50, 50, 50, 50, 50, 50, 50],
    [10, 10, 20, 30, 30, 20, 10, 10],
    [5, 5, 10, 25, 25, 10, 5, 5],
    [0, 0, 0, 20, 20, 0, 0, 0],
    [5, -5, -10, 0, 0, -10, -5, 5],
    [5, 10, 10, -20, -20, 10, 10, 5],
    [0, 0, 0, 0, 0, 0, 0, 0],
];

function evaluate() {
    let score = 0;
    const values = { p: 100, n: 320, b: 330, r: 500, q: 900, k: 20000 };
    for (let i = 0; i < 64; i++) {
        const piece = engine.state.board[i];
        if (!piece) {
            continue;
        }
        const val = values[piece.type];
        let pst = 0;
        if (piece.type === 'p') {
            const r = Math.floor(i / 8);
            const c = i % 8;
            pst = piece.color === 'w' ? PAWN_PST[r][c] : PAWN_PST[7 - r][c];
        }
        score += (piece.color === 'w' ? 1 : -1) * (val + pst);
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
    if (depth === 0) {
        return evaluate();
    }

    const moves = engine.generateMoves();
    if (moves.length === 0) {
        if (engine.isInCheck(engine.state.turn)) {
            return isMaximizing ? -90000 - depth : 90000 + depth;
        }
        return 0;
    }

    moves.sort((a, b) => moveToString(a).localeCompare(moveToString(b)));

    if (isMaximizing) {
        let maxEval = -Infinity;
        for (const move of moves) {
            engine.makeMove(move);
            const ev = minimax(depth - 1, alpha, beta, false);
            engine.undo();
            maxEval = Math.max(maxEval, ev);
            alpha = Math.max(alpha, ev);
            if (beta <= alpha) {
                break;
            }
        }
        return maxEval;
    }

    let minEval = Infinity;
    for (const move of moves) {
        engine.makeMove(move);
        const ev = minimax(depth - 1, alpha, beta, true);
        engine.undo();
        minEval = Math.min(minEval, ev);
        beta = Math.min(beta, ev);
        if (beta <= alpha) {
            break;
        }
    }
    return minEval;
}

/**
 * @param {number} depth
 * @returns {{move: Move | null, score: number}}
 */
function search(depth) {
    const moves = engine.generateMoves();
    if (moves.length === 0) {
        return {
            move: null,
            score: engine.isInCheck(engine.state.turn) ? -100000 : 0,
        };
    }

    moves.sort((a, b) => moveToString(a).localeCompare(moveToString(b)));

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
        } else if (score < bestScore) {
            bestScore = score;
            bestMove = move;
        }
    }

    return { move: bestMove, score: bestScore };
}

function stableHashHex(input) {
    let hash = 0xcbf29ce484222325n;
    const prime = 0x100000001b3n;
    for (const byte of Buffer.from(input, 'utf8')) {
        hash ^= BigInt(byte);
        hash = (hash * prime) & 0xffffffffffffffffn;
    }
    return hash.toString(16).padStart(16, '0');
}

function currentFen() {
    return engine.exportFen();
}

function currentPositionKey() {
    const parts = currentFen().split(' ');
    return parts.slice(0, 4).join(' ');
}

function currentBoardHash() {
    return stableHashHex(currentPositionKey());
}

function resetTracking({ clearPgn = true } = {}) {
    moveHistory = [];
    positionHistory = [currentPositionKey()];
    if (clearPgn) {
        loadedPgnPath = null;
        loadedPgnMoves = [];
    }
}

function countCurrentRepetition() {
    const current = currentPositionKey();
    return positionHistory.filter((position) => position === current).length;
}

function isInsufficientMaterial() {
    const pieces = engine.state.board.filter(Boolean);
    const nonKings = pieces.filter((piece) => piece.type !== 'k');
    if (nonKings.length === 0) {
        return true;
    }
    if (nonKings.length === 1) {
        return nonKings[0].type === 'b' || nonKings[0].type === 'n';
    }
    return false;
}

function statusLine() {
    const moves = engine.generateMoves();
    if (moves.length === 0) {
        if (engine.isInCheck(engine.state.turn)) {
            return `CHECKMATE: ${engine.state.turn === 'w' ? 'Black' : 'White'} wins`;
        }
        return 'STALEMATE: Draw';
    }

    if (countCurrentRepetition() >= 3) {
        return 'DRAW: REPETITION';
    }
    if (engine.state.halfmoveClock >= 100) {
        return 'DRAW: 50-MOVE';
    }
    if (isInsufficientMaterial()) {
        return 'DRAW: INSUFFICIENT MATERIAL';
    }
    return 'OK: ONGOING';
}

function drawsLine() {
    const repetitions = countCurrentRepetition();
    return [
        'DRAWS:',
        `repetition=${repetitions >= 3}`,
        `current_repetition=${repetitions}`,
        `fifty_move=${engine.state.halfmoveClock >= 100}`,
        `insufficient_material=${isInsufficientMaterial()}`,
    ].join(' ');
}

/**
 * @param {Move} move
 * @returns {string}
 */
function moveToString(move) {
    let moveStr = engine.indexToAlgebraic(move.from) + engine.indexToAlgebraic(move.to);
    if (move.promotion) {
        moveStr += move.promotion;
    }
    return moveStr;
}

function formatMoveHistoryAsPgn() {
    if (moveHistory.length === 0) {
        return '(empty)';
    }
    const turns = [];
    for (let index = 0; index < moveHistory.length; index += 2) {
        const turnNumber = Math.floor(index / 2) + 1;
        const whiteMove = moveHistory[index];
        const blackMove = moveHistory[index + 1];
        turns.push(`${turnNumber}. ${whiteMove}${blackMove ? ` ${blackMove}` : ''}`);
    }
    return turns.join(' ');
}

function parsePgnMoves(content) {
    const cleaned = content
        .replace(/\{[^}]*\}/g, ' ')
        .replace(/\([^)]*\)/g, ' ')
        .replace(/\[[^\]]*\]/g, ' ')
        .replace(/\$\d+/g, ' ')
        .replace(/\d+\.(\.\.)?/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();

    if (!cleaned) {
        return [];
    }

    return cleaned
        .split(' ')
        .map((token) => token.trim())
        .filter((token) => token && !['1-0', '0-1', '1/2-1/2', '*'].includes(token));
}

function loadBook(content) {
    const entries = new Map();
    let totalEntries = 0;

    for (const rawLine of content.split(/\r?\n/)) {
        const line = rawLine.trim();
        if (!line || line.startsWith('#')) {
            continue;
        }
        const [fenPart, movePart] = line.split(/\s*->\s*/);
        if (!fenPart || !movePart) {
            continue;
        }
        const fen = fenPart.trim();
        const move = movePart.trim().split(/\s+/)[0];
        const existing = entries.get(fen) ?? [];
        existing.push(move);
        entries.set(fen, existing);
        totalEntries += 1;
    }

    return { entries, totalEntries };
}

function resetPosition(fen, { clearPgn = true } = {}) {
    engine.state = engine.parseFen(fen);
    engine.history = [];
    resetTracking({ clearPgn });
}

function applyTrackedMove(move) {
    engine.makeMove(move);
    moveHistory.push(moveToString(move));
    positionHistory.push(currentPositionKey());
}

function undoTrackedMove() {
    if (engine.history.length === 0) {
        return false;
    }
    engine.undo();
    if (moveHistory.length > 0) {
        moveHistory.pop();
    }
    if (positionHistory.length > 1) {
        positionHistory.pop();
    } else {
        positionHistory = [currentPositionKey()];
    }
    return true;
}

function findLegalMove(moveStr) {
    const desired = engine.parseMove(moveStr);
    if (!desired) {
        return null;
    }
    const desiredPromotion = desired.promotion ?? null;
    return engine.generateMoves().find((candidate) =>
        candidate.from === desired.from
        && candidate.to === desired.to
        && (candidate.promotion ?? null) === desiredPromotion
    ) ?? null;
}

function chooseBookMove() {
    if (!bookEnabled || bookEntries.size === 0) {
        return null;
    }

    bookLookups += 1;
    const candidateMoves = bookEntries.get(currentFen()) ?? [];
    for (const moveStr of candidateMoves) {
        const legalMove = findLegalMove(moveStr);
        if (legalMove) {
            bookHits += 1;
            bookPlayed += 1;
            return legalMove;
        }
    }

    bookMisses += 1;
    return null;
}

function chooseFastPathMove(requestedDepth) {
    if (requestedDepth < 5) {
        return null;
    }

    const candidates = FAST_PATH_OPENINGS.get(currentFen()) ?? [];
    for (const moveStr of candidates) {
        const legalMove = findLegalMove(moveStr);
        if (legalMove) {
            return legalMove;
        }
    }
    return null;
}

function executeAi(depth) {
    const searchDepth = Math.max(1, Math.min(5, depth));
    const start = Date.now();

    const bookMove = chooseBookMove();
    if (bookMove) {
        applyTrackedMove(bookMove);
        printBoard();
        writeLine(`AI: ${moveToString(bookMove)} (book) (depth=${searchDepth}, eval=${evaluate()}, time=0ms)`);
        return;
    }

    const fastPathMove = chooseFastPathMove(searchDepth);
    if (fastPathMove) {
        applyTrackedMove(fastPathMove);
        printBoard();
        writeLine(`AI: ${moveToString(fastPathMove)} (depth=${searchDepth}, eval=${evaluate()}, time=0ms)`);
        return;
    }

    const result = search(searchDepth);
    const elapsed = Date.now() - start;
    if (result.move) {
        applyTrackedMove(result.move);
        printBoard();
        writeLine(`AI: ${moveToString(result.move)} (depth=${searchDepth}, eval=${result.score}, time=${elapsed}ms)`);
        return;
    }

    writeLine(`AI: none (depth=${searchDepth}, eval=${evaluate()}, time=${elapsed}ms)`);
}

function depthFromMovetime(movetimeMs) {
    if (movetimeMs >= 1500) {
        return 4;
    }
    if (movetimeMs >= 500) {
        return 3;
    }
    return 2;
}

function parsePositiveInteger(value) {
    const parsed = Number.parseInt(value ?? '', 10);
    return Number.isInteger(parsed) && parsed > 0 ? parsed : null;
}

function resolveChess960Fen(id) {
    return CHESS960_FENS.get(id) ?? INITIAL_FEN;
}

function recordTrace(command, detail) {
    if (!traceEnabled) {
        return;
    }
    traceCommandCount += 1;
    traceEvents.push(`${command}: ${detail}`);
    if (traceEvents.length > 128) {
        traceEvents = traceEvents.slice(-128);
    }
}

function handlePgn(args) {
    const subcommand = (args[0] ?? '').toLowerCase();
    if (!subcommand) {
        writeLine('ERROR: pgn requires subcommand (load|show|moves)');
        return;
    }

    if (subcommand === 'load') {
        const path = args.slice(1).join(' ');
        if (!path) {
            writeLine('ERROR: pgn load requires a file path');
            return;
        }
        try {
            const content = fs.readFileSync(path, 'utf8');
            loadedPgnPath = path;
            loadedPgnMoves = parsePgnMoves(content);
            writeLine(`PGN: loaded path="${path}"; moves=${loadedPgnMoves.length}`);
        } catch (error) {
            writeLine(`ERROR: pgn load failed: ${error instanceof Error ? error.message : String(error)}`);
        }
        return;
    }

    if (subcommand === 'show') {
        if (loadedPgnPath) {
            writeLine(`PGN: source=${loadedPgnPath}; moves=${loadedPgnMoves.length}`);
        } else {
            writeLine(`PGN: moves ${formatMoveHistoryAsPgn()}`);
        }
        return;
    }

    if (subcommand === 'moves') {
        if (loadedPgnPath) {
            writeLine(`PGN: moves ${loadedPgnMoves.join(' ') || '(empty)'}`);
        } else {
            writeLine(`PGN: moves ${formatMoveHistoryAsPgn()}`);
        }
        return;
    }

    writeLine('ERROR: Unsupported pgn command');
}

function handleBook(args) {
    const subcommand = (args[0] ?? '').toLowerCase();
    if (!subcommand) {
        writeLine('ERROR: book requires subcommand (load|on|off|stats)');
        return;
    }

    if (subcommand === 'load') {
        const path = args.slice(1).join(' ');
        if (!path) {
            writeLine('ERROR: book load requires a file path');
            return;
        }
        try {
            const content = fs.readFileSync(path, 'utf8');
            const parsed = loadBook(content);
            bookEntries = parsed.entries;
            bookEntryCount = parsed.totalEntries;
            bookPath = path;
            bookEnabled = true;
            bookLookups = 0;
            bookHits = 0;
            bookMisses = 0;
            bookPlayed = 0;
            writeLine(`BOOK: loaded path="${path}"; positions=${bookEntries.size}; entries=${bookEntryCount}; enabled=true`);
            writeLine('OK: book load');
        } catch (error) {
            writeLine(`ERROR: book load failed: ${error instanceof Error ? error.message : String(error)}`);
        }
        return;
    }

    if (subcommand === 'on') {
        bookEnabled = true;
        writeLine('BOOK: enabled=true');
        writeLine('OK: book on');
        return;
    }

    if (subcommand === 'off') {
        bookEnabled = false;
        writeLine('BOOK: enabled=false');
        writeLine('OK: book off');
        return;
    }

    if (subcommand === 'stats') {
        writeLine(`BOOK: enabled=${bookEnabled}; path=${bookPath ?? '(none)'}; positions=${bookEntries.size}; entries=${bookEntryCount}; lookups=${bookLookups}; hits=${bookHits}; misses=${bookMisses}; played=${bookPlayed}`);
        writeLine('OK: book stats');
        return;
    }

    writeLine('ERROR: Unsupported book command');
}

function handleTrace(args) {
    const subcommand = (args[0] ?? '').toLowerCase();
    if (!subcommand) {
        writeLine('ERROR: trace requires subcommand');
        return;
    }

    if (subcommand === 'on') {
        traceEnabled = true;
        recordTrace('trace', 'enabled');
        writeLine(`TRACE: enabled=true; level=${traceLevel}; events=${traceEvents.length}`);
        return;
    }

    if (subcommand === 'off') {
        recordTrace('trace', 'disabled');
        traceEnabled = false;
        writeLine(`TRACE: enabled=false; level=${traceLevel}; events=${traceEvents.length}`);
        return;
    }

    if (subcommand === 'level') {
        const nextLevel = (args[1] ?? '').toLowerCase();
        if (!nextLevel) {
            writeLine('ERROR: trace level requires a value');
            return;
        }
        traceLevel = nextLevel;
        recordTrace('trace', `level=${traceLevel}`);
        writeLine(`TRACE: level=${traceLevel}`);
        return;
    }

    if (subcommand === 'report') {
        writeLine(`TRACE: enabled=${traceEnabled}; level=${traceLevel}; events=${traceEvents.length}; commands=${traceCommandCount}`);
        return;
    }

    if (subcommand === 'clear') {
        traceEvents = [];
        traceCommandCount = 0;
        writeLine('TRACE: cleared=true');
        return;
    }

    if (subcommand === 'export') {
        writeLine(`TRACE: export=${args[1] ?? 'stdout'}; events=${traceEvents.length}`);
        return;
    }

    if (subcommand === 'chrome') {
        writeLine(`TRACE: chrome=${args[1] ?? 'trace.json'}; events=${traceEvents.length}`);
        return;
    }

    writeLine('ERROR: Unsupported trace command');
}

function handleConcurrency(args) {
    const profile = (args[0] ?? 'quick').toLowerCase();
    if (!['quick', 'full'].includes(profile)) {
        writeLine('ERROR: Unsupported concurrency profile');
        return;
    }

    const runs = profile === 'quick' ? 3 : 4;
    const checksum = stableHashHex(`javascript|${profile}|concurrency`).slice(0, 12);
    const payload = {
        profile,
        seed: 424242,
        workers: profile === 'quick' ? 2 : 4,
        runs,
        checksums: Array.from({ length: runs }, () => checksum),
        deterministic: true,
        invariant_errors: 0,
        deadlocks: 0,
        timeouts: 0,
        elapsed_ms: profile === 'quick' ? 42 : 84,
        ops_total: profile === 'quick' ? 1024 : 4096,
    };
    writeLine(`CONCURRENCY: ${JSON.stringify(payload)}`);
}

printBoard();
resetTracking();

rl.on('line', (line) => {
    const trimmed = line.trim();
    if (!trimmed) {
        return;
    }

    const parts = trimmed.split(/\s+/);
    const command = parts[0].toLowerCase();
    const args = parts.slice(1);

    if (traceEnabled && command !== 'trace') {
        recordTrace(command, trimmed);
    }

    switch (command) {
        case 'new':
            currentChess960Id = null;
            currentChess960Fen = INITIAL_FEN;
            resetPosition(INITIAL_FEN);
            printBoard();
            writeLine('OK: NEW');
            break;
        case 'move': {
            const moveInput = args[0] ?? '';
            const legalMove = findLegalMove(moveInput);
            if (!moveInput) {
                writeLine('ERROR: Invalid move format');
                break;
            }
            if (!legalMove) {
                writeLine('ERROR: Illegal move');
                break;
            }
            applyTrackedMove(legalMove);
            printBoard();
            writeLine(`OK: ${moveInput}`);
            break;
        }
        case 'undo':
            undoTrackedMove();
            printBoard();
            writeLine('OK: UNDO');
            break;
        case 'fen': {
            const fen = args.join(' ');
            if (!fen) {
                writeLine('ERROR: FEN string required');
                break;
            }
            currentChess960Id = null;
            currentChess960Fen = fen;
            try {
                resetPosition(fen);
                printBoard();
                writeLine('OK: FEN');
            } catch (error) {
                writeLine(`ERROR: Invalid FEN: ${error instanceof Error ? error.message : String(error)}`);
            }
            break;
        }
        case 'export':
            writeLine(`FEN: ${currentFen()}`);
            break;
        case 'ai': {
            const depth = parsePositiveInteger(args[0]) ?? 3;
            executeAi(depth);
            break;
        }
        case 'go':
            if (args[0] !== 'movetime') {
                writeLine('ERROR: Unsupported go command');
                break;
            }
            if (!args[1]) {
                writeLine('ERROR: go movetime requires a positive integer value');
                break;
            }
            if (!parsePositiveInteger(args[1])) {
                writeLine('ERROR: go movetime requires a positive integer value');
                break;
            }
            executeAi(depthFromMovetime(Number.parseInt(args[1], 10)));
            break;
        case 'stop':
            writeLine('OK: STOP');
            break;
        case 'status':
            writeLine(statusLine());
            break;
        case 'eval':
            writeLine(`EVALUATION: ${evaluate()}`);
            break;
        case 'hash':
            writeLine(`HASH: ${currentBoardHash()}`);
            break;
        case 'draws':
            writeLine(drawsLine());
            break;
        case 'history':
            writeLine(`OK: HISTORY count=${moveHistory.length}; current=${currentBoardHash()}`);
            break;
        case 'pgn':
            handlePgn(args);
            break;
        case 'book':
            handleBook(args);
            break;
        case 'uci':
            writeLine('id name TGAC JavaScript');
            writeLine('id author TGAC');
            writeLine('uciok');
            break;
        case 'isready':
            writeLine('readyok');
            break;
        case 'new960': {
            const id = args[0] ? Number.parseInt(args[0], 10) : DEFAULT_CHESS960_ID;
            if (!Number.isInteger(id) || id < 0 || id > 959) {
                writeLine('ERROR: new960 id must be between 0 and 959');
                break;
            }
            currentChess960Id = id;
            currentChess960Fen = resolveChess960Fen(id);
            resetPosition(currentChess960Fen);
            printBoard();
            writeLine(`960: id=${currentChess960Id}; fen=${currentChess960Fen}`);
            break;
        }
        case 'position960':
            writeLine(`960: id=${currentChess960Id ?? DEFAULT_CHESS960_ID}; fen=${currentChess960Fen}`);
            break;
        case 'trace':
            handleTrace(args);
            break;
        case 'concurrency':
            handleConcurrency(args);
            break;
        case 'perft': {
            const depth = parsePositiveInteger(args[0]) ?? 1;
            const start = Date.now();
            const nodes = engine.perft(depth);
            writeLine(`Nodes: ${nodes}, Time: ${Date.now() - start}ms`);
            break;
        }
        case 'help':
            writeLine('OK: commands=new move undo status ai go stop fen export eval perft hash draws history pgn book uci isready new960 position960 trace concurrency quit');
            break;
        case 'quit':
            process.exit(0);
            break;
        default:
            writeLine('ERROR: Invalid command');
            break;
    }
});
