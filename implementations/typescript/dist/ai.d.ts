import { Board } from "./board";
import { MoveGenerator } from "./moveGenerator";
import { Move } from "./types";
export declare class AI {
    private board;
    private moveGenerator;
    private nodesEvaluated;
    private static readonly PAWN_TABLE;
    private static readonly KNIGHT_TABLE;
    private static readonly BISHOP_TABLE;
    private static readonly ROOK_TABLE;
    private static readonly QUEEN_TABLE;
    private static readonly KING_TABLE;
    constructor(board: Board, moveGenerator: MoveGenerator);
    findBestMove(depth: number): {
        move: Move | null;
        eval: number;
        nodes: number;
        time: number;
    };
    evaluatePosition(): number;
    private minimax;
    private evaluate;
    private orderMoves;
    private scoreMove;
    private moveToNotation;
}
//# sourceMappingURL=ai.d.ts.map