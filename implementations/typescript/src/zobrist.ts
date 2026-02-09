import { Piece, PieceType, Color, Square, CastlingRights, GameState } from "./types";

export type ZobristKey = bigint;

export class ZobristTable {
  private pieceKeys: bigint[][][]; // [pieceType][color][square]
  private castlingKeys: bigint[]; // [rights] (0-15)
  private enPassantKeys: bigint[]; // [file] (0-7)
  private blackToMove: bigint;

  constructor() {
    this.pieceKeys = [];
    this.castlingKeys = new Array(16);
    this.enPassantKeys = new Array(8);
    this.blackToMove = 0n;

    this.initialize();
  }

  private initialize(): void {
    const rng = new SimplePRNG(0x0123456789abcdefn);

    // Initialize piece keys [6 piece types][2 colors][64 squares]
    for (let pieceType = 0; pieceType < 6; pieceType++) {
      this.pieceKeys[pieceType] = [];
      for (let color = 0; color < 2; color++) {
        this.pieceKeys[pieceType][color] = [];
        for (let square = 0; square < 64; square++) {
          this.pieceKeys[pieceType][color][square] = rng.next();
        }
      }
    }

    // Initialize castling keys
    for (let i = 0; i < 16; i++) {
      this.castlingKeys[i] = rng.next();
    }

    // Initialize en passant keys
    for (let file = 0; file < 8; file++) {
      this.enPassantKeys[file] = rng.next();
    }

    // Initialize black to move key
    this.blackToMove = rng.next();
  }

  public pieceKey(piece: Piece, square: Square): bigint {
    const pieceIdx = this.pieceTypeToIndex(piece.type);
    const colorIdx = piece.color === "white" ? 0 : 1;
    return this.pieceKeys[pieceIdx][colorIdx][square];
  }

  public castlingKey(rights: CastlingRights): bigint {
    let index = 0;
    if (rights.whiteKingside) index |= 1;
    if (rights.whiteQueenside) index |= 2;
    if (rights.blackKingside) index |= 4;
    if (rights.blackQueenside) index |= 8;
    return this.castlingKeys[index];
  }

  public enPassantKey(file: number): bigint {
    return this.enPassantKeys[file];
  }

  public blackToMoveKey(): bigint {
    return this.blackToMove;
  }

  private pieceTypeToIndex(type: PieceType): number {
    switch (type) {
      case "P": return 0;
      case "N": return 1;
      case "B": return 2;
      case "R": return 3;
      case "Q": return 4;
      case "K": return 5;
    }
  }
}

class SimplePRNG {
  private state: bigint;

  constructor(seed: bigint) {
    this.state = seed;
  }

  public next(): bigint {
    const MULTIPLIER = 6364136223846793005n;
    const INCREMENT = 1442695040888963407n;
    const MASK_64 = (1n << 64n) - 1n;

    this.state = (this.state * MULTIPLIER + INCREMENT) & MASK_64;
    return this.state;
  }
}

export function computeHash(state: GameState, zobrist: ZobristTable): bigint {
  let hash = 0n;

  // Hash all pieces on the board
  for (let square = 0; square < 64; square++) {
    const piece = state.board[square];
    if (piece) {
      hash ^= zobrist.pieceKey(piece, square);
    }
  }

  // Hash castling rights
  hash ^= zobrist.castlingKey(state.castlingRights);

  // Hash en passant target
  if (state.enPassantTarget !== null) {
    const file = state.enPassantTarget % 8;
    hash ^= zobrist.enPassantKey(file);
  }

  // Hash side to move
  if (state.turn === "black") {
    hash ^= zobrist.blackToMoveKey();
  }

  return hash;
}

export function updateHashAfterMove(
  hash: bigint,
  from: Square,
  to: Square,
  movedPiece: Piece,
  capturedPiece: Piece | null,
  oldEp: Square | null,
  newEp: Square | null,
  oldCastling: CastlingRights,
  newCastling: CastlingRights,
  zobrist: ZobristTable
): bigint {
  // Remove moved piece from source square
  hash ^= zobrist.pieceKey(movedPiece, from);

  // Add moved piece to destination square
  hash ^= zobrist.pieceKey(movedPiece, to);

  // Remove captured piece if any
  if (capturedPiece) {
    hash ^= zobrist.pieceKey(capturedPiece, to);
  }

  // Update en passant
  if (oldEp !== null) {
    const file = oldEp % 8;
    hash ^= zobrist.enPassantKey(file);
  }
  if (newEp !== null) {
    const file = newEp % 8;
    hash ^= zobrist.enPassantKey(file);
  }

  // Update castling rights
  if (!castlingRightsEqual(oldCastling, newCastling)) {
    hash ^= zobrist.castlingKey(oldCastling);
    hash ^= zobrist.castlingKey(newCastling);
  }

  // Toggle side to move
  hash ^= zobrist.blackToMoveKey();

  return hash;
}

function castlingRightsEqual(a: CastlingRights, b: CastlingRights): boolean {
  return (
    a.whiteKingside === b.whiteKingside &&
    a.whiteQueenside === b.whiteQueenside &&
    a.blackKingside === b.blackKingside &&
    a.blackQueenside === b.blackQueenside
  );
}
