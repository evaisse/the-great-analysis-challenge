"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MoveGenerator = void 0;
const attackTables_1 = require("./attackTables");
class MoveGenerator {
    constructor(board) {
        this.board = board;
    }
    generateAllMoves(color) {
        const moves = [];
        for (let square = 0; square < 64; square++) {
            const piece = this.board.getPiece(square);
            if (piece && piece.color === color) {
                moves.push(...this.generatePieceMoves(square, piece));
            }
        }
        return moves;
    }
    generatePieceMoves(from, piece) {
        switch (piece.type) {
            case "P":
                return this.generatePawnMoves(from, piece);
            case "N":
                return this.generateKnightMoves(from, piece);
            case "B":
                return this.generateBishopMoves(from, piece);
            case "R":
                return this.generateRookMoves(from, piece);
            case "Q":
                return this.generateQueenMoves(from, piece);
            case "K":
                return this.generateKingMoves(from, piece);
            default:
                return [];
        }
    }
    generatePawnMoves(from, piece) {
        const moves = [];
        const direction = piece.color === "white" ? 8 : -8;
        const startRank = piece.color === "white" ? 1 : 6;
        const promotionRank = piece.color === "white" ? 7 : 0;
        const rank = Math.floor(from / 8);
        const file = from % 8;
        const oneSquareForward = from + direction;
        if (this.isValidSquare(oneSquareForward) &&
            !this.board.getPiece(oneSquareForward)) {
            if (Math.floor(oneSquareForward / 8) === promotionRank) {
                ["Q", "R", "B", "N"].forEach((promo) => {
                    moves.push({
                        from,
                        to: oneSquareForward,
                        piece: "P",
                        promotion: promo,
                    });
                });
            }
            else {
                moves.push({ from, to: oneSquareForward, piece: "P" });
            }
            if (rank === startRank) {
                const twoSquaresForward = from + 2 * direction;
                if (!this.board.getPiece(twoSquaresForward)) {
                    moves.push({ from, to: twoSquaresForward, piece: "P" });
                }
            }
        }
        const captureOffsets = [direction - 1, direction + 1];
        captureOffsets.forEach((offset) => {
            const to = from + offset;
            const toFile = to % 8;
            if (Math.abs(toFile - file) === 1 && this.isValidSquare(to)) {
                const target = this.board.getPiece(to);
                if (target && target.color !== piece.color) {
                    if (Math.floor(to / 8) === promotionRank) {
                        ["Q", "R", "B", "N"].forEach((promo) => {
                            moves.push({
                                from,
                                to,
                                piece: "P",
                                captured: target.type,
                                promotion: promo,
                            });
                        });
                    }
                    else {
                        moves.push({ from, to, piece: "P", captured: target.type });
                    }
                }
            }
        });
        const enPassantTarget = this.board.getEnPassantTarget();
        if (enPassantTarget !== null) {
            const expectedPawnRank = piece.color === "white" ? 4 : 3;
            if (rank === expectedPawnRank) {
                [-1, 1].forEach((offset) => {
                    const to = from + direction + offset;
                    const toFile = to % 8;
                    if (Math.abs(toFile - file) === 1 && to === enPassantTarget) {
                        moves.push({
                            from,
                            to,
                            piece: "P",
                            enPassant: true,
                            captured: "P",
                        });
                    }
                });
            }
        }
        return moves;
    }
    generateKnightMoves(from, piece) {
        const moves = [];
        const attacks = (0, attackTables_1.getKnightAttacks)(from);
        for (const to of attacks) {
            const target = this.board.getPiece(to);
            if (!target || target.color !== piece.color) {
                moves.push({ from, to, piece: "N", captured: target?.type });
            }
        }
        return moves;
    }
    generateBishopMoves(from, piece) {
        return this.generateSlidingMoves(from, piece, [-9, -7, 7, 9], true);
    }
    generateRookMoves(from, piece) {
        return this.generateSlidingMoves(from, piece, [-8, -1, 1, 8], false);
    }
    generateQueenMoves(from, piece) {
        return this.generateSlidingMoves(from, piece, [-9, -8, -7, -1, 1, 7, 8, 9], null);
    }
    generateKingMoves(from, piece) {
        const moves = [];
        const attacks = (0, attackTables_1.getKingAttacks)(from);
        for (const to of attacks) {
            const target = this.board.getPiece(to);
            if (!target || target.color !== piece.color) {
                moves.push({ from, to, piece: "K", captured: target?.type });
            }
        }
        const rights = this.board.getCastlingRights();
        if (piece.color === "white" && from === 4) {
            if (rights.whiteKingside &&
                !this.board.getPiece(5) &&
                !this.board.getPiece(6) &&
                this.board.getPiece(7)?.type === "R" &&
                this.board.getPiece(7)?.color === "white") {
                if (!this.isSquareAttacked(4, "black") &&
                    !this.isSquareAttacked(5, "black") &&
                    !this.isSquareAttacked(6, "black")) {
                    moves.push({ from: 4, to: 6, piece: "K", castling: "K" });
                }
            }
            if (rights.whiteQueenside &&
                !this.board.getPiece(3) &&
                !this.board.getPiece(2) &&
                !this.board.getPiece(1) &&
                this.board.getPiece(0)?.type === "R" &&
                this.board.getPiece(0)?.color === "white") {
                if (!this.isSquareAttacked(4, "black") &&
                    !this.isSquareAttacked(3, "black") &&
                    !this.isSquareAttacked(2, "black")) {
                    moves.push({ from: 4, to: 2, piece: "K", castling: "Q" });
                }
            }
        }
        else if (piece.color === "black" && from === 60) {
            if (rights.blackKingside &&
                !this.board.getPiece(61) &&
                !this.board.getPiece(62) &&
                this.board.getPiece(63)?.type === "R" &&
                this.board.getPiece(63)?.color === "black") {
                if (!this.isSquareAttacked(60, "white") &&
                    !this.isSquareAttacked(61, "white") &&
                    !this.isSquareAttacked(62, "white")) {
                    moves.push({ from: 60, to: 62, piece: "K", castling: "k" });
                }
            }
            if (rights.blackQueenside &&
                !this.board.getPiece(59) &&
                !this.board.getPiece(58) &&
                !this.board.getPiece(57) &&
                this.board.getPiece(56)?.type === "R" &&
                this.board.getPiece(56)?.color === "black") {
                if (!this.isSquareAttacked(60, "white") &&
                    !this.isSquareAttacked(59, "white") &&
                    !this.isSquareAttacked(58, "white")) {
                    moves.push({ from: 60, to: 58, piece: "K", castling: "q" });
                }
            }
        }
        return moves;
    }
    generateSlidingMoves(from, piece, directions, isDiagonal) {
        const moves = [];
        const file = from % 8;
        directions.forEach((direction) => {
            let current = from;
            let to = current + direction;
            while (this.isValidSquare(to)) {
                const currentFile = current % 8;
                const currentRank = Math.floor(current / 8);
                const toFile = to % 8;
                const toRank = Math.floor(to / 8);
                // Check for board wrapping based on direction type
                if (Math.abs(direction) === 1) {
                    // Horizontal movement - must stay on same rank
                    if (currentRank !== toRank)
                        break;
                }
                else if (Math.abs(direction) === 7 || Math.abs(direction) === 9) {
                    // Diagonal movement - file and rank must both change by 1
                    if (Math.abs(toRank - currentRank) !== 1 || Math.abs(toFile - currentFile) !== 1)
                        break;
                }
                const target = this.board.getPiece(to);
                if (!target) {
                    moves.push({ from, to, piece: piece.type, captured: undefined });
                }
                else if (target.color !== piece.color) {
                    moves.push({ from, to, piece: piece.type, captured: target.type });
                    break;
                }
                else {
                    break;
                }
                current = to;
                to += direction;
            }
        });
        return moves;
    }
    isSquareAttacked(square, byColor) {
        for (let from = 0; from < 64; from++) {
            const piece = this.board.getPiece(from);
            if (piece && piece.color === byColor) {
                const moves = this.generatePieceMoves(from, piece);
                if (moves.some((move) => move.to === square)) {
                    return true;
                }
            }
        }
        return false;
    }
    isInCheck(color) {
        for (let square = 0; square < 64; square++) {
            const piece = this.board.getPiece(square);
            if (piece && piece.type === "K" && piece.color === color) {
                return this.isSquareAttacked(square, color === "white" ? "black" : "white");
            }
        }
        return false;
    }
    getLegalMoves(color) {
        const moves = this.generateAllMoves(color);
        const legalMoves = [];
        for (const move of moves) {
            const state = this.board.getState();
            this.board.makeMove(move);
            if (!this.isInCheck(color)) {
                legalMoves.push(move);
            }
            this.board.setState(state);
        }
        return legalMoves;
    }
    isCheckmate(color) {
        return this.isInCheck(color) && this.getLegalMoves(color).length === 0;
    }
    isStalemate(color) {
        return !this.isInCheck(color) && this.getLegalMoves(color).length === 0;
    }
    isValidSquare(square) {
        return square >= 0 && square < 64;
    }
}
exports.MoveGenerator = MoveGenerator;
//# sourceMappingURL=moveGenerator.js.map