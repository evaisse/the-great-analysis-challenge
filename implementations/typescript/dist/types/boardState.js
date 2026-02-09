"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createWhiteToMoveState = createWhiteToMoveState;
exports.createBlackToMoveState = createBlackToMoveState;
exports.createBoardState = createBoardState;
exports.transitionState = transitionState;
exports.stateToData = stateToData;
exports.isWhiteToMove = isWhiteToMove;
exports.isBlackToMove = isBlackToMove;
// Type-safe state transition constructors - simplified during transition
function createWhiteToMoveState(data) {
    if (data.turn !== "white") {
        throw new Error("Cannot create WhiteToMove state when turn is not white");
    }
    return data;
}
function createBlackToMoveState(data) {
    if (data.turn !== "black") {
        throw new Error("Cannot create BlackToMove state when turn is not black");
    }
    return data;
}
// Helper to create board state with correct phantom type
function createBoardState(data) {
    return data;
}
// Type-safe state transition - simplified during transition
function transitionState(state, newData) {
    return newData;
}
// Strip phantom type for compatibility
function stateToData(state) {
    return state;
}
// Type guards
function isWhiteToMove(state) {
    return state.turn === "white";
}
function isBlackToMove(state) {
    return state.turn === "black";
}
//# sourceMappingURL=boardState.js.map