"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PIECE_VALUES = void 0;
exports.oppositeColor = oppositeColor;
exports.isColor = isColor;
exports.isPieceType = isPieceType;
exports.createPiece = createPiece;
exports.pieceEquals = pieceEquals;
function oppositeColor(color) {
    return color === "white" ? "black" : "white";
}
function isColor(value) {
    return value === "white" || value === "black";
}
function isPieceType(value) {
    return ["K", "Q", "R", "B", "N", "P"].includes(value);
}
function createPiece(type, color) {
    return { type, color };
}
function pieceEquals(a, b) {
    return a.type === b.type && a.color === b.color;
}
// Piece values for evaluation
exports.PIECE_VALUES = {
    P: 100,
    N: 320,
    B: 330,
    R: 500,
    Q: 900,
    K: 20000,
};
//# sourceMappingURL=piece.js.map