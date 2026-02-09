"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.zobrist = exports.ZobristKeys = void 0;
class ZobristKeys {
    constructor() {
        this.pieces = Array.from({ length: 12 }, () => Array(64).fill(0n));
        this.castling = Array(4).fill(0n);
        this.enPassant = Array(8).fill(0n);
        let state = 0x123456789abcdef0n;
        const next = () => {
            // Simulation of u64 xorshift
            state ^= (state << 13n) & 0xffffffffffffffffn;
            state ^= (state >> 7n); // Right shift on bigint is already logical/unsigned for positive values
            state ^= (state << 17n) & 0xffffffffffffffffn;
            return state;
        };
        for (let p = 0; p < 12; p++) {
            for (let s = 0; s < 64; s++) {
                this.pieces[p][s] = next();
            }
        }
        this.sideToMove = next();
        for (let i = 0; i < 4; i++) {
            this.castling[i] = next();
        }
        for (let i = 0; i < 8; i++) {
            this.enPassant[i] = next();
        }
    }
    computeHash(state) {
        let hash = 0n;
        for (let i = 0; i < 64; i++) {
            const piece = state.board[i];
            if (piece) {
                hash ^= this.pieces[this.getPieceIndex(piece)][i];
            }
        }
        if (state.turn === "black") {
            hash ^= this.sideToMove;
        }
        if (state.castlingRights.whiteKingside)
            hash ^= this.castling[0];
        if (state.castlingRights.whiteQueenside)
            hash ^= this.castling[1];
        if (state.castlingRights.blackKingside)
            hash ^= this.castling[2];
        if (state.castlingRights.blackQueenside)
            hash ^= this.castling[3];
        if (state.enPassantTarget !== null) {
            hash ^= this.enPassant[state.enPassantTarget % 8];
        }
        return hash;
    }
    getPieceIndex(piece) {
        const types = { P: 0, N: 1, B: 2, R: 3, Q: 4, K: 5 };
        let idx = types[piece.type];
        if (piece.color === "black")
            idx += 6;
        return idx;
    }
}
exports.ZobristKeys = ZobristKeys;
exports.zobrist = new ZobristKeys();
//# sourceMappingURL=zobrist.js.map