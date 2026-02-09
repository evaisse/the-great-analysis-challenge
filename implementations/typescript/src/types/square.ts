// Branded Square type: ensures values are 0-63
// During refactoring, we keep structural compatibility with number
declare const SquareBrand: unique symbol;
export type Square = number;  // Temporarily relaxed for gradual migration

// Helper to create validated squares
export function createSquare(value: number): Square {
  if (value < 0 || value > 63) {
    throw new Error(`Invalid square value: ${value}. Must be 0-63.`);
  }
  return value;
}

export function isValidSquare(value: number): value is Square {
  return value >= 0 && value <= 63;
}

// No-op for compatibility during refactoring
export function unsafeSquare(value: number): Square {
  return value;
}

export function squareToRank(square: Square): Rank {
  return Math.floor(square / 8);
}

export function squareToFile(square: Square): File {
  return (square % 8);
}

export function squareToAlgebraic(square: Square): string {
  const file = squareToFile(square);
  const rank = squareToRank(square);
  return `${String.fromCharCode(97 + file)}${rank + 1}`;
}

export function algebraicToSquare(algebraic: string): Square | null {
  if (algebraic.length !== 2) return null;
  const file = algebraic.charCodeAt(0) - 97;
  const rank = parseInt(algebraic[1]) - 1;
  if (file < 0 || file > 7 || rank < 0 || rank > 7) return null;
  return createSquare(rank * 8 + file);
}

export function squareOffset(square: Square, dx: number, dy: number): Square | null {
  const file = squareToFile(square);
  const rank = squareToRank(square);
  const newFile = file + dx;
  const newRank = rank + dy;
  if (newFile < 0 || newFile > 7 || newRank < 0 || newRank > 7) return null;
  return createSquare(newRank * 8 + newFile);
}

export function squareDistance(a: Square, b: Square): number {
  const aFile = squareToFile(a);
  const aRank = squareToRank(a);
  const bFile = squareToFile(b);
  const bRank = squareToRank(b);
  return Math.max(Math.abs(aFile - bFile), Math.abs(aRank - bRank));
}

// Rank and File types (0-7)
// Temporarily relaxed during refactoring
export type Rank = number;
export type File = number;

export function createRank(value: number): Rank {
  if (value < 0 || value > 7) {
    throw new Error(`Invalid rank value: ${value}. Must be 0-7.`);
  }
  return value;
}

export function createFile(value: number): File {
  if (value < 0 || value > 7) {
    throw new Error(`Invalid file value: ${value}. Must be 0-7.`);
  }
  return value;
}

export function rankFileToSquare(rank: Rank, file: File): Square {
  return createSquare(rank * 8 + file);
}
