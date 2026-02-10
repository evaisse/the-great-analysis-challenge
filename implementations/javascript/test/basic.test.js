import { test } from 'node:test';
import assert from 'node:assert';
import { ChessEngine } from '../engine.js';

test('engine can parse initial FEN', () => {
    const engine = new ChessEngine();
    assert.strictEqual(engine.state.turn, 'w');
});
