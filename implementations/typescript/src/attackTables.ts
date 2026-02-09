/**
 * Pre-calculated attack tables for chess pieces
 * Square indices: 0-63 where 0 = a1, 7 = h1, 56 = a8, 63 = h8
 * Using `as const` for compile-time constant literal types
 */

// Helper functions for table generation
function rankOf(square: number): number {
  return Math.floor(square / 8);
}

function fileOf(square: number): number {
  return square % 8;
}

function isValidSquare(square: number): boolean {
  return square >= 0 && square < 64;
}

// Generate knight attack table
function generateKnightAttacks(): readonly (readonly number[])[] {
  const knightOffsets = [-17, -15, -10, -6, 6, 10, 15, 17];
  const attacks: number[][] = [];

  for (let square = 0; square < 64; square++) {
    const fromFile = fileOf(square);
    const squareAttacks: number[] = [];

    for (const offset of knightOffsets) {
      const to = square + offset;
      const toFile = fileOf(to);

      // Validate the move doesn't wrap around the board
      if (isValidSquare(to) && Math.abs(toFile - fromFile) <= 2) {
        squareAttacks.push(to);
      }
    }

    attacks.push(squareAttacks);
  }

  return attacks as readonly (readonly number[])[];
}

// Generate king attack table
function generateKingAttacks(): readonly (readonly number[])[] {
  const kingOffsets = [-9, -8, -7, -1, 1, 7, 8, 9];
  const attacks: number[][] = [];

  for (let square = 0; square < 64; square++) {
    const fromFile = fileOf(square);
    const squareAttacks: number[] = [];

    for (const offset of kingOffsets) {
      const to = square + offset;
      const toFile = fileOf(to);

      // Validate the move doesn't wrap around the board
      if (isValidSquare(to) && Math.abs(toFile - fromFile) <= 1) {
        squareAttacks.push(to);
      }
    }

    attacks.push(squareAttacks);
  }

  return attacks as readonly (readonly number[])[];
}

// Generate ray tables for sliding pieces (8 directions × 64 squares)
// Directions: N, NE, E, SE, S, SW, W, NW
function generateRayTables(): readonly (readonly (readonly number[])[])[] {
  const directions = [
    { offset: 8, name: "N" },   // North
    { offset: 9, name: "NE" },  // Northeast
    { offset: 1, name: "E" },   // East
    { offset: -7, name: "SE" }, // Southeast
    { offset: -8, name: "S" },  // South
    { offset: -9, name: "SW" }, // Southwest
    { offset: -1, name: "W" },  // West
    { offset: 7, name: "NW" },  // Northwest
  ];

  const rays: (number[][])[] = [];

  for (const dir of directions) {
    const directionRays: number[][] = [];

    for (let square = 0; square < 64; square++) {
      const ray: number[] = [];
      let current = square;
      const startFile = fileOf(square);

      while (true) {
        const next = current + dir.offset;

        if (!isValidSquare(next)) break;

        const currentFile = fileOf(current);
        const nextFile = fileOf(next);

        // Check for board wrapping
        if (dir.offset === 1 || dir.offset === -1) {
          // Horizontal movement
          if (Math.abs(nextFile - currentFile) !== 1) break;
        } else if (Math.abs(dir.offset) === 7 || Math.abs(dir.offset) === 9) {
          // Diagonal movement
          if (Math.abs(nextFile - currentFile) !== 1) break;
        }

        ray.push(next);
        current = next;
      }

      directionRays.push(ray);
    }

    rays.push(directionRays);
  }

  return rays as readonly (readonly (readonly number[])[])[];
}

// Generate Chebyshev distance table (max of rank/file distance)
function generateChebyshevDistances(): readonly (readonly number[])[] {
  const distances: number[][] = [];

  for (let from = 0; from < 64; from++) {
    const fromRank = rankOf(from);
    const fromFile = fileOf(from);
    const squareDistances: number[] = [];

    for (let to = 0; to < 64; to++) {
      const toRank = rankOf(to);
      const toFile = fileOf(to);
      const rankDist = Math.abs(toRank - fromRank);
      const fileDist = Math.abs(toFile - fromFile);
      squareDistances.push(Math.max(rankDist, fileDist));
    }

    distances.push(squareDistances);
  }

  return distances as readonly (readonly number[])[];
}

// Generate Manhattan distance table (sum of rank/file distance)
function generateManhattanDistances(): readonly (readonly number[])[] {
  const distances: number[][] = [];

  for (let from = 0; from < 64; from++) {
    const fromRank = rankOf(from);
    const fromFile = fileOf(from);
    const squareDistances: number[] = [];

    for (let to = 0; to < 64; to++) {
      const toRank = rankOf(to);
      const toFile = fileOf(to);
      const rankDist = Math.abs(toRank - fromRank);
      const fileDist = Math.abs(toFile - fromFile);
      squareDistances.push(rankDist + fileDist);
    }

    distances.push(squareDistances);
  }

  return distances as readonly (readonly number[])[];
}

// Pre-calculated attack tables
export const KNIGHT_ATTACKS = generateKnightAttacks();
export const KING_ATTACKS = generateKingAttacks();
export const RAY_TABLES = generateRayTables();
export const CHEBYSHEV_DISTANCE = generateChebyshevDistances();
export const MANHATTAN_DISTANCE = generateManhattanDistances();

// Ray direction indices for convenient access
export const RAY_DIRECTIONS = {
  NORTH: 0,
  NORTHEAST: 1,
  EAST: 2,
  SOUTHEAST: 3,
  SOUTH: 4,
  SOUTHWEST: 5,
  WEST: 6,
  NORTHWEST: 7,
} as const;

// Export singleton getter functions for consistency
export function getKnightAttacks(square: number): readonly number[] {
  return KNIGHT_ATTACKS[square];
}

export function getKingAttacks(square: number): readonly number[] {
  return KING_ATTACKS[square];
}

export function getRay(square: number, direction: number): readonly number[] {
  return RAY_TABLES[direction][square];
}

export function getChebyshevDistance(from: number, to: number): number {
  return CHEBYSHEV_DISTANCE[from][to];
}

export function getManhattanDistance(from: number, to: number): number {
  return MANHATTAN_DISTANCE[from][to];
}
