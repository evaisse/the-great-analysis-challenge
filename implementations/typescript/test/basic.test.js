const { spawnSync } = require('child_process');

function runEngine(commands) {
  return spawnSync('node', ['dist/chess.js'], {
    input: commands.join('\n') + '\n',
    encoding: 'utf-8',
  });
}

function assert(condition, message) {
  if (!condition) {
    console.error(message);
    process.exit(1);
  }
}

(function main() {
  const basic = runEngine(['new', 'move e2e4', 'export', 'quit']);
  assert(basic.status === 0, `Engine exited with status ${basic.status}`);
  assert(
    basic.stdout.includes('OK: e2e4'),
    'Expected confirmation for move e2e4',
  );
  assert(/FEN:/i.test(basic.stdout), 'Export command did not produce a FEN');

  const ai = runEngine(['new', 'ai 1', 'quit']);
  assert(ai.status === 0, `AI run exited with status ${ai.status}`);
  assert(/AI:\s*[a-h][1-8][a-h][1-8]/.test(ai.stdout), 'AI did not produce a move indication');
})();
