import { Board } from "./board";
import { MoveGenerator } from "./moveGenerator";
import { Move } from "./types";
import { TranspositionTable } from "./transpositionTable";
export declare class AI {
    private board;
    private moveGenerator;
    private nodesEvaluated;
    private tt;
    constructor(board: Board, moveGenerator: MoveGenerator);
    getTranspositionTable(): TranspositionTable;
    findBestMove(depth: number): {
        move: Move | null;
        eval: number;
        nodes: number;
        time: number;
    };
    private minimax;
    private evaluate;
    private getPositionBonus;
    private isEndgame;
}
//# sourceMappingURL=ai.d.ts.map