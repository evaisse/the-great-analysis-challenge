import { Board } from "./board";
import { MoveGenerator } from "./moveGenerator";
import { Move, Color, Square, PIECE_VALUES } from "./types";
import {
  TranspositionTable,
  BoundType,
  encodeMove,
} from "./transpositionTable";

export class AI {
  private board: Board;
  private moveGenerator: MoveGenerator;
  private nodesEvaluated: number = 0;
  private tt: TranspositionTable;

  constructor(board: Board, moveGenerator: MoveGenerator) {
    this.board = board;
    this.moveGenerator = moveGenerator;
    this.tt = new TranspositionTable(16);
  }

  public getTranspositionTable(): TranspositionTable {
    return this.tt;
  }

  public findBestMove(depth: number): {
    move: Move | null;
    eval: number;
    nodes: number;
    time: number;
  } {
    const startTime = Date.now();
    this.nodesEvaluated = 0;

    const color = this.board.getTurn();
    const moves = this.moveGenerator.getLegalMoves(color);

    if (moves.length === 0) {
      return { move: null, eval: 0, nodes: 0, time: 0 };
    }

    let bestMove = moves[0];
    let bestEval = color === "white" ? -Infinity : Infinity;
    const alpha = -Infinity;
    const beta = Infinity;

    for (const move of moves) {
      const state = this.board.getState();
      this.board.makeMove(move);

      const evaluation = this.minimax(
        depth - 1,
        alpha,
        beta,
        color === "black",
      );

      this.board.setState(state);

      if (color === "white" && evaluation > bestEval) {
        bestEval = evaluation;
        bestMove = move;
      } else if (color === "black" && evaluation < bestEval) {
        bestEval = evaluation;
        bestMove = move;
      }
    }

    const endTime = Date.now();
    return {
      move: bestMove,
      eval: bestEval,
      nodes: this.nodesEvaluated,
      time: endTime - startTime,
    };
  }

  private minimax(
    depth: number,
    alpha: number,
    beta: number,
    maximizing: boolean,
  ): number {
    this.nodesEvaluated++;

    // Probe transposition table
    const hash = this.board.getHash();
    const originalAlpha = alpha;

    const ttEntry = this.tt.probe(hash);
    if (ttEntry && ttEntry.depth >= depth) {
      if (ttEntry.bound === BoundType.Exact) {
        return ttEntry.score;
      } else if (ttEntry.bound === BoundType.LowerBound) {
        alpha = Math.max(alpha, ttEntry.score);
      } else if (ttEntry.bound === BoundType.UpperBound) {
        beta = Math.min(beta, ttEntry.score);
      }
      if (alpha >= beta) {
        return ttEntry.score;
      }
    }

    if (depth === 0) {
      const score = this.evaluate();
      this.tt.store(hash, 0, score, BoundType.Exact, null);
      return score;
    }

    const color = this.board.getTurn();
    const moves = this.moveGenerator.getLegalMoves(color);

    if (moves.length === 0) {
      const score = this.moveGenerator.isInCheck(color)
        ? (maximizing ? -100000 : 100000)
        : 0;
      this.tt.store(hash, depth, score, BoundType.Exact, null);
      return score;
    }

    if (maximizing) {
      let maxEval = -Infinity;
      let bestMove: number | null = null;

      for (const move of moves) {
        const state = this.board.getState();
        this.board.makeMove(move);

        const evaluation = this.minimax(depth - 1, alpha, beta, false);

        this.board.setState(state);

        if (evaluation > maxEval) {
          maxEval = evaluation;
          bestMove = encodeMove(move.from, move.to);
        }
        alpha = Math.max(alpha, evaluation);

        if (beta <= alpha) {
          break;
        }
      }

      // Determine bound type
      const bound =
        maxEval <= originalAlpha
          ? BoundType.UpperBound
          : maxEval >= beta
          ? BoundType.LowerBound
          : BoundType.Exact;

      this.tt.store(hash, depth, maxEval, bound, bestMove);
      return maxEval;
    } else {
      let minEval = Infinity;
      let bestMove: number | null = null;

      for (const move of moves) {
        const state = this.board.getState();
        this.board.makeMove(move);

        const evaluation = this.minimax(depth - 1, alpha, beta, true);

        this.board.setState(state);

        if (evaluation < minEval) {
          minEval = evaluation;
          bestMove = encodeMove(move.from, move.to);
        }
        beta = Math.min(beta, evaluation);

        if (beta <= alpha) {
          break;
        }
      }

      // Determine bound type
      const bound =
        minEval <= alpha
          ? BoundType.LowerBound
          : minEval >= beta
          ? BoundType.UpperBound
          : BoundType.Exact;

      this.tt.store(hash, depth, minEval, bound, bestMove);
      return minEval;
    }
  }

  private evaluate(): number {
    let score = 0;

    for (let square = 0; square < 64; square++) {
      const piece = this.board.getPiece(square);
      if (piece) {
        const value = PIECE_VALUES[piece.type];
        const positionBonus = this.getPositionBonus(
          square,
          piece.type,
          piece.color,
        );
        const totalValue = value + positionBonus;

        score += piece.color === "white" ? totalValue : -totalValue;
      }
    }

    return score;
  }

  private getPositionBonus(
    square: Square,
    pieceType: string,
    color: Color,
  ): number {
    const file = square % 8;
    const rank = Math.floor(square / 8);
    let bonus = 0;

    const centerSquares = [27, 28, 35, 36];
    if (centerSquares.includes(square)) {
      bonus += 10;
    }

    if (pieceType === "P") {
      const advancement = color === "white" ? rank : 7 - rank;
      bonus += advancement * 5;
    }

    if (pieceType === "K") {
      const isEndgame = this.isEndgame();
      if (!isEndgame) {
        const kingSafetyRow = color === "white" ? 0 : 7;
        if (rank === kingSafetyRow && (file <= 2 || file >= 5)) {
          bonus += 20;
        } else {
          bonus -= 20;
        }
      }
    }

    return bonus;
  }

  private isEndgame(): number {
    let pieceCount = 0;
    let queenCount = 0;

    for (let square = 0; square < 64; square++) {
      const piece = this.board.getPiece(square);
      if (piece) {
        if (piece.type !== "K" && piece.type !== "P") {
          pieceCount++;
          if (piece.type === "Q") {
            queenCount++;
          }
        }
      }
    }

    return pieceCount <= 4 || (pieceCount <= 6 && queenCount === 0) ? 1 : 0;
  }
}
