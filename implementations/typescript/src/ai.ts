import { Board } from "./board";
import { MoveGenerator } from "./moveGenerator";
import { Move, PIECE_VALUES } from "./types";

export class AI {
  private board: Board;
  private moveGenerator: MoveGenerator;
  private nodesEvaluated: number = 0;

  private static readonly PAWN_TABLE: number[] = [
    0, 0, 0, 0, 0, 0, 0, 0,
    50, 50, 50, 50, 50, 50, 50, 50,
    10, 10, 20, 30, 30, 20, 10, 10,
    5, 5, 10, 25, 25, 10, 5, 5,
    0, 0, 0, 20, 20, 0, 0, 0,
    5, -5, -10, 0, 0, -10, -5, 5,
    5, 10, 10, -20, -20, 10, 10, 5,
    0, 0, 0, 0, 0, 0, 0, 0,
  ];

  private static readonly KNIGHT_TABLE: number[] = [
    -50, -40, -30, -30, -30, -30, -40, -50,
    -40, -20, 0, 0, 0, 0, -20, -40,
    -30, 0, 10, 15, 15, 10, 0, -30,
    -30, 5, 15, 20, 20, 15, 5, -30,
    -30, 0, 15, 20, 20, 15, 0, -30,
    -30, 5, 10, 15, 15, 10, 5, -30,
    -40, -20, 0, 5, 5, 0, -20, -40,
    -50, -40, -30, -30, -30, -30, -40, -50,
  ];

  private static readonly BISHOP_TABLE: number[] = [
    -20, -10, -10, -10, -10, -10, -10, -20,
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 10, 10, 5, 0, -10,
    -10, 5, 5, 10, 10, 5, 5, -10,
    -10, 0, 10, 10, 10, 10, 0, -10,
    -10, 10, 10, 10, 10, 10, 10, -10,
    -10, 5, 0, 0, 0, 0, 5, -10,
    -20, -10, -10, -10, -10, -10, -10, -20,
  ];

  private static readonly ROOK_TABLE: number[] = [
    0, 0, 0, 0, 0, 0, 0, 0,
    5, 10, 10, 10, 10, 10, 10, 5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    0, 0, 0, 5, 5, 0, 0, 0,
  ];

  private static readonly QUEEN_TABLE: number[] = [
    -20, -10, -10, -5, -5, -10, -10, -20,
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 5, 5, 5, 0, -10,
     -5, 0, 5, 5, 5, 5, 0, -5,
      0, 0, 5, 5, 5, 5, 0, -5,
    -10, 5, 5, 5, 5, 5, 0, -10,
    -10, 0, 5, 0, 0, 0, 0, -10,
    -20, -10, -10, -5, -5, -10, -10, -20,
  ];

  private static readonly KING_TABLE: number[] = [
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -20, -30, -30, -40, -40, -30, -30, -20,
    -10, -20, -20, -20, -20, -20, -20, -10,
     20, 20,  0,  0,  0,  0, 20, 20,
     20, 30, 10,  0,  0, 10, 30, 20
  ];

  constructor(board: Board, moveGenerator: MoveGenerator) {
    this.board = board;
    this.moveGenerator = moveGenerator;
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

    const orderedMoves = this.orderMoves(moves);
    const maximizing = color === "white";

    let bestMove: Move | null = null;
    let bestEval = maximizing ? -Infinity : Infinity;

    let alpha = -Infinity;
    let beta = Infinity;

    for (const move of orderedMoves) {
      this.board.makeMove(move);

      const evaluation = this.minimax(depth - 1, alpha, beta, !maximizing);

      this.board.undoMove();

      if (maximizing) {
        if (evaluation > bestEval || bestMove === null) {
          bestEval = evaluation;
          bestMove = move;
        }
        alpha = Math.max(alpha, evaluation);
      } else {
        if (evaluation < bestEval || bestMove === null) {
          bestEval = evaluation;
          bestMove = move;
        }
        beta = Math.min(beta, evaluation);
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

  public evaluatePosition(): number {
    return this.evaluate();
  }

  private minimax(
    depth: number,
    alpha: number,
    beta: number,
    maximizing: boolean,
  ): number {
    this.nodesEvaluated++;

    if (depth === 0) {
      return this.evaluate();
    }

    const color = this.board.getTurn();
    const moves = this.moveGenerator.getLegalMoves(color);

    if (moves.length === 0) {
      if (this.moveGenerator.isInCheck(color)) {
        return maximizing ? -100000 : 100000;
      }
      return 0;
    }

    const orderedMoves = this.orderMoves(moves);

    if (maximizing) {
      let maxEval = -Infinity;

      for (const move of orderedMoves) {
        this.board.makeMove(move);

        const evaluation = this.minimax(depth - 1, alpha, beta, false);

        this.board.undoMove();

        maxEval = Math.max(maxEval, evaluation);
        alpha = Math.max(alpha, evaluation);

        if (beta <= alpha) {
          break;
        }
      }

      return maxEval;
    } else {
      let minEval = Infinity;

      for (const move of orderedMoves) {
        this.board.makeMove(move);

        const evaluation = this.minimax(depth - 1, alpha, beta, true);

        this.board.undoMove();

        minEval = Math.min(minEval, evaluation);
        beta = Math.min(beta, evaluation);

        if (beta <= alpha) {
          break;
        }
      }

      return minEval;
    }
  }

  private evaluate(): number {
    let score = 0;

    for (let square = 0; square < 64; square++) {
      const piece = this.board.getPiece(square);
      if (piece) {
        const row = Math.floor(square / 8);
        const col = square % 8;
        const evalRow = piece.color === "white" ? row : 7 - row;
        const tableIdx = evalRow * 8 + col;

        let positionBonus = 0;
        switch (piece.type) {
          case "P":
            positionBonus = AI.PAWN_TABLE[tableIdx];
            break;
          case "N":
            positionBonus = AI.KNIGHT_TABLE[tableIdx];
            break;
          case "B":
            positionBonus = AI.BISHOP_TABLE[tableIdx];
            break;
          case "R":
            positionBonus = AI.ROOK_TABLE[tableIdx];
            break;
          case "Q":
            positionBonus = AI.QUEEN_TABLE[tableIdx];
            break;
          case "K":
            positionBonus = AI.KING_TABLE[tableIdx];
            break;
        }

        const totalValue = PIECE_VALUES[piece.type] + positionBonus;
        score += piece.color === "white" ? totalValue : -totalValue;
      }
    }

    return score;
  }

  private orderMoves(moves: Move[]): Move[] {
    const scored = moves.map((move) => ({
      move,
      score: this.scoreMove(move),
      notation: this.moveToNotation(move),
    }));

    scored.sort((a, b) => {
      if (a.score !== b.score) {
        return b.score - a.score;
      }
      if (a.notation < b.notation) {
        return -1;
      }
      if (a.notation > b.notation) {
        return 1;
      }
      return 0;
    });

    return scored.map((entry) => entry.move);
  }

  private scoreMove(move: Move): number {
    let score = 0;

    const attacker = this.board.getPiece(move.from);
    const attackerValue = attacker ? PIECE_VALUES[attacker.type] : 0;

    const targetType = move.captured ?? this.board.getPiece(move.to)?.type;
    if (targetType) {
      const victimValue = PIECE_VALUES[targetType];
      score += victimValue * 10 - attackerValue;
    }

    if (move.promotion) {
      score += PIECE_VALUES[move.promotion] * 10;
    }

    const toRow = Math.floor(move.to / 8);
    const toCol = move.to % 8;
    if ((toRow === 3 || toRow === 4) && (toCol === 3 || toCol === 4)) {
      score += 10;
    }

    if (move.castling) {
      score += 50;
    }

    return score;
  }

  private moveToNotation(move: Move): string {
    const from = this.board.squareToAlgebraic(move.from);
    const to = this.board.squareToAlgebraic(move.to);
    const promotion = move.promotion ? move.promotion.toLowerCase() : "";
    return `${from}${to}${promotion}`;
  }
}
