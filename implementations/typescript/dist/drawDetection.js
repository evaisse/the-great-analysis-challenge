"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.isDrawByRepetition = isDrawByRepetition;
exports.isDrawByFiftyMoves = isDrawByFiftyMoves;
function isDrawByRepetition(state) {
    const currentHash = state.zobristHash;
    let count = 1;
    const historyLen = state.positionHistory.length;
    // We only need to check back to the last irreversible move
    const startIdx = Math.max(0, historyLen - state.halfmoveClock);
    for (let i = historyLen - 1; i >= startIdx; i--) {
        if (state.positionHistory[i] === currentHash) {
            count++;
            if (count >= 3)
                return true;
        }
    }
    return false;
}
function isDrawByFiftyMoves(state) {
    return state.halfmoveClock >= 100;
}
//# sourceMappingURL=drawDetection.js.map