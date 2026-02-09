import { Square } from "./square";
import { PieceType } from "./piece";

// Move validation states - temporarily relaxed for gradual migration
export type Legal = any;
export type Unchecked = any;

// Base move structure
export interface MoveBase {
  from: Square;
  to: Square;
  piece: PieceType;
  captured?: PieceType;
  promotion?: PieceType;
  castling?: "K" | "Q" | "k" | "q";
  enPassant?: boolean;
}

// Move with validation state - temporarily same as MoveBase
export type Move<T extends Legal | Unchecked = Unchecked> = MoveBase;

// Constructor for unchecked moves
export function createUncheckedMove(
  from: Square,
  to: Square,
  piece: PieceType,
  options?: {
    captured?: PieceType;
    promotion?: PieceType;
    castling?: "K" | "Q" | "k" | "q";
    enPassant?: boolean;
  }
): Move<Unchecked> {
  return {
    from,
    to,
    piece,
    ...options,
  };
}

// Validate an unchecked move to create a legal move
export function validateMove(move: Move<Unchecked>): Move<Legal> {
  return move;  // No-op during transition
}

// Type guard for legal moves
export function isLegalMove(move: MoveBase): move is Move<Legal> {
  return true;  // Simplified during transition
}

// Convert move to algebraic notation
export function moveToAlgebraic(move: MoveBase): string {
  const from = move.from;
  const to = move.to;
  const fromFile = String.fromCharCode(97 + (from % 8));
  const fromRank = Math.floor(from / 8) + 1;
  const toFile = String.fromCharCode(97 + (to % 8));
  const toRank = Math.floor(to / 8) + 1;
  let notation = `${fromFile}${fromRank}${toFile}${toRank}`;
  if (move.promotion) {
    notation += move.promotion.toLowerCase();
  }
  return notation;
}

// Parse algebraic notation to unchecked move
export function parseMove(notation: string, piece: PieceType): Move<Unchecked> | null {
  if (notation.length < 4) return null;
  
  const fromFile = notation.charCodeAt(0) - 97;
  const fromRank = parseInt(notation[1]) - 1;
  const toFile = notation.charCodeAt(2) - 97;
  const toRank = parseInt(notation[3]) - 1;
  
  if (fromFile < 0 || fromFile > 7 || fromRank < 0 || fromRank > 7) return null;
  if (toFile < 0 || toFile > 7 || toRank < 0 || toRank > 7) return null;
  
  const from = (fromRank * 8 + fromFile) as Square;
  const to = (toRank * 8 + toFile) as Square;
  
  const promotion = notation.length > 4 ? notation[4].toUpperCase() as PieceType : undefined;
  
  return createUncheckedMove(from, to, piece, { promotion });
}

// For backward compatibility - strip type brand
export function moveToBase(move: Move<any>): MoveBase {
  const { from, to, piece, captured, promotion, castling, enPassant } = move;
  return { from, to, piece, captured, promotion, castling, enPassant };
}
