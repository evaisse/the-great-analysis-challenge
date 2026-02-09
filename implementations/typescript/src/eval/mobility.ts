import { Board } from "../board";
import { Color, PieceType, Square } from "../types";

const KNIGHT_MOBILITY: number[] = [-15, -5, 0, 5, 10, 15, 20, 22, 24];
const BISHOP_MOBILITY: number[] = [-20, -10, 0, 5, 10, 15, 18, 21, 24, 26, 28, 30, 32, 34];
const ROOK_MOBILITY: number[] = [-15, -8, 0, 3, 6, 9, 12, 14, 16, 18, 20, 22, 24, 26, 28];
const QUEEN_MOBILITY: number[] = [
  -10, -5, 0, 2, 4, 6, 8, 10, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 22, 23, 23, 24, 24, 25, 25, 26, 26
];

export function evaluate(board: Board): number {
  let score = 0;
  
  for (let square = 0; square < 64; square++) {
    const piece = board.getPiece(square);
    if (piece) {
      let mobility = 0;
      switch (piece.type) {
        case "N":
          mobility = countKnightMobility(board, square, piece.color);
          break;
        case "B":
          mobility = countBishopMobility(board, square, piece.color);
          break;
        case "R":
          mobility = countRookMobility(board, square, piece.color);
          break;
        case "Q":
          mobility = countQueenMobility(board, square, piece.color);
          break;
        default:
          continue;
      }
      
      const bonus = getMobilityBonus(piece.type, mobility);
      score += piece.color === "white" ? bonus : -bonus;
    }
  }
  
  return score;
}

function countKnightMobility(board: Board, square: Square, _color: Color): number {
  const offsets: [number, number][] = [
    [-2, -1], [-2, 1], [-1, -2], [-1, 2],
    [1, -2], [1, 2], [2, -1], [2, 1],
  ];
  
  const rank = Math.floor(square / 8);
  const file = square % 8;
  let count = 0;
  
  for (const [dr, df] of offsets) {
    const newRank = rank + dr;
    const newFile = file + df;
    
    if (newRank >= 0 && newRank < 8 && newFile >= 0 && newFile < 8) {
      const target = newRank * 8 + newFile;
      const targetPiece = board.getPiece(target);
      const sourcePiece = board.getPiece(square);
      
      if (targetPiece) {
        if (sourcePiece && targetPiece.color !== sourcePiece.color) {
          count++;
        }
      } else {
        count++;
      }
    }
  }
  
  return count;
}

function countBishopMobility(board: Board, square: Square, color: Color): number {
  return countSlidingMobility(board, square, color, [[1, 1], [1, -1], [-1, 1], [-1, -1]]);
}

function countRookMobility(board: Board, square: Square, color: Color): number {
  return countSlidingMobility(board, square, color, [[0, 1], [0, -1], [1, 0], [-1, 0]]);
}

function countQueenMobility(board: Board, square: Square, color: Color): number {
  return countSlidingMobility(board, square, color, [
    [0, 1], [0, -1], [1, 0], [-1, 0],
    [1, 1], [1, -1], [-1, 1], [-1, -1],
  ]);
}

function countSlidingMobility(board: Board, square: Square, color: Color, directions: number[][]): number {
  const rank = Math.floor(square / 8);
  const file = square % 8;
  let count = 0;
  
  for (const [dr, df] of directions) {
    let currentRank = rank + dr;
    let currentFile = file + df;
    
    while (currentRank >= 0 && currentRank < 8 && currentFile >= 0 && currentFile < 8) {
      const target = currentRank * 8 + currentFile;
      const targetPiece = board.getPiece(target);
      
      if (targetPiece) {
        if (targetPiece.color !== color) {
          count++;
        }
        break;
      } else {
        count++;
      }
      
      currentRank += dr;
      currentFile += df;
    }
  }
  
  return count;
}

function getMobilityBonus(pieceType: PieceType, mobility: number): number {
  switch (pieceType) {
    case "N": return KNIGHT_MOBILITY[Math.min(mobility, 8)];
    case "B": return BISHOP_MOBILITY[Math.min(mobility, 13)];
    case "R": return ROOK_MOBILITY[Math.min(mobility, 14)];
    case "Q": return QUEEN_MOBILITY[Math.min(mobility, 27)];
    default: return 0;
  }
}
