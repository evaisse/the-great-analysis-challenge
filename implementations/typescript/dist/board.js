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
exports.Board = void 0;
const types_1 = require("./types");
const zobrist_1 = require("./zobrist");
const drawDetection = __importStar(require("./drawDetection"));
class Board {
    constructor() {
        this.state = this.createInitialState();
    }
    createInitialState() {
        const board = new Array(64).fill(null);
        const pieces = [
            [0, { type: "R", color: "white" }],
            [1, { type: "N", color: "white" }],
            [2, { type: "B", color: "white" }],
            [3, { type: "Q", color: "white" }],
            [4, { type: "K", color: "white" }],
            [5, { type: "B", color: "white" }],
            [6, { type: "N", color: "white" }],
            [7, { type: "R", color: "white" }],
            [56, { type: "R", color: "black" }],
            [57, { type: "N", color: "black" }],
            [58, { type: "B", color: "black" }],
            [59, { type: "Q", color: "black" }],
            [60, { type: "K", color: "black" }],
            [61, { type: "B", color: "black" }],
            [62, { type: "N", color: "black" }],
            [63, { type: "R", color: "black" }],
        ];
        for (let i = 8; i < 16; i++) {
            pieces.push([i, { type: "P", color: "white" }]);
        }
        for (let i = 48; i < 56; i++) {
            pieces.push([i, { type: "P", color: "black" }]);
        }
        for (const [square, piece] of pieces) {
            board[square] = piece;
        }
        const state = {
            board,
            turn: "white",
            castlingRights: {
                whiteKingside: true,
                whiteQueenside: true,
                blackKingside: true,
                blackQueenside: true,
            },
            enPassantTarget: null,
            halfmoveClock: 0,
            fullmoveNumber: 1,
            moveHistory: [],
            zobristHash: 0n,
            positionHistory: [],
            irreversibleHistory: [],
        };
        state.zobristHash = zobrist_1.zobrist.computeHash(state);
        return state;
    }
    reset() {
        this.state = this.createInitialState();
    }
    getState() {
        return { ...this.state };
    }
    setState(state) {
        this.state = { ...state };
    }
    isDraw() {
        return (drawDetection.isDrawByRepetition(this.state) ||
            drawDetection.isDrawByFiftyMoves(this.state));
    }
    getHash() {
        return this.state.zobristHash;
    }
    getDrawInfo() {
        return `Repetition: ${drawDetection.isDrawByRepetition(this.state)}, 50-move clock: ${this.state.halfmoveClock}`;
    }
    getPiece(square) {
        return this.state.board[square];
    }
    setPiece(square, piece) {
        this.state.board[square] = piece;
    }
    getTurn() {
        return this.state.turn;
    }
    setTurn(color) {
        this.state.turn = color;
    }
    getCastlingRights() {
        return { ...this.state.castlingRights };
    }
    setCastlingRights(rights) {
        this.state.castlingRights = { ...rights };
    }
    getEnPassantTarget() {
        return this.state.enPassantTarget;
    }
    setEnPassantTarget(square) {
        this.state.enPassantTarget = square;
    }
    squareToAlgebraic(square) {
        const file = square % 8;
        const rank = Math.floor(square / 8);
        return types_1.FILES[file] + types_1.RANKS[rank];
    }
    algebraicToSquare(algebraic) {
        const file = types_1.FILES.indexOf(algebraic[0]);
        const rank = types_1.RANKS.indexOf(algebraic[1]);
        if (file === -1 || rank === -1) {
            throw new Error(`Invalid algebraic notation: ${algebraic}`);
        }
        return rank * 8 + file;
    }
    makeMove(move) {
        const piece = this.getPiece(move.from);
        if (!piece)
            return;
        // Save irreversible state
        this.state.irreversibleHistory.push({
            castlingRights: { ...this.state.castlingRights },
            enPassantTarget: this.state.enPassantTarget,
            halfmoveClock: this.state.halfmoveClock,
            zobristHash: this.state.zobristHash,
        });
        this.state.positionHistory.push(this.state.zobristHash);
        let hash = this.state.zobristHash;
        // 1. Remove moving piece from source
        hash ^= zobrist_1.zobrist.pieces[zobrist_1.zobrist.getPieceIndex(piece)][move.from];
        // 2. Handle capture
        if (move.captured) {
            const capturedColor = piece.color === "white" ? "black" : "white";
            const capturedPiece = { type: move.captured, color: capturedColor };
            if (move.enPassant) {
                const capturedSq = move.to + (piece.color === "white" ? -8 : 8);
                hash ^=
                    zobrist_1.zobrist.pieces[zobrist_1.zobrist.getPieceIndex(capturedPiece)][capturedSq];
                this.setPiece(capturedSq, null);
            }
            else {
                hash ^= zobrist_1.zobrist.pieces[zobrist_1.zobrist.getPieceIndex(capturedPiece)][move.to];
                // Dest square will be overwritten below
            }
            this.state.halfmoveClock = 0;
        }
        else if (piece.type === "P") {
            this.state.halfmoveClock = 0;
        }
        else {
            this.state.halfmoveClock++;
        }
        // 3. Place piece at destination (handling promotion)
        if (move.promotion) {
            const promoPiece = { type: move.promotion, color: piece.color };
            hash ^= zobrist_1.zobrist.pieces[zobrist_1.zobrist.getPieceIndex(promoPiece)][move.to];
            this.setPiece(move.to, promoPiece);
        }
        else {
            hash ^= zobrist_1.zobrist.pieces[zobrist_1.zobrist.getPieceIndex(piece)][move.to];
            this.setPiece(move.to, piece);
        }
        this.setPiece(move.from, null);
        // 4. Handle castling rook
        if (move.castling) {
            const rank = piece.color === "white" ? 0 : 7;
            let rookFrom, rookTo;
            if (move.castling === "K" || move.castling === "k") {
                rookFrom = rank * 8 + 7;
                rookTo = rank * 8 + 5;
            }
            else {
                rookFrom = rank * 8;
                rookTo = rank * 8 + 3;
            }
            const rook = this.getPiece(rookFrom);
            if (rook) {
                hash ^= zobrist_1.zobrist.pieces[zobrist_1.zobrist.getPieceIndex(rook)][rookFrom];
                hash ^= zobrist_1.zobrist.pieces[zobrist_1.zobrist.getPieceIndex(rook)][rookTo];
                this.setPiece(rookTo, rook);
                this.setPiece(rookFrom, null);
            }
        }
        // 5. Update castling rights in hash
        if (this.state.castlingRights.whiteKingside)
            hash ^= zobrist_1.zobrist.castling[0];
        if (this.state.castlingRights.whiteQueenside)
            hash ^= zobrist_1.zobrist.castling[1];
        if (this.state.castlingRights.blackKingside)
            hash ^= zobrist_1.zobrist.castling[2];
        if (this.state.castlingRights.blackQueenside)
            hash ^= zobrist_1.zobrist.castling[3];
        if (piece.type === "K") {
            if (piece.color === "white") {
                this.state.castlingRights.whiteKingside = false;
                this.state.castlingRights.whiteQueenside = false;
            }
            else {
                this.state.castlingRights.blackKingside = false;
                this.state.castlingRights.blackQueenside = false;
            }
        }
        if (move.from === 0 || move.to === 0)
            this.state.castlingRights.whiteQueenside = false;
        if (move.from === 7 || move.to === 7)
            this.state.castlingRights.whiteKingside = false;
        if (move.from === 56 || move.to === 56)
            this.state.castlingRights.blackQueenside = false;
        if (move.from === 63 || move.to === 63)
            this.state.castlingRights.blackKingside = false;
        if (this.state.castlingRights.whiteKingside)
            hash ^= zobrist_1.zobrist.castling[0];
        if (this.state.castlingRights.whiteQueenside)
            hash ^= zobrist_1.zobrist.castling[1];
        if (this.state.castlingRights.blackKingside)
            hash ^= zobrist_1.zobrist.castling[2];
        if (this.state.castlingRights.blackQueenside)
            hash ^= zobrist_1.zobrist.castling[3];
        // 6. Update en passant target in hash
        if (this.state.enPassantTarget !== null) {
            hash ^= zobrist_1.zobrist.enPassant[this.state.enPassantTarget % 8];
        }
        if (piece.type === "P" && Math.abs(move.to - move.from) === 16) {
            const enPassantSquare = (move.from + move.to) / 2;
            this.state.enPassantTarget = enPassantSquare;
            hash ^= zobrist_1.zobrist.enPassant[enPassantSquare % 8];
        }
        else {
            this.state.enPassantTarget = null;
        }
        // 7. Update side to move and fullmove
        hash ^= zobrist_1.zobrist.sideToMove;
        if (piece.color === "black") {
            this.state.fullmoveNumber++;
        }
        this.state.zobristHash = hash;
        this.setTurn(piece.color === "white" ? "black" : "white");
        this.state.moveHistory.push(move);
    }
    undoMove() {
        const move = this.state.moveHistory.pop();
        if (!move)
            return null;
        const oldState = this.state.irreversibleHistory.pop();
        if (!oldState)
            throw new Error("No irreversible history for undo");
        this.state.positionHistory.pop();
        const piece = this.getPiece(move.to);
        if (!piece)
            return null;
        // Restore irreversible state
        this.state.castlingRights = { ...oldState.castlingRights };
        this.state.enPassantTarget = oldState.enPassantTarget;
        this.state.halfmoveClock = oldState.halfmoveClock;
        this.state.zobristHash = oldState.zobristHash;
        if (move.promotion) {
            this.setPiece(move.from, { type: "P", color: piece.color });
        }
        else {
            this.setPiece(move.from, piece);
        }
        if (move.captured) {
            const capturedColor = piece.color === "white" ? "black" : "white";
            const capturedPiece = { type: move.captured, color: capturedColor };
            if (move.enPassant) {
                const capturedPawnSquare = move.to + (piece.color === "white" ? -8 : 8);
                this.setPiece(capturedPawnSquare, capturedPiece);
                this.setPiece(move.to, null);
            }
            else {
                this.setPiece(move.to, capturedPiece);
            }
        }
        else {
            this.setPiece(move.to, null);
        }
        if (move.castling) {
            const rank = piece.color === "white" ? 0 : 7;
            let rookFrom, rookTo;
            if (move.castling === "K" || move.castling === "k") {
                rookFrom = rank * 8 + 5;
                rookTo = rank * 8 + 7;
            }
            else {
                rookFrom = rank * 8 + 3;
                rookTo = rank * 8;
            }
            const rook = this.getPiece(rookFrom);
            if (rook) {
                this.setPiece(rookTo, rook);
                this.setPiece(rookFrom, null);
            }
        }
        if (piece.color === "black") {
            this.state.fullmoveNumber--;
        }
        this.setTurn(piece.color);
        return move;
    }
    display() {
        let output = "  a b c d e f g h\n";
        for (let rank = 7; rank >= 0; rank--) {
            output += `${rank + 1} `;
            for (let file = 0; file < 8; file++) {
                const square = rank * 8 + file;
                const piece = this.getPiece(square);
                if (piece) {
                    const char = piece.color === "white" ? piece.type : piece.type.toLowerCase();
                    output += `${char} `;
                }
                else {
                    output += ". ";
                }
            }
            output += `${rank + 1}\n`;
        }
        output += "  a b c d e f g h\n\n";
        output += `${this.state.turn === "white" ? "White" : "Black"} to move`;
        return output;
    }
}
exports.Board = Board;
//# sourceMappingURL=board.js.map