import { Board } from "./board";
import { AI } from "./ai";
import { TimeManager } from "./timeManager";
import { TranspositionTable } from "./transpositionTable";
import { Move } from "./types";
export interface IterativeDeepeningResult {
    bestMove: Move | null;
    bestScore: number;
    depthReached: number;
}
export declare function extractPV(board: Board, tt: TranspositionTable, depth: number): string[];
export declare function iterativeDeepening(board: Board, maxDepth: number, timeManager: TimeManager, ai: AI): IterativeDeepeningResult;
//# sourceMappingURL=iterativeDeepening.d.ts.map