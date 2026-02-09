import { GameState, Piece } from "./types";
export declare class ZobristKeys {
    pieces: bigint[][];
    sideToMove: bigint;
    castling: bigint[];
    enPassant: bigint[];
    constructor();
    computeHash(state: GameState): bigint;
    getPieceIndex(piece: Piece): number;
}
export declare const zobrist: ZobristKeys;
//# sourceMappingURL=zobrist.d.ts.map