"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const board_1 = require("./board");
const board = new board_1.Board();
console.log("Piece at g1 (6):", board.getPiece(6));
console.log("Board display:");
console.log(board.display());
//# sourceMappingURL=debug_board.js.map