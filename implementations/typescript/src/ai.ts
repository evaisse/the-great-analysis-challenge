import { Board } from './board';
import { MoveGenerator } from './moveGenerator';
import { Move, Color, Square, PIECE_VALUES } from './types';

export class AI {
  private board: Board;
  private moveGenerator: MoveGenerator;
  private nodesEvaluated: number = 0;

  constructor(board: Board, moveGenerator: MoveGenerator) {
    this.board = board;
    this.moveGenerator = moveGenerator;
  }

  public findBestMove(depth: number): { move: Move | null; eval: number; nodes: number; time: number } {
    const startTime = Date.now();
    this.nodesEvaluated = 0;
    
    const color = this.board.getTurn();
    const moves = this.moveGenerator.getLegalMoves(color);
    
    if (moves.length === 0) {
      return { move: null, eval: 0, nodes: 0, time: 0 };
    }

    let bestMove = moves[0];
    let bestEval = color === 'white' ? -Infinity : Infinity;
    const alpha = -Infinity;
    const beta = Infinity;

    for (const move of moves) {
      const state = this.board.getState();
      this.board.makeMove(move);
      
      const evaluation = this.minimax(depth - 1, alpha, beta, color === 'black');
      
      this.board.setState(state);
      
      if (color === 'white' && evaluation > bestEval) {
        bestEval = evaluation;
        bestMove = move;
      } else if (color === 'black' && evaluation < bestEval) {
        bestEval = evaluation;
        bestMove = move;
      }
    }

    const endTime = Date.now();
    return {
      move: bestMove,
      eval: bestEval,
      nodes: this.nodesEvaluated,
      time: endTime - startTime
    };
  }

  private minimax(depth: number, alpha: number, beta: number, maximizing: boolean): number {
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

    if (maximizing) {
      let maxEval = -Infinity;
      
      for (const move of moves) {
        const state = this.board.getState();
        this.board.makeMove(move);
        
        const evaluation = this.minimax(depth - 1, alpha, beta, false);
        
        this.board.setState(state);
        
        maxEval = Math.max(maxEval, evaluation);
        alpha = Math.max(alpha, evaluation);
        
        if (beta <= alpha) {
          break;
        }
      }
      
      return maxEval;
    } else {
      let minEval = Infinity;
      
      for (const move of moves) {
        const state = this.board.getState();
        this.board.makeMove(move);
        
        const evaluation = this.minimax(depth - 1, alpha, beta, true);
        
        this.board.setState(state);
        
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
        const value = PIECE_VALUES[piece.type];
        const positionBonus = this.getPositionBonus(square, piece.type, piece.color);
        const totalValue = value + positionBonus;
        
        score += piece.color === 'white' ? totalValue : -totalValue;
      }
    }

    return score;
  }

  private getPositionBonus(square: Square, pieceType: string, color: Color): number {
    const file = square % 8;
    const rank = Math.floor(square / 8);
    let bonus = 0;

    const centerSquares = [27, 28, 35, 36];
    if (centerSquares.includes(square)) {
      bonus += 10;
    }

    if (pieceType === 'P') {
      const advancement = color === 'white' ? rank : 7 - rank;
      bonus += advancement * 5;
    }

    if (pieceType === 'K') {
      const isEndgame = this.isEndgame();
      if (!isEndgame) {
        const kingSafetyRow = color === 'white' ? 0 : 7;
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
        if (piece.type !== 'K' && piece.type !== 'P') {
          pieceCount++;
          if (piece.type === 'Q') {
            queenCount++;
          }
        }
      }
    }
    
    return pieceCount <= 4 || (pieceCount <= 6 && queenCount === 0) ? 1 : 0;
  }
}