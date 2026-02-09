import { Board } from "../board";
import { PIECE_VALUES } from "../types";
import * as tables from "./tables";
import * as tapered from "./tapered";
import * as mobility from "./mobility";
import * as pawnStructure from "./pawnStructure";
import * as kingSafety from "./kingSafety";
import * as positional from "./positional";

export class RichEvaluator {
  constructor() {}

  public evaluate(board: Board): number {
    const phase = this.computePhase(board);
    
    const mgScore = this.evaluatePhase(board, true);
    const egScore = this.evaluatePhase(board, false);
    
    const taperedScore = tapered.interpolate(mgScore, egScore, phase);
    
    const mobilityScore = mobility.evaluate(board);
    const pawnScore = pawnStructure.evaluate(board);
    const kingScore = kingSafety.evaluate(board);
    const positionalScore = positional.evaluate(board);
    
    return taperedScore + mobilityScore + pawnScore + kingScore + positionalScore;
  }

  private computePhase(board: Board): number {
    let phase = 0;
    
    for (let square = 0; square < 64; square++) {
      const piece = board.getPiece(square);
      if (piece) {
        switch (piece.type) {
          case "N":
            phase += 1;
            break;
          case "B":
            phase += 1;
            break;
          case "R":
            phase += 2;
            break;
          case "Q":
            phase += 4;
            break;
        }
      }
    }
    
    return Math.min(phase, 24);
  }

  private evaluatePhase(board: Board, middlegame: boolean): number {
    let score = 0;
    
    for (let square = 0; square < 64; square++) {
      const piece = board.getPiece(square);
      if (piece) {
        const value = PIECE_VALUES[piece.type];
        const positionBonus = middlegame
          ? tables.getMiddlegameBonus(square, piece.type, piece.color)
          : tables.getEndgameBonus(square, piece.type, piece.color);
        
        const totalValue = value + positionBonus;
        score += piece.color === "white" ? totalValue : -totalValue;
      }
    }
    
    return score;
  }
}
