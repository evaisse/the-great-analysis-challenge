import { Square, squareFromCoords } from "./types";

type Delta = readonly [number, number];

const KNIGHT_DELTAS: readonly Delta[] = [
  [-1, -2],
  [1, -2],
  [-2, -1],
  [2, -1],
  [-2, 1],
  [2, 1],
  [-1, 2],
  [1, 2],
];

const KING_DELTAS: readonly Delta[] = [
  [-1, -1],
  [0, -1],
  [1, -1],
  [-1, 0],
  [1, 0],
  [-1, 1],
  [0, 1],
  [1, 1],
];

const RAY_DELTAS: readonly (readonly [number, Delta])[] = [
  [-9, [-1, -1]],
  [-8, [0, -1]],
  [-7, [1, -1]],
  [-1, [-1, 0]],
  [1, [1, 0]],
  [7, [-1, 1]],
  [8, [0, 1]],
  [9, [1, 1]],
];

function buildAttackTable(deltas: readonly Delta[]): ReadonlyArray<ReadonlyArray<Square>> {
  return Array.from({ length: 64 }, (_, square) => {
    const file = square % 8;
    const rank = Math.floor(square / 8);
    const attacks: Square[] = [];

    for (const [df, dr] of deltas) {
      const targetFile = file + df;
      const targetRank = rank + dr;
      if (targetFile >= 0 && targetFile < 8 && targetRank >= 0 && targetRank < 8) {
        attacks.push(squareFromCoords(targetFile, targetRank));
      }
    }

    return Object.freeze(attacks);
  });
}

function buildRayTable(delta: Delta): ReadonlyArray<ReadonlyArray<Square>> {
  return Array.from({ length: 64 }, (_, square) => {
    const file = square % 8;
    const rank = Math.floor(square / 8);
    const ray: Square[] = [];

    let targetFile = file + delta[0];
    let targetRank = rank + delta[1];
    while (targetFile >= 0 && targetFile < 8 && targetRank >= 0 && targetRank < 8) {
      ray.push(squareFromCoords(targetFile, targetRank));
      targetFile += delta[0];
      targetRank += delta[1];
    }

    return Object.freeze(ray);
  });
}

function buildDistanceTable(
  metric: (fileDistance: number, rankDistance: number) => number,
): ReadonlyArray<ReadonlyArray<number>> {
  return Array.from({ length: 64 }, (_, from) => {
    const fromFile = from % 8;
    const fromRank = Math.floor(from / 8);
    return Object.freeze(
      Array.from({ length: 64 }, (_, to) => {
        const fileDistance = Math.abs(fromFile - (to % 8));
        const rankDistance = Math.abs(fromRank - Math.floor(to / 8));
        return metric(fileDistance, rankDistance);
      }),
    );
  });
}

export const KNIGHT_ATTACKS = buildAttackTable(KNIGHT_DELTAS);
export const KING_ATTACKS = buildAttackTable(KING_DELTAS);

export const RAY_TABLES = new Map<number, ReadonlyArray<ReadonlyArray<Square>>>(
  RAY_DELTAS.map(([direction, delta]) => [direction, buildRayTable(delta)]),
);

export const CHEBYSHEV_DISTANCE = buildDistanceTable((fd, rd) => Math.max(fd, rd));
export const MANHATTAN_DISTANCE = buildDistanceTable((fd, rd) => fd + rd);
