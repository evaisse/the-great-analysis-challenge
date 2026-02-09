import { Piece, Color } from "./piece";
import { Square } from "./square";
import { MoveBase } from "./move";
import { CastlingRights } from "./castling";
export type WhiteToMove = any;
export type BlackToMove = any;
export type ActiveState = WhiteToMove | BlackToMove;
export interface BoardStateData {
    board: (Piece | null)[];
    turn: Color;
    castlingRights: CastlingRights;
    enPassantTarget: Square | null;
    halfmoveClock: number;
    fullmoveNumber: number;
    moveHistory: MoveBase[];
}
export type BoardState<T extends ActiveState = WhiteToMove> = BoardStateData;
export declare function createWhiteToMoveState(data: BoardStateData): BoardState<WhiteToMove>;
export declare function createBlackToMoveState(data: BoardStateData): BoardState<BlackToMove>;
export declare function createBoardState(data: BoardStateData): BoardState<WhiteToMove> | BoardState<BlackToMove>;
export declare function transitionState<T extends ActiveState>(state: BoardState<T>, newData: BoardStateData): T extends WhiteToMove ? BoardState<BlackToMove> : BoardState<WhiteToMove>;
export declare function stateToData<T extends ActiveState>(state: BoardState<T>): BoardStateData;
export declare function isWhiteToMove(state: BoardStateData): state is BoardState<WhiteToMove>;
export declare function isBlackToMove(state: BoardStateData): state is BoardState<BlackToMove>;
//# sourceMappingURL=boardState.d.ts.map