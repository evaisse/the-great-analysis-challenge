import { Square } from "./square";
import { PieceType } from "./piece";
export type Legal = any;
export type Unchecked = any;
export interface MoveBase {
    from: Square;
    to: Square;
    piece: PieceType;
    captured?: PieceType;
    promotion?: PieceType;
    castling?: "K" | "Q" | "k" | "q";
    enPassant?: boolean;
}
export type Move<T extends Legal | Unchecked = Unchecked> = MoveBase;
export declare function createUncheckedMove(from: Square, to: Square, piece: PieceType, options?: {
    captured?: PieceType;
    promotion?: PieceType;
    castling?: "K" | "Q" | "k" | "q";
    enPassant?: boolean;
}): Move<Unchecked>;
export declare function validateMove(move: Move<Unchecked>): Move<Legal>;
export declare function isLegalMove(move: MoveBase): move is Move<Legal>;
export declare function moveToAlgebraic(move: MoveBase): string;
export declare function parseMove(notation: string, piece: PieceType): Move<Unchecked> | null;
export declare function moveToBase(move: Move<any>): MoveBase;
//# sourceMappingURL=move.d.ts.map