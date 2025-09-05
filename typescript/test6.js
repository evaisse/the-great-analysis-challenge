const { Board } = require('./dist/board.js');

const board = new Board();

console.log('Before move - checking display function line by line:');
const displayBefore = board.display();
console.log(displayBefore);

// Make the move
const move = { from: 12, to: 28, piece: 'P' };
board.makeMove(move);

console.log('\nAfter move - checking display function line by line:');
const displayAfter = board.display();
console.log(displayAfter);

console.log('\nChecking board state directly:');
console.log('Turn:', board.getTurn());
console.log('Piece at e4 (28):', board.getPiece(28));

// Verify the display is wrong by checking manually
console.log('\nWhat the display SHOULD show:');
let output = '  a b c d e f g h\n';
for (let rank = 7; rank >= 0; rank--) {
  output += `${rank + 1} `;
  for (let file = 0; file < 8; file++) {
    const square = rank * 8 + file;
    const piece = board.getPiece(square);
    if (piece) {
      const char = piece.color === 'white' 
        ? piece.type 
        : piece.type.toLowerCase();
      output += `${char} `;
    } else {
      output += '. ';
    }
  }
  output += `${rank + 1}\n`;
}
output += '  a b c d e f g h\n\n';
output += `${board.getTurn() === 'white' ? 'White' : 'Black'} to move`;
console.log(output);