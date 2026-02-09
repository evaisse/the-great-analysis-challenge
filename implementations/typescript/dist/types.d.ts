export type PieceType = "K" | "Q" | "R" | "B" | "N" | "P";
export type Color = "white" | "black";
export type Square = number;
export interface Piece {
    type: PieceType;
    color: Color;
}
export interface Move {
    from: Square;
    to: Square;
    piece: PieceType;
    captured?: PieceType;
    promotion?: PieceType;
    castling?: "K" | "Q" | "k" | "q";
    enPassant?: boolean;
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
export interface GameState {
    board: (Piece | null)[];
    turn: Color;
    castlingRights: CastlingRights;
    enPassantTarget: Square | null;
    halfmoveClock: number;
    fullmoveNumber: number;
    moveHistory: Move[];
    zobristHash: bigint;
    positionHistory: bigint[];
    irreversibleHistory: IrreversibleState[];
}
export declare const PIECE_VALUES: Record<PieceType, number>;
export declare const FILES: string[];
export declare const RANKS: string[];
//# sourceMappingURL=types.d.ts.map