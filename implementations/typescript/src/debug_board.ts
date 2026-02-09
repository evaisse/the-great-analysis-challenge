import { Board } from "./board";
const board = new Board();
console.log("Piece at g1 (6):", board.getPiece(6));
console.log("Board display:");
console.log(board.display());
