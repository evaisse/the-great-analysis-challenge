// Re-export type-safe types for backward compatibility
export type {
  PieceType,
  Color,
  Piece,
  Square,
  CastlingRights,
  Legal,
  Unchecked,
  MoveBase,
} from "./types/index";

// For backward compatibility, export Move without type parameter (defaults to Unchecked)
export type { Move } from "./types/index";

// Re-export all constructors and utilities
export {
  PIECE_VALUES,
  FILES,
  RANKS,
  createSquare,
  unsafeSquare,
  isValidSquare,
  squareToAlgebraic,
  algebraicToSquare,
  createPiece,
  createCastlingRights,
  allCastlingRights,
  noCastlingRights,
  createUncheckedMove,
  validateMove,
  moveToAlgebraic,
  parseMove,
  moveToBase,
  oppositeColor,
} from "./types/index";

// GameState type alias for backward compatibility
export type { BoardStateData as GameState } from "./types/index";
