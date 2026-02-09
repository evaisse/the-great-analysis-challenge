export type TimeControl =
  | { mode: "depth"; maxDepth: number }
  | { mode: "movetime"; timeMs: number }
  | {
      mode: "timeincrement";
      whiteTime: number;
      blackTime: number;
      whiteInc: number;
      blackInc: number;
    }
  | { mode: "infinite" };

export class TimeManager {
  private timeControl: TimeControl;
  private startTime: number;
  private allocatedTime: number | null;
  private maxTime: number | null;
  private moveNumber: number;
  private isWhite: boolean;
  private lastScore: number | null = null;
  private lastBestMove: number | null = null;
  private bestMoveChanges: number = 0;

  constructor(
    timeControl: TimeControl,
    moveNumber: number,
    isWhite: boolean
  ) {
    this.timeControl = timeControl;
    this.startTime = Date.now();
    this.moveNumber = moveNumber;
    this.isWhite = isWhite;

    const [allocated, max] = this.calculateTimeAllocation();
    this.allocatedTime = allocated;
    this.maxTime = max;
  }

  private calculateTimeAllocation(): [number | null, number | null] {
    if (this.timeControl.mode === "depth") {
      return [null, null];
    }

    if (this.timeControl.mode === "movetime") {
      return [this.timeControl.timeMs, this.timeControl.timeMs];
    }

    if (this.timeControl.mode === "timeincrement") {
      const { whiteTime, blackTime, whiteInc, blackInc } = this.timeControl;
      const remaining = this.isWhite ? whiteTime : blackTime;
      const increment = this.isWhite ? whiteInc : blackInc;

      const [base, max] = this.allocateTime(
        remaining,
        increment,
        this.moveNumber
      );
      return [base, max];
    }

    if (this.timeControl.mode === "infinite") {
      return [null, null];
    }

    return [null, null];
  }

  private allocateTime(
    remainingMs: number,
    incrementMs: number,
    moveNumber: number
  ): [number, number] {
    // Estimate number of moves remaining
    const estimatedMoves =
      moveNumber < 20 ? 30 : Math.max(20, 50 - moveNumber);

    // Base time allocation
    let baseTime = Math.floor(remainingMs / estimatedMoves) + incrementMs;

    // Don't use more than 50% of remaining time
    const maxTime = Math.floor(remainingMs / 2);

    baseTime = Math.min(baseTime, maxTime);

    // Absolute maximum is 80% of remaining time
    const absoluteMax = Math.floor((remainingMs * 80) / 100);

    return [baseTime, absoluteMax];
  }

  public shouldStop(): boolean {
    if (this.maxTime === null) {
      return false;
    }

    const elapsed = Date.now() - this.startTime;
    return elapsed >= this.maxTime;
  }

  public shouldContinueIteration(currentDepth: number): boolean {
    // Check depth limit
    if (this.timeControl.mode === "depth") {
      return currentDepth < this.timeControl.maxDepth;
    }

    // Check time limit
    if (this.allocatedTime !== null) {
      const elapsed = Date.now() - this.startTime;

      // Don't start next iteration if we've used most of our time
      // Heuristic: assume next iteration takes ~3x the time of all previous iterations
      if (elapsed * 4 >= this.allocatedTime) {
        return false;
      }

      // Adjust for instability
      let threshold = this.allocatedTime;

      // If score is unstable, use more time
      if (this.bestMoveChanges > 2) {
        threshold = Math.floor((threshold * 13) / 10); // +30%
      }

      if (elapsed >= threshold) {
        return false;
      }
    }

    return true;
  }

  public reportIteration(
    depth: number,
    score: number,
    bestMove: number | null
  ): void {
    // Track score instability
    if (this.lastScore !== null) {
      const scoreDiff = Math.abs(score - this.lastScore);
      // Significant score change (>50 centipawns)
      if (scoreDiff > 50) {
        this.bestMoveChanges++;
      }
    }
    this.lastScore = score;

    // Track best move changes
    if (this.lastBestMove !== null && bestMove !== null) {
      if (this.lastBestMove !== bestMove) {
        this.bestMoveChanges++;
      }
    }
    this.lastBestMove = bestMove;
  }

  public elapsedMs(): number {
    return Date.now() - this.startTime;
  }

  public allocatedTimeMs(): number | null {
    return this.allocatedTime;
  }

  public searchWasInterrupted(): boolean {
    return this.shouldStop();
  }
}
