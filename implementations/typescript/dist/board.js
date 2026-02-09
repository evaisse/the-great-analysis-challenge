"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.Board = void 0;
const types_1 = require("./types");
const zobrist_1 = require("./zobrist");
const moveGenerator_1 = require("./moveGenerator");
class Board {
    constructor() {
        this.zobrist = new zobrist_1.ZobristTable();
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
        const initialState = {
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
            hash: 0n,
        };
        initialState.hash = (0, zobrist_1.computeHash)(initialState, this.zobrist);
        return initialState;
    }
    reset() {
        this.state = this.createInitialState();
    }
    getState() {
        return { ...this.state };
    }
    setState(state) {
        const newState = { ...state };
        newState.hash = (0, zobrist_1.computeHash)(newState, this.zobrist);
        this.state = newState;
    }
    getHash() {
        return this.state.hash;
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
        // Store old state for hash update
        const oldEp = this.state.enPassantTarget;
        const oldCastling = { ...this.state.castlingRights };
        const capturedPiece = move.enPassant
            ? { type: "P", color: (piece.color === "white" ? "black" : "white") }
            : this.getPiece(move.to);
        this.setPiece(move.to, piece);
        this.setPiece(move.from, null);
        if (move.castling) {
            const rank = piece.color === "white" ? 0 : 7;
            if (move.castling === "K" || move.castling === "k") {
                const rookFrom = rank * 8 + 7;
                const rookTo = rank * 8 + 5;
                const rook = this.getPiece(rookFrom);
                if (rook) {
                    this.setPiece(rookTo, rook);
                    this.setPiece(rookFrom, null);
                }
            }
            else {
                const rookFrom = rank * 8;
                const rookTo = rank * 8 + 3;
                const rook = this.getPiece(rookFrom);
                if (rook) {
                    this.setPiece(rookTo, rook);
                    this.setPiece(rookFrom, null);
                }
            }
        }
        if (move.enPassant) {
            const capturedPawnSquare = move.to + (piece.color === "white" ? -8 : 8);
            this.setPiece(capturedPawnSquare, null);
        }
        let finalPiece = piece;
        if (move.promotion) {
            finalPiece = { type: move.promotion, color: piece.color };
            this.setPiece(move.to, finalPiece);
        }
        const rights = this.getCastlingRights();
        if (piece.type === "K") {
            if (piece.color === "white") {
                rights.whiteKingside = false;
                rights.whiteQueenside = false;
            }
            else {
                rights.blackKingside = false;
                rights.blackQueenside = false;
            }
        }
        else if (piece.type === "R") {
            if (piece.color === "white") {
                if (move.from === 0)
                    rights.whiteQueenside = false;
                if (move.from === 7)
                    rights.whiteKingside = false;
            }
            else {
                if (move.from === 56)
                    rights.blackQueenside = false;
                if (move.from === 63)
                    rights.blackKingside = false;
            }
        }
        this.setCastlingRights(rights);
        let newEp = null;
        if (piece.type === "P" && Math.abs(move.to - move.from) === 16) {
            newEp = (move.from + move.to) / 2;
            this.setEnPassantTarget(newEp);
        }
        else {
            this.setEnPassantTarget(null);
        }
        // Update hash incrementally
        this.state.hash = (0, zobrist_1.updateHashAfterMove)(this.state.hash, move.from, move.to, piece, capturedPiece, oldEp, newEp, oldCastling, rights, this.zobrist);
        // Handle promotion hash update
        if (move.promotion) {
            // Remove pawn hash and add promoted piece hash
            this.state.hash ^= this.zobrist.pieceKey(piece, move.to);
            this.state.hash ^= this.zobrist.pieceKey(finalPiece, move.to);
        }
        // Handle castling rook move in hash
        if (move.castling) {
            const rank = piece.color === "white" ? 0 : 7;
            const rook = { type: "R", color: piece.color };
            if (move.castling === "K" || move.castling === "k") {
                const rookFrom = rank * 8 + 7;
                const rookTo = rank * 8 + 5;
                this.state.hash ^= this.zobrist.pieceKey(rook, rookFrom);
                this.state.hash ^= this.zobrist.pieceKey(rook, rookTo);
            }
            else {
                const rookFrom = rank * 8;
                const rookTo = rank * 8 + 3;
                this.state.hash ^= this.zobrist.pieceKey(rook, rookFrom);
                this.state.hash ^= this.zobrist.pieceKey(rook, rookTo);
            }
        }
        // Handle en passant captured pawn in hash
        if (move.enPassant) {
            const capturedPawnSquare = move.to + (piece.color === "white" ? -8 : 8);
            const capturedPawn = { type: "P", color: (piece.color === "white" ? "black" : "white") };
            this.state.hash ^= this.zobrist.pieceKey(capturedPawn, capturedPawnSquare);
        }
        if (piece.type === "P" || move.captured) {
            this.state.halfmoveClock = 0;
        }
        else {
            this.state.halfmoveClock++;
        }
        if (piece.color === "black") {
            this.state.fullmoveNumber++;
        }
        this.setTurn(piece.color === "white" ? "black" : "white");
        this.state.moveHistory.push(move);
    }
    undoMove() {
        const move = this.state.moveHistory.pop();
        if (!move)
            return null;
        const piece = this.getPiece(move.to);
        if (!piece)
            return null;
        if (move.promotion) {
            this.setPiece(move.from, { type: "P", color: piece.color });
        }
        else {
            this.setPiece(move.from, piece);
        }
        if (move.captured) {
            const capturedColor = piece.color === "white" ? "black" : "white";
            this.setPiece(move.to, { type: move.captured, color: capturedColor });
        }
        else {
            this.setPiece(move.to, null);
        }
        if (move.castling) {
            const rank = piece.color === "white" ? 0 : 7;
            if (move.castling === "K" || move.castling === "k") {
                const rookFrom = rank * 8 + 5;
                const rookTo = rank * 8 + 7;
                const rook = this.getPiece(rookFrom);
                if (rook) {
                    this.setPiece(rookTo, rook);
                    this.setPiece(rookFrom, null);
                }
            }
            else {
                const rookFrom = rank * 8 + 3;
                const rookTo = rank * 8;
                const rook = this.getPiece(rookFrom);
                if (rook) {
                    this.setPiece(rookTo, rook);
                    this.setPiece(rookFrom, null);
                }
            }
        }
        if (move.enPassant) {
            const capturedPawnSquare = move.to + (piece.color === "white" ? -8 : 8);
            const capturedColor = piece.color === "white" ? "black" : "white";
            this.setPiece(capturedPawnSquare, { type: "P", color: capturedColor });
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
    getLegalMovesForPV() {
        const moveGenerator = new moveGenerator_1.MoveGenerator(this);
        return moveGenerator.getLegalMoves(this.getTurn());
    }
}
exports.Board = Board;
//# sourceMappingURL=board.js.map