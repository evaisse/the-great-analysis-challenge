const { Board } = require('./dist/board.js');

const board = new Board();

// Check initial positions
console.log('Checking initial positions:');
console.log('White pawns should be at squares 8-15 (rank 1)');
for (let i = 8; i < 16; i++) {
  const piece = board.getPiece(i);
  console.log(`Square ${i} (${board.squareToAlgebraic(i)}):`, piece);
}

console.log('\nBlack pawns should be at squares 48-55 (rank 6)');
for (let i = 48; i < 56; i++) {
  const piece = board.getPiece(i);
  console.log(`Square ${i} (${board.squareToAlgebraic(i)}):`, piece);
}

console.log('\nLet\'s check all squares:');
for (let rank = 7; rank >= 0; rank--) {
  let row = '';
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
  console.log(`Rank ${rank + 1}: ${row}`);
}