"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createUncheckedMove = createUncheckedMove;
exports.validateMove = validateMove;
exports.isLegalMove = isLegalMove;
exports.moveToAlgebraic = moveToAlgebraic;
exports.parseMove = parseMove;
exports.moveToBase = moveToBase;
// Constructor for unchecked moves
function createUncheckedMove(from, to, piece, options) {
    return {
        from,
        to,
        piece,
        ...options,
    };
}
// Validate an unchecked move to create a legal move
function validateMove(move) {
    return move; // No-op during transition
}
// Type guard for legal moves
function isLegalMove(move) {
    return true; // Simplified during transition
}
// Convert move to algebraic notation
function moveToAlgebraic(move) {
    const from = move.from;
    const to = move.to;
    const fromFile = String.fromCharCode(97 + (from % 8));
    const fromRank = Math.floor(from / 8) + 1;
    const toFile = String.fromCharCode(97 + (to % 8));
    const toRank = Math.floor(to / 8) + 1;
    let notation = `${fromFile}${fromRank}${toFile}${toRank}`;
    if (move.promotion) {
        notation += move.promotion.toLowerCase();
    }
    return notation;
}
// Parse algebraic notation to unchecked move
function parseMove(notation, piece) {
    if (notation.length < 4)
        return null;
    const fromFile = notation.charCodeAt(0) - 97;
    const fromRank = parseInt(notation[1]) - 1;
    const toFile = notation.charCodeAt(2) - 97;
    const toRank = parseInt(notation[3]) - 1;
    if (fromFile < 0 || fromFile > 7 || fromRank < 0 || fromRank > 7)
        return null;
    if (toFile < 0 || toFile > 7 || toRank < 0 || toRank > 7)
        return null;
    const from = (fromRank * 8 + fromFile);
    const to = (toRank * 8 + toFile);
    const promotion = notation.length > 4 ? notation[4].toUpperCase() : undefined;
    return createUncheckedMove(from, to, piece, { promotion });
}
// For backward compatibility - strip type brand
function moveToBase(move) {
    const { from, to, piece, captured, promotion, castling, enPassant } = move;
    return { from, to, piece, captured, promotion, castling, enPassant };
}
//# sourceMappingURL=move.js.map