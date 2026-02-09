"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createCastlingRights = createCastlingRights;
exports.allCastlingRights = allCastlingRights;
exports.noCastlingRights = noCastlingRights;
exports.copyCastlingRights = copyCastlingRights;
exports.castlingRightsToString = castlingRightsToString;
exports.parseCastlingRights = parseCastlingRights;
function createCastlingRights(whiteKingside = true, whiteQueenside = true, blackKingside = true, blackQueenside = true) {
    return { whiteKingside, whiteQueenside, blackKingside, blackQueenside };
}
function allCastlingRights() {
    return createCastlingRights(true, true, true, true);
}
function noCastlingRights() {
    return createCastlingRights(false, false, false, false);
}
function copyCastlingRights(rights) {
    return { ...rights };
}
function castlingRightsToString(rights) {
    let result = "";
    if (rights.whiteKingside)
        result += "K";
    if (rights.whiteQueenside)
        result += "Q";
    if (rights.blackKingside)
        result += "k";
    if (rights.blackQueenside)
        result += "q";
    return result || "-";
}
function parseCastlingRights(str) {
    if (str === "-")
        return noCastlingRights();
    return {
        whiteKingside: str.includes("K"),
        whiteQueenside: str.includes("Q"),
        blackKingside: str.includes("k"),
        blackQueenside: str.includes("q"),
    };
}
//# sourceMappingURL=castling.js.map