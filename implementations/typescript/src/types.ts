type Brand<T, TBrand extends string> = T & { readonly __brand: TBrand };

export type PieceType = "K" | "Q" | "R" | "B" | "N" | "P";
export type Color = "white" | "black";
export type SideToMove = Color;
export type NextTurn<TTurn extends SideToMove> = TTurn extends "white"
  ? "black"
  : "white";

type BoardAxis = 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7;

export type FileIndex = Brand<BoardAxis, "FileIndex">;
export type RankIndex = Brand<BoardAxis, "RankIndex">;
export type Square = Brand<number, "Square">;
export type CastlingSymbol = "K" | "Q" | "k" | "q";

export const FILES = ["a", "b", "c", "d", "e", "f", "g", "h"] as const;
export const RANKS = ["1", "2", "3", "4", "5", "6", "7", "8"] as const;

export type AlgebraicFile = (typeof FILES)[number];
export type AlgebraicRank = (typeof RANKS)[number];
export type AlgebraicSquare = `${AlgebraicFile}${AlgebraicRank}`;

export function square(value: number): Square {
  if (!Number.isInteger(value) || value < 0 || value >= 64) {
    throw new Error(`Invalid square index: ${value}`);
  }
  return value as Square;
}

export function unsafeSquare(value: number): Square {
  return value as Square;
}

export function isSquareValue(value: number): value is Square {
  return Number.isInteger(value) && value >= 0 && value < 64;
}

export const SQUARES: readonly Square[] = Object.freeze(
  Array.from({ length: 64 }, (_, index) => unsafeSquare(index)),
);

function toBoardAxis(value: number, label: string): BoardAxis {
  if (!Number.isInteger(value) || value < 0 || value > 7) {
    throw new Error(`Invalid ${label}: ${value}`);
  }
  return value as BoardAxis;
}

export function fileOf(boardSquare: Square): FileIndex {
  return toBoardAxis(Number(boardSquare) % 8, "file") as FileIndex;
}

export function rankOf(boardSquare: Square): RankIndex {
  return toBoardAxis(Math.floor(Number(boardSquare) / 8), "rank") as RankIndex;
}

export function squareFromCoords(file: number, rank: number): Square {
  const fileIndex = toBoardAxis(file, "file");
  const rankIndex = toBoardAxis(rank, "rank");
  return unsafeSquare(rankIndex * 8 + fileIndex);
}

export function squareToAlgebraic(boardSquare: Square): AlgebraicSquare {
  const file = Number(fileOf(boardSquare));
  const rank = Number(rankOf(boardSquare));
  return `${FILES[file]}${RANKS[rank]}` as AlgebraicSquare;
}

export function squareFromAlgebraic(algebraic: string): Square {
  const normalized = algebraic.trim().toLowerCase();
  if (normalized.length !== 2) {
    throw new Error(`Invalid algebraic notation: ${algebraic}`);
  }

  const file = FILES.indexOf(normalized[0] as AlgebraicFile);
  const rank = RANKS.indexOf(normalized[1] as AlgebraicRank);
  if (file === -1 || rank === -1) {
    throw new Error(`Invalid algebraic notation: ${algebraic}`);
  }

  return squareFromCoords(file, rank);
}

export function offsetSquare(
  origin: Square,
  fileDelta: number,
  rankDelta: number,
): Square | null {
  const nextFile = Number(fileOf(origin)) + fileDelta;
  const nextRank = Number(rankOf(origin)) + rankDelta;
  if (nextFile < 0 || nextFile > 7 || nextRank < 0 || nextRank > 7) {
    return null;
  }
  return squareFromCoords(nextFile, nextRank);
}

export function nextTurn<TTurn extends SideToMove>(turn: TTurn): NextTurn<TTurn> {
  return (turn === "white" ? "black" : "white") as NextTurn<TTurn>;
}

export interface Piece {
  type: PieceType;
  color: Color;
}

export type MoveStage = "unchecked" | "legal";

type MoveBase<TStage extends MoveStage> = {
  readonly stage: TStage;
  from: Square;
  to: Square;
  promotion?: PieceType;
};

type LegalMoveDetails = {
  piece: PieceType;
  captured?: PieceType;
  castling?: CastlingSymbol;
  enPassant?: boolean;
};

export type Move<TStage extends MoveStage = "legal"> = MoveBase<TStage> &
  (TStage extends "legal" ? LegalMoveDetails : Record<never, never>);

export type UncheckedMove = Move<"unchecked">;
export type LegalMove = Move<"legal">;

export function uncheckedMove(params: {
  from: Square;
  to: Square;
  promotion?: PieceType;
}): UncheckedMove {
  return {
    stage: "unchecked",
    from: params.from,
    to: params.to,
    promotion: params.promotion,
  };
}

export function legalMove(params: {
  from: Square;
  to: Square;
  piece: PieceType;
  captured?: PieceType;
  promotion?: PieceType;
  castling?: CastlingSymbol;
  enPassant?: boolean;
}): LegalMove {
  return {
    stage: "legal",
    from: params.from,
    to: params.to,
    piece: params.piece,
    captured: params.captured,
    promotion: params.promotion,
    castling: params.castling,
    enPassant: params.enPassant,
  };
}

export function matchesUncheckedMove(
  candidate: LegalMove,
  requested: UncheckedMove,
): boolean {
  const promotionMatches =
    candidate.promotion === requested.promotion ||
    (requested.promotion === undefined && candidate.promotion === "Q") ||
    (requested.promotion === undefined && candidate.promotion === undefined);

  return (
    candidate.from === requested.from &&
    candidate.to === requested.to &&
    promotionMatches
  );
}

export interface CastlingRights {
  whiteKingside: boolean;
  whiteQueenside: boolean;
  blackKingside: boolean;
  blackQueenside: boolean;
}

export interface IrreversibleState {
  castlingRights: CastlingRights;
  enPassantTarget: Square | null;
  halfmoveClock: number;
  zobristHash: bigint;
}

export interface GameState<TTurn extends SideToMove = SideToMove> {
  board: (Piece | null)[];
  turn: TTurn;
  castlingRights: CastlingRights;
  enPassantTarget: Square | null;
  halfmoveClock: number;
  fullmoveNumber: number;
  moveHistory: LegalMove[];
  zobristHash: bigint;
  positionHistory: bigint[];
  irreversibleHistory: IrreversibleState[];
}

export const PIECE_VALUES: Record<PieceType, number> = {
  P: 100,
  N: 320,
  B: 330,
  R: 500,
  Q: 900,
  K: 20000,
};
