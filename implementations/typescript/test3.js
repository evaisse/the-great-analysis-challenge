const { Board } = require('./dist/board.js');
const { MoveGenerator } = require('./dist/moveGenerator.js');

const board = new Board();
const moveGen = new MoveGenerator(board);

console.log('Initial:');
console.log(board.display());

// Make move e2e4
const e2 = board.algebraicToSquare('e2');
const e4 = board.algebraicToSquare('e4');
const moves = moveGen.getLegalMoves('white');
const e2e4 = moves.find(m => m.from === e2 && m.to === e4);

console.log('\nMaking move e2e4...');
board.makeMove(e2e4);

console.log('\nAfter move:');
console.log(board.display());

console.log('\nChecking specific squares:');
console.log('e2 (square 12):', board.getPiece(12));
console.log('e4 (square 28):', board.getPiece(28));

console.log('\nManual check of all squares:');
for (let rank = 7; rank >= 0; rank--) {
  let row = `Rank ${rank + 1}: `;
  for (let file = 0; file < 8; file++) {
    const square = rank * 8 + file;
    const piece = board.getPiece(square);
    if (piece) {
      const char = piece.color === 'white' ? piece.type : piece.type.toLowerCase();
      row += char + ' ';
    } else {
      row += '. ';
    }
  }
  console.log(row);
}