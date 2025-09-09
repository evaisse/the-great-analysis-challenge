const { ChessEngine } = require('./dist/chess.js');
const { Board } = require('./dist/board.js');
const { MoveGenerator } = require('./dist/moveGenerator.js');

const board = new Board();
const moveGen = new MoveGenerator(board);

console.log('Initial board:');
console.log(board.display());

// Try to move e2 to e4
const e2 = board.algebraicToSquare('e2');
const e4 = board.algebraicToSquare('e4');

console.log('e2 square index:', e2);
console.log('e4 square index:', e4);
console.log('Piece at e2:', board.getPiece(e2));

// Get legal moves for white
const moves = moveGen.getLegalMoves('white');
const e2e4Move = moves.find(m => m.from === e2 && m.to === e4);
console.log('Found e2e4 move:', e2e4Move);

if (e2e4Move) {
  board.makeMove(e2e4Move);
  console.log('\nAfter e2e4:');
  console.log(board.display());
  console.log('Piece at e4:', board.getPiece(e4));
}