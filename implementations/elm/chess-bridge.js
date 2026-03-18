#!/usr/bin/env node

const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const { runProtocolEngine } = require('./protocol-runner');

const args = process.argv.slice(2);

async function ensureElmBuilt() {
  const chessJsPath = path.join(__dirname, 'src', 'chess.js');
  
  if (!fs.existsSync(chessJsPath)) {
    console.error('Building Elm...');
    return new Promise((resolve, reject) => {
      const elmMake = spawn('elm', ['make', 'src/ChessEngine.elm', '--output=src/chess.js'], {
        cwd: __dirname,
        stdio: ['ignore', 'pipe', 'pipe']
      });
      
      let stderr = '';
      elmMake.stderr.on('data', (data) => {
        stderr += data.toString();
      });
      
      elmMake.on('close', (code) => {
        if (code === 0) {
          resolve();
        } else {
          reject(new Error(`Elm compilation failed: ${stderr}`));
        }
      });
    });
  }
}

(async () => {
  try {
    await ensureElmBuilt();
    await runProtocolEngine({
      elmModulePath: path.join(__dirname, 'src', 'chess.js'),
      args,
    });
  } catch (error) {
    console.error('ERROR: Failed to initialize Elm chess engine');
    console.error(error && error.message ? error.message : 'Make sure Elm is installed and src/ChessEngine.elm exists');
    process.exit(1);
  }
})();
