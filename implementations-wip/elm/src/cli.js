const readline = require('readline');
const { Elm } = require('./chess.js');

// Initialize Elm app
const app = Elm.ChessEngine.init({ flags: process.argv.slice(2) || [] });

// Setup readline interface
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false,
  crlfDelay: Infinity
});

// Handle messages from Elm
if (app.ports.stdout) {
  app.ports.stdout.subscribe(function(message) {
    process.stdout.write(message);
  });
}

if (app.ports.exit) {
  app.ports.exit.subscribe(function(code) {
    process.exit(code);
  });
}

// Send commands to Elm
rl.on('line', (line) => {
  if (app.ports.stdin) {
    app.ports.stdin.send(line);
  }
});

rl.on('close', () => {
  process.exit(0);
});
