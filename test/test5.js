const { Board } = require('./dist/board.js');

const board = new Board();

console.log('Before move:');
console.log('Piece at e2 (12):', board.getPiece(12));
console.log('Piece at e4 (28):', board.getPiece(28));

// Manually create move
const move = {
  from: 12,  // e2
  to: 28,    // e4
  piece: 'P'
};

console.log('\nMaking move:', move);
board.makeMove(move);

console.log('\nAfter move:');
console.log('Piece at e2 (12):', board.getPiece(12));
console.log('Piece at e4 (28):', board.getPiece(28));

// Check where all white pawns ended up
console.log('\nWhere are the white pawns?');
for (let i = 0; i < 64; i++) {
  const piece = board.getPiece(i);
  if (piece && piece.type === 'P' && piece.color === 'white') {
    console.log(`  White pawn at square ${i} (${board.squareToAlgebraic(i)})`);
  }
}