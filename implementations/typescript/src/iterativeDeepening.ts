import { Board } from "./board";
import { AI } from "./ai";
import { TimeManager } from "./timeManager";
import { TranspositionTable, decodeMove } from "./transpositionTable";
import { Move } from "./types";

const MATE_SCORE = 100000;
const MAX_DEPTH = 100;

export interface IterativeDeepeningResult {
  bestMove: Move | null;
  bestScore: number;
  depthReached: number;
}

export function extractPV(
  board: Board,
  tt: TranspositionTable,
  depth: number
): string[] {
  const pv: string[] = [];
  const seen = new Set<string>();
  const boardCopy = new Board();
  boardCopy.setState(board.getState());
  let currentDepth = depth;

  while (currentDepth > 0) {
    const hash = boardCopy.getHash();
    const hashStr = hash.toString();

    if (seen.has(hashStr)) {
      break;
    }

    const entry = tt.probe(hash);
    if (!entry || entry.bestMove === null) {
      break;
    }

    seen.add(hashStr);

    const [from, to] = decodeMove(entry.bestMove);
    const moveStr =
      boardCopy.squareToAlgebraic(from) + boardCopy.squareToAlgebraic(to);
    pv.push(moveStr);

    // Try to make the move
    const legalMoves = boardCopy.getLegalMovesForPV();
    let found = false;

    for (const move of legalMoves) {
      if (move.from === from && move.to === to) {
        boardCopy.makeMove(move);
        found = true;
        break;
      }
    }

    if (!found) {
      break;
    }

    currentDepth--;
  }

  return pv;
}

export function iterativeDeepening(
  board: Board,
  maxDepth: number,
  timeManager: TimeManager,
  ai: AI
): IterativeDeepeningResult {
  let bestMove: Move | null = null;
  let bestScore = 0;
  let depthReached = 0;

  for (let depth = 1; depth <= maxDepth; depth++) {
    if (timeManager.shouldStop()) {
      break;
    }

    // Check if we should start this iteration
    if (!timeManager.shouldContinueIteration(depth - 1)) {
      break;
    }

    const result = ai.findBestMove(depth);

    // Check if search was interrupted
    if (timeManager.searchWasInterrupted()) {
      break;
    }

    // Update best move and score
    if (result.move !== null) {
      bestMove = result.move;
      bestScore = result.eval;
      depthReached = depth;

      // Extract PV
      const pv = extractPV(board, ai.getTranspositionTable(), depth);
      const pvStr = pv.join(" ");

      // Print info line
      console.log(
        `info depth ${depth} score cp ${bestScore} nodes ${result.nodes} time ${timeManager.elapsedMs()} pv ${pvStr}`
      );

      // Report to time manager
      const bestMoveEncoded =
        (bestMove.from | (bestMove.to << 6));
      timeManager.reportIteration(depth, bestScore, bestMoveEncoded);

      // Early exit if mate found
      if (Math.abs(bestScore) >= MATE_SCORE - MAX_DEPTH) {
        break;
      }
    } else {
      // No legal moves
      break;
    }
  }

  return {
    bestMove,
    bestScore,
    depthReached,
  };
}
