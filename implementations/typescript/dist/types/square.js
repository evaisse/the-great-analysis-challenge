"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createSquare = createSquare;
exports.isValidSquare = isValidSquare;
exports.unsafeSquare = unsafeSquare;
exports.squareToRank = squareToRank;
exports.squareToFile = squareToFile;
exports.squareToAlgebraic = squareToAlgebraic;
exports.algebraicToSquare = algebraicToSquare;
exports.squareOffset = squareOffset;
exports.squareDistance = squareDistance;
exports.createRank = createRank;
exports.createFile = createFile;
exports.rankFileToSquare = rankFileToSquare;
// Helper to create validated squares
function createSquare(value) {
    if (value < 0 || value > 63) {
        throw new Error(`Invalid square value: ${value}. Must be 0-63.`);
    }
    return value;
}
function isValidSquare(value) {
    return value >= 0 && value <= 63;
}
// No-op for compatibility during refactoring
function unsafeSquare(value) {
    return value;
}
function squareToRank(square) {
    return Math.floor(square / 8);
}
function squareToFile(square) {
    return (square % 8);
}
function squareToAlgebraic(square) {
    const file = squareToFile(square);
    const rank = squareToRank(square);
    return `${String.fromCharCode(97 + file)}${rank + 1}`;
}
function algebraicToSquare(algebraic) {
    if (algebraic.length !== 2)
        return null;
    const file = algebraic.charCodeAt(0) - 97;
    const rank = parseInt(algebraic[1]) - 1;
    if (file < 0 || file > 7 || rank < 0 || rank > 7)
        return null;
    return createSquare(rank * 8 + file);
}
function squareOffset(square, dx, dy) {
    const file = squareToFile(square);
    const rank = squareToRank(square);
    const newFile = file + dx;
    const newRank = rank + dy;
    if (newFile < 0 || newFile > 7 || newRank < 0 || newRank > 7)
        return null;
    return createSquare(newRank * 8 + newFile);
}
function squareDistance(a, b) {
    const aFile = squareToFile(a);
    const aRank = squareToRank(a);
    const bFile = squareToFile(b);
    const bRank = squareToRank(b);
    return Math.max(Math.abs(aFile - bFile), Math.abs(aRank - bRank));
}
function createRank(value) {
    if (value < 0 || value > 7) {
        throw new Error(`Invalid rank value: ${value}. Must be 0-7.`);
    }
    return value;
}
function createFile(value) {
    if (value < 0 || value > 7) {
        throw new Error(`Invalid file value: ${value}. Must be 0-7.`);
    }
    return value;
}
function rankFileToSquare(rank, file) {
    return createSquare(rank * 8 + file);
}
//# sourceMappingURL=square.js.map