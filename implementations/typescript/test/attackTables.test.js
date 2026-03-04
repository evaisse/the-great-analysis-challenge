const {
  KNIGHT_ATTACKS,
  KING_ATTACKS,
  RAY_TABLES,
  CHEBYSHEV_DISTANCE,
  MANHATTAN_DISTANCE,
} = require("../dist/attackTables");

function assert(condition, message) {
  if (!condition) {
    console.error(message);
    process.exit(1);
  }
}

function expectedTargets(square, deltas) {
  const file = square % 8;
  const rank = Math.floor(square / 8);
  const targets = [];
  for (const [df, dr] of deltas) {
    const nextFile = file + df;
    const nextRank = rank + dr;
    if (nextFile >= 0 && nextFile < 8 && nextRank >= 0 && nextRank < 8) {
      targets.push(nextRank * 8 + nextFile);
    }
  }
  return targets.sort((a, b) => a - b);
}

function arraysEqual(a, b) {
  return a.length === b.length && a.every((value, idx) => value === b[idx]);
}

(function main() {
  assert(KNIGHT_ATTACKS.length === 64, "KNIGHT_ATTACKS should contain 64 entries");
  assert(KING_ATTACKS.length === 64, "KING_ATTACKS should contain 64 entries");
  assert(CHEBYSHEV_DISTANCE.length === 64, "CHEBYSHEV_DISTANCE should contain 64 rows");
  assert(MANHATTAN_DISTANCE.length === 64, "MANHATTAN_DISTANCE should contain 64 rows");

  const knightDeltas = [
    [-1, -2],
    [1, -2],
    [-2, -1],
    [2, -1],
    [-2, 1],
    [2, 1],
    [-1, 2],
    [1, 2],
  ];
  const kingDeltas = [
    [-1, -1],
    [0, -1],
    [1, -1],
    [-1, 0],
    [1, 0],
    [-1, 1],
    [0, 1],
    [1, 1],
  ];
  for (let square = 0; square < 64; square++) {
    assert(
      arraysEqual([...KNIGHT_ATTACKS[square]].sort((a, b) => a - b), expectedTargets(square, knightDeltas)),
      `KNIGHT_ATTACKS mismatch on square ${square}`,
    );
    assert(
      arraysEqual([...KING_ATTACKS[square]].sort((a, b) => a - b), expectedTargets(square, kingDeltas)),
      `KING_ATTACKS mismatch on square ${square}`,
    );
    assert(CHEBYSHEV_DISTANCE[square].length === 64, `CHEBYSHEV_DISTANCE row ${square} should contain 64 entries`);
    assert(MANHATTAN_DISTANCE[square].length === 64, `MANHATTAN_DISTANCE row ${square} should contain 64 entries`);
  }

  for (const direction of [-9, -8, -7, -1, 1, 7, 8, 9]) {
    const table = RAY_TABLES.get(direction);
    assert(table, `RAY_TABLES missing direction ${direction}`);
    assert(table.length === 64, `RAY_TABLES direction ${direction} should contain 64 entries`);
  }
})();
