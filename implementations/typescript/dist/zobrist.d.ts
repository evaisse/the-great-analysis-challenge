import { Piece, Square, CastlingRights, GameState } from "./types";
export type ZobristKey = bigint;
export declare class ZobristTable {
    private pieceKeys;
    private castlingKeys;
    private enPassantKeys;
    private blackToMove;
    constructor();
    private initialize;
    pieceKey(piece: Piece, square: Square): bigint;
    castlingKey(rights: CastlingRights): bigint;
    enPassantKey(file: number): bigint;
    blackToMoveKey(): bigint;
    private pieceTypeToIndex;
}
export declare function computeHash(state: GameState, zobrist: ZobristTable): bigint;
export declare function updateHashAfterMove(hash: bigint, from: Square, to: Square, movedPiece: Piece, capturedPiece: Piece | null, oldEp: Square | null, newEp: Square | null, oldCastling: CastlingRights, newCastling: CastlingRights, zobrist: ZobristTable): bigint;
//# sourceMappingURL=zobrist.d.ts.map