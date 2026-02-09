export type TimeControl = {
    mode: "depth";
    maxDepth: number;
} | {
    mode: "movetime";
    timeMs: number;
} | {
    mode: "timeincrement";
    whiteTime: number;
    blackTime: number;
    whiteInc: number;
    blackInc: number;
} | {
    mode: "infinite";
};
export declare class TimeManager {
    private timeControl;
    private startTime;
    private allocatedTime;
    private maxTime;
    private moveNumber;
    private isWhite;
    private lastScore;
    private lastBestMove;
    private bestMoveChanges;
    constructor(timeControl: TimeControl, moveNumber: number, isWhite: boolean);
    private calculateTimeAllocation;
    private allocateTime;
    shouldStop(): boolean;
    shouldContinueIteration(currentDepth: number): boolean;
    reportIteration(depth: number, score: number, bestMove: number | null): void;
    elapsedMs(): number;
    allocatedTimeMs(): number | null;
    searchWasInterrupted(): boolean;
}
//# sourceMappingURL=timeManager.d.ts.map