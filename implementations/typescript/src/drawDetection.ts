import { GameState } from "./types";

export function isDrawByRepetition(state: GameState): boolean {
  const currentHash = state.zobristHash;
  let count = 1;

  const historyLen = state.positionHistory.length;
  // We only need to check back to the last irreversible move
  const startIdx = Math.max(0, historyLen - state.halfmoveClock);

  for (let i = historyLen - 1; i >= startIdx; i--) {
    if (state.positionHistory[i] === currentHash) {
      count++;
      if (count >= 3) return true;
    }
  }

  return false;
}

export function isDrawByFiftyMoves(state: GameState): boolean {
  return state.halfmoveClock >= 100;
}
