"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.ChessEngine = void 0;
const readline = __importStar(require("readline"));
const board_1 = require("./board");
const moveGenerator_1 = require("./moveGenerator");
const fen_1 = require("./fen");
const ai_1 = require("./ai");
const perft_1 = require("./perft");
class ChessEngine {
    constructor() {
        this.board = new board_1.Board();
        this.moveGenerator = new moveGenerator_1.MoveGenerator(this.board);
        this.fenParser = new fen_1.FenParser(this.board);
        this.ai = new ai_1.AI(this.board, this.moveGenerator);
        this.perft = new perft_1.Perft(this.board, this.moveGenerator);
        this.rl = readline.createInterface({
            input: process.stdin,
            output: process.stdout,
            terminal: false,
        });
    }
    start() {
        console.log(this.board.display());
        this.rl.on("line", (input) => {
            const trimmed = input.trim();
            if (trimmed) {
                this.processCommand(trimmed);
            }
        });
    }
    processCommand(command) {
        const parts = command.split(" ");
        const cmd = parts[0].toLowerCase();
        try {
            switch (cmd) {
                case "move":
                    this.handleMove(parts[1]);
                    break;
                case "undo":
                    this.handleUndo();
                    break;
                case "new":
                    this.handleNew();
                    break;
                case "ai":
                    this.handleAI(parts[1]);
                    break;
                case "fen":
                    this.handleFen(parts.slice(1).join(" "));
                    break;
                case "export":
                    this.handleExport();
                    break;
                case "eval":
                    this.handleEval();
                    break;
                case "hash":
                    this.handleHash();
                    break;
                case "draws":
                    this.handleDraws();
                    break;
                case "history":
                    this.handleHistory();
                    break;
                case "perft":
                    this.handlePerft(parts[1]);
                    break;
                case "help":
                    this.handleHelp();
                    break;
                case "quit":
                    process.exit(0);
                    break;
                default:
                    console.log("ERROR: Invalid command");
                    break;
            }
        }
        catch (error) {
            console.log(error.message || "ERROR: Invalid command");
        }
    }
    handleMove(moveStr) {
        if (!moveStr || moveStr.length < 4) {
            console.log("ERROR: Invalid move format");
            return;
        }
        const from = moveStr.substring(0, 2);
        const to = moveStr.substring(2, 4);
        const promotion = moveStr.substring(4, 5).toUpperCase();
        try {
            const fromSquare = this.board.algebraicToSquare(from);
            const toSquare = this.board.algebraicToSquare(to);
            const piece = this.board.getPiece(fromSquare);
            if (!piece) {
                console.log("ERROR: No piece at source square");
                return;
            }
            if (piece.color !== this.board.getTurn()) {
                console.log("ERROR: Wrong color piece");
                return;
            }
            const legalMoves = this.moveGenerator.getLegalMoves(this.board.getTurn());
            const move = legalMoves.find((m) => m.from === fromSquare &&
                m.to === toSquare &&
                (!m.promotion ||
                    m.promotion === promotion ||
                    (!promotion && m.promotion === "Q")));
            if (!move) {
                const inCheck = this.moveGenerator.isInCheck(this.board.getTurn());
                if (inCheck) {
                    console.log("ERROR: King would be in check");
                }
                else {
                    console.log("ERROR: Illegal move");
                }
                return;
            }
            if (move.promotion && !promotion) {
                move.promotion = "Q";
            }
            else if (move.promotion && promotion) {
                move.promotion = promotion;
            }
            this.board.makeMove(move);
            console.log(`OK: ${moveStr}`);
            console.log(this.board.display());
            this.checkGameEnd();
        }
        catch (error) {
            console.log("ERROR: Invalid move format");
        }
    }
    handleUndo() {
        const move = this.board.undoMove();
        if (move) {
            console.log("Move undone");
            console.log(this.board.display());
        }
        else {
            console.log("ERROR: No moves to undo");
        }
    }
    handleNew() {
        this.board.reset();
        console.log("New game started");
        console.log(this.board.display());
    }
    handleAI(depthStr) {
        const depth = parseInt(depthStr);
        if (isNaN(depth) || depth < 1 || depth > 5) {
            console.log("ERROR: AI depth must be 1-5");
            return;
        }
        const result = this.ai.findBestMove(depth);
        if (!result.move) {
            console.log("ERROR: No legal moves available");
            return;
        }
        const moveStr = this.board.squareToAlgebraic(result.move.from) +
            this.board.squareToAlgebraic(result.move.to) +
            (result.move.promotion || "");
        this.board.makeMove(result.move);
        console.log(`AI: ${moveStr} (depth=${depth}, eval=${result.eval}, time=${result.time}ms)`);
        console.log(this.board.display());
        this.checkGameEnd();
    }
    handleFen(fenString) {
        try {
            this.fenParser.parseFen(fenString);
            console.log("Position loaded from FEN");
            console.log(this.board.display());
        }
        catch (error) {
            console.log("ERROR: Invalid FEN string");
        }
    }
    handleExport() {
        const fen = this.fenParser.exportFen();
        console.log(`FEN: ${fen}`);
    }
    handleEval() {
        const evaluation = this.evaluatePosition();
        console.log(`Position evaluation: ${evaluation}`);
    }
    handleHash() {
        console.log(`Hash: ${this.board.getHash().toString(16).padStart(16, "0")}`);
    }
    handleDraws() {
        console.log(this.board.getDrawInfo());
    }
    handleHistory() {
        const state = this.board.getState();
        console.log(`Position History (${state.positionHistory.length + 1} positions):`);
        state.positionHistory.forEach((hash, i) => {
            console.log(`  ${i}: ${hash.toString(16).padStart(16, "0")}`);
        });
        console.log(`  ${state.positionHistory.length}: ${state.zobristHash
            .toString(16)
            .padStart(16, "0")} (current)`);
    }
    evaluatePosition() {
        let score = 0;
        for (let square = 0; square < 64; square++) {
            const piece = this.board.getPiece(square);
            if (piece) {
                const value = {
                    P: 100,
                    N: 320,
                    B: 330,
                    R: 500,
                    Q: 900,
                    K: 20000,
                }[piece.type];
                score += piece.color === "white" ? value : -value;
            }
        }
        return score;
    }
    handlePerft(depthStr) {
        const depth = parseInt(depthStr);
        if (isNaN(depth) || depth < 1) {
            console.log("ERROR: Invalid perft depth");
            return;
        }
        const startTime = Date.now();
        const nodes = this.perft.perft(depth);
        const endTime = Date.now();
        console.log(`Perft(${depth}): ${nodes} nodes (${endTime - startTime}ms)`);
    }
    handleHelp() {
        console.log("Available commands:");
        console.log("  move <from><to>[promotion] - Make a move (e.g., e2e4, e7e8Q)");
        console.log("  undo - Undo the last move");
        console.log("  new - Start a new game");
        console.log("  ai <depth> - Let AI make a move (depth 1-5)");
        console.log("  fen <string> - Load position from FEN");
        console.log("  export - Export current position as FEN");
        console.log("  eval - Evaluate current position");
        console.log("  hash - Show Zobrist hash of current position");
        console.log("  draws - Show draw detection status");
        console.log("  history - Show position hash history");
        console.log("  perft <depth> - Run performance test");
        console.log("  help - Show this help message");
        console.log("  quit - Exit the program");
    }
    checkGameEnd() {
        const color = this.board.getTurn();
        const legalMoves = this.moveGenerator.getLegalMoves(color);
        if (legalMoves.length === 0) {
            if (this.moveGenerator.isInCheck(color)) {
                const winner = color === "white" ? "Black" : "White";
                console.log(`CHECKMATE: ${winner} wins`);
            }
            else {
                console.log("STALEMATE: Draw");
            }
        }
        else if (this.board.isDraw()) {
            console.log(`DRAW: ${this.board.getDrawInfo()}`);
        }
    }
}
exports.ChessEngine = ChessEngine;
const engine = new ChessEngine();
engine.start();
//# sourceMappingURL=chess.js.map