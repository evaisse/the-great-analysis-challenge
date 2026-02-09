import { Piece, Color } from "./piece";
import { Square } from "./square";
import { Move, Legal, Unchecked, MoveBase } from "./move";
import { CastlingRights } from "./castling";

// Phantom types - temporarily disabled for gradual migration
export type WhiteToMove = any;
export type BlackToMove = any;

// Type alias for the active state
export type ActiveState = WhiteToMove | BlackToMove;

// Board state structure (without phantom type during transition)
export interface BoardStateData {
  board: (Piece | null)[];
  turn: Color;
  castlingRights: CastlingRights;
  enPassantTarget: Square | null;
  halfmoveClock: number;
  fullmoveNumber: number;
  moveHistory: MoveBase[];
}

// Board with phantom type - temporarily same as BoardStateData
export type BoardState<T extends ActiveState = WhiteToMove> = BoardStateData;

// Type-safe state transition constructors - simplified during transition
export function createWhiteToMoveState(data: BoardStateData): BoardState<WhiteToMove> {
  if (data.turn !== "white") {
    throw new Error("Cannot create WhiteToMove state when turn is not white");
  }
  return data;
}

export function createBlackToMoveState(data: BoardStateData): BoardState<BlackToMove> {
  if (data.turn !== "black") {
    throw new Error("Cannot create BlackToMove state when turn is not black");
  }
  return data;
}

// Helper to create board state with correct phantom type
export function createBoardState(data: BoardStateData): BoardState<WhiteToMove> | BoardState<BlackToMove> {
  return data;
}

// Type-safe state transition - simplified during transition
export function transitionState<T extends ActiveState>(
  state: BoardState<T>,
  newData: BoardStateData
): T extends WhiteToMove ? BoardState<BlackToMove> : BoardState<WhiteToMove> {
  return newData as any;
}

// Strip phantom type for compatibility
export function stateToData<T extends ActiveState>(state: BoardState<T>): BoardStateData {
  return state;
}

// Type guards
export function isWhiteToMove(state: BoardStateData): state is BoardState<WhiteToMove> {
  return state.turn === "white";
}

export function isBlackToMove(state: BoardStateData): state is BoardState<BlackToMove> {
  return state.turn === "black";
}
