import { Board } from "./board";
import { SQUARES } from "./types";

const board = new Board();
console.log("Piece at g1 (6):", board.getPiece(SQUARES[6]));
console.log("Board display:");
console.log(board.display());
