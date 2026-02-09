export type Color = "white" | "black";
export declare function oppositeColor(color: Color): Color;
export declare function isColor(value: string): value is Color;
export type PieceType = "K" | "Q" | "R" | "B" | "N" | "P";
export declare function isPieceType(value: string): value is PieceType;
export interface Piece {
    readonly type: PieceType;
    readonly color: Color;
}
export declare function createPiece(type: PieceType, color: Color): Piece;
export declare function pieceEquals(a: Piece, b: Piece): boolean;
export declare const PIECE_VALUES: Record<PieceType, number>;
//# sourceMappingURL=piece.d.ts.map