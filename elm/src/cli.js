const readline = require('readline');
const { Elm } = require('../dist/chess.js');

// Initialize Elm app
const app = Elm.ChessEngine.init();

// Setup readline interface
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  prompt: '> '
});

// Handle messages from Elm
app.ports.sendCommand.subscribe(function(message) {
  if (message === 'QUIT') {
    console.log('\nGoodbye!');
    process.exit(0);
  } else {
    process.stdout.write(message);
    if (!message.includes('ERROR') && !message.includes('OK') && !message.includes('AI:')) {
      rl.prompt();
    }
  }
});

// Send commands to Elm
rl.on('line', (line) => {
  app.ports.receiveResponse.send(line);
  if (line.trim() !== 'quit') {
    rl.prompt();
  }
});

rl.on('close', () => {
  console.log('\nGoodbye!');
  process.exit(0);
});

// Initial prompt
setTimeout(() => rl.prompt(), 100);
