import { Board } from './board';
import { MoveGenerator } from './moveGenerator';
import { Move } from './types';
export declare class AI {
    private board;
    private moveGenerator;
    private nodesEvaluated;
    constructor(board: Board, moveGenerator: MoveGenerator);
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