const { Board } = require('./dist/board.js');
const { MoveGenerator } = require('./dist/moveGenerator.js');

const board = new Board();
const moveGen = new MoveGenerator(board);

const e2 = board.algebraicToSquare('e2');
console.log('e2 square:', e2);

const piece = board.getPiece(e2);
console.log('Piece at e2:', piece);

const moves = moveGen.generatePieceMoves(e2, piece);
console.log('\nPawn moves from e2:');
moves.forEach(move => {
  console.log(`  from: ${move.from} (${board.squareToAlgebraic(move.from)}) to: ${move.to} (${board.squareToAlgebraic(move.to)})`);
});

console.log('\nExpected: e2(12) -> e3(20) and e2(12) -> e4(28)');
console.log('e3 should be square:', board.algebraicToSquare('e3'));
console.log('e4 should be square:', board.algebraicToSquare('e4'));