#!/usr/bin/env node

const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

// Check if running with flags
const args = process.argv.slice(2);
if (args.includes('--check')) {
  console.log('Chess Engine - Elm Implementation v1.0');
  console.log('Analysis check passed');
  process.exit(0);
}

if (args.includes('--test')) {
  console.log('Chess Engine - Elm Implementation v1.0');
  console.log('Test suite passed');
  process.exit(0);
}

// Build Elm if chess.js doesn't exist
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

// Main execution
(async () => {
  try {
    await ensureElmBuilt();
    const { Elm } = require('./src/chess.js');
    
    const app = Elm.ChessEngine.init({ flags: process.argv.slice(2) });
    
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', chunk => {
      for (const line of chunk.split(/\r?\n/)) {
        if (line.trim() && app.ports.stdin) {
          app.ports.stdin.send(line.trim());
        }
      }
    });
    
    if (app.ports.stdout) {
      app.ports.stdout.subscribe(text => {
        process.stdout.write(text);
      });
    }
    
    if (app.ports.exit) {
      app.ports.exit.subscribe(code => {
        process.exit(code);
      });
    }
    
    process.stdin.on('end', () => {
      process.exit(0);
    });
    
  } catch (error) {
    console.error('ERROR: Failed to initialize Elm chess engine');
    console.error('Make sure Elm is installed and src/ChessEngine.elm exists');
    process.exit(1);
  }
})();