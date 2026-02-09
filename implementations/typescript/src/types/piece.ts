// Type-safe Color type
export type Color = "white" | "black";

export function oppositeColor(color: Color): Color {
  return color === "white" ? "black" : "white";
}

export function isColor(value: string): value is Color {
  return value === "white" || value === "black";
}

// Type-safe PieceType
export type PieceType = "K" | "Q" | "R" | "B" | "N" | "P";

export function isPieceType(value: string): value is PieceType {
  return ["K", "Q", "R", "B", "N", "P"].includes(value);
}

// Piece combines Color and PieceType
export interface Piece {
  readonly type: PieceType;
  readonly color: Color;
}

export function createPiece(type: PieceType, color: Color): Piece {
  return { type, color };
}

export function pieceEquals(a: Piece, b: Piece): boolean {
  return a.type === b.type && a.color === b.color;
}

// Piece values for evaluation
export const PIECE_VALUES: Record<PieceType, number> = {
  P: 100,
  N: 320,
  B: 330,
  R: 500,
  Q: 900,
  K: 20000,
};
