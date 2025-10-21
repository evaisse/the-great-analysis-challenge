import { Board } from './board';
import { MoveGenerator } from './moveGenerator';
import { Color } from './types';

export class Perft {
  private board: Board;
  private moveGenerator: MoveGenerator;

  constructor(board: Board, moveGenerator: MoveGenerator) {
    this.board = board;
    this.moveGenerator = moveGenerator;
  }

  public perft(depth: number): number {
    if (depth === 0) {
      return 1;
    }

    const color = this.board.getTurn();
    const moves = this.moveGenerator.getLegalMoves(color);
    let nodes = 0;

    for (const move of moves) {
      const state = this.board.getState();
      this.board.makeMove(move);
      nodes += this.perft(depth - 1);
      this.board.setState(state);
    }

    return nodes;
  }

  public perftDivide(depth: number): Map<string, number> {
    const results = new Map<string, number>();
    const color = this.board.getTurn();
    const moves = this.moveGenerator.getLegalMoves(color);

    for (const move of moves) {
      const state = this.board.getState();
      const from = this.board.squareToAlgebraic(move.from);
      const to = this.board.squareToAlgebraic(move.to);
      const moveStr = from + to + (move.promotion || '');
      
      this.board.makeMove(move);
      const count = this.perft(depth - 1);
      this.board.setState(state);
      
      results.set(moveStr, count);
    }

    return results;
  }
}