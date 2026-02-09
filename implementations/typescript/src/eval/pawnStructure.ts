import { Board } from "../board";
import { Color, PieceType, Square } from "../types";

const PASSED_PAWN_BONUS: number[] = [0, 10, 20, 40, 60, 90, 120, 0];
const DOUBLED_PAWN_PENALTY = -20;
const ISOLATED_PAWN_PENALTY = -15;
const BACKWARD_PAWN_PENALTY = -10;
const CONNECTED_PAWN_BONUS = 5;
const PAWN_CHAIN_BONUS = 10;

export function evaluate(board: Board): number {
  let score = 0;
  
  score += evaluateColor(board, "white");
  score -= evaluateColor(board, "black");
  
  return score;
}

function evaluateColor(board: Board, color: Color): number {
  let score = 0;
  const pawnFiles: number[] = new Array(8).fill(0);
  const pawnPositions: [Square, number, number][] = [];
  
  for (let square = 0; square < 64; square++) {
    const piece = board.getPiece(square);
    if (piece && piece.color === color && piece.type === "P") {
      const file = square % 8;
      const rank = Math.floor(square / 8);
      pawnFiles[file]++;
      pawnPositions.push([square, rank, file]);
    }
  }
  
  for (const [square, rank, file] of pawnPositions) {
    if (pawnFiles[file] > 1) {
      score += DOUBLED_PAWN_PENALTY;
    }
    
    if (isIsolated(file, pawnFiles)) {
      score += ISOLATED_PAWN_PENALTY;
    }
    
    if (isPassed(board, square, rank, file, color)) {
      const bonusRank = color === "white" ? rank : 7 - rank;
      score += PASSED_PAWN_BONUS[bonusRank];
    }
    
    if (isConnected(board, square, file, color)) {
      score += CONNECTED_PAWN_BONUS;
    }
    
    if (isInChain(board, square, rank, file, color)) {
      score += PAWN_CHAIN_BONUS;
    }
    
    if (isBackward(board, square, rank, file, color, pawnFiles)) {
      score += BACKWARD_PAWN_PENALTY;
    }
  }
  
  return score;
}

function isIsolated(file: number, pawnFiles: number[]): boolean {
  const leftFile = file > 0 ? pawnFiles[file - 1] : 0;
  const rightFile = file < 7 ? pawnFiles[file + 1] : 0;
  return leftFile === 0 && rightFile === 0;
}

function isPassed(board: Board, square: Square, rank: number, file: number, color: Color): boolean {
  const startRank = color === "white" ? rank + 1 : 0;
  const endRank = color === "white" ? 8 : rank;
  const direction = color === "white" ? 1 : -1;
  
  for (let checkFile = Math.max(0, file - 1); checkFile <= Math.min(7, file + 1); checkFile++) {
    let currentRank = startRank;
    
    while (true) {
      if (color === "white") {
        if (currentRank >= endRank) break;
      } else {
        if (currentRank >= rank) break;
      }
      
      const checkSquare = currentRank * 8 + checkFile;
      const piece = board.getPiece(checkSquare);
      if (piece && piece.type === "P" && piece.color !== color) {
        return false;
      }
      
      currentRank = direction > 0 ? currentRank + 1 : Math.max(0, currentRank - 1);
      if (direction < 0 && currentRank === 0) break;
    }
  }
  
  return true;
}

function isConnected(board: Board, square: Square, file: number, color: Color): boolean {
  const rank = Math.floor(square / 8);
  
  const adjacentFiles = [Math.max(0, file - 1), Math.min(7, file + 1)];
  for (const adjacentFile of adjacentFiles) {
    if (adjacentFile !== file) {
      const adjacentSquare = rank * 8 + adjacentFile;
      const piece = board.getPiece(adjacentSquare);
      if (piece && piece.color === color && piece.type === "P") {
        return true;
      }
    }
  }
  
  return false;
}

function isInChain(board: Board, square: Square, rank: number, file: number, color: Color): boolean {
  const behindRank = color === "white" ? Math.max(0, rank - 1) : Math.min(7, rank + 1);
  
  const adjacentFiles = [Math.max(0, file - 1), Math.min(7, file + 1)];
  for (const adjacentFile of adjacentFiles) {
    if (adjacentFile !== file) {
      const checkSquare = behindRank * 8 + adjacentFile;
      const piece = board.getPiece(checkSquare);
      if (piece && piece.color === color && piece.type === "P") {
        return true;
      }
    }
  }
  
  return false;
}

function isBackward(board: Board, square: Square, rank: number, file: number, color: Color, pawnFiles: number[]): boolean {
  const leftFile = Math.max(0, file - 1);
  const rightFile = Math.min(7, file + 1);
  
  const adjacentFiles = [leftFile, rightFile];
  for (const adjacentFile of adjacentFiles) {
    if (adjacentFile !== file && pawnFiles[adjacentFile] > 0) {
      for (let checkSquare = 0; checkSquare < 64; checkSquare++) {
        const piece = board.getPiece(checkSquare);
        if (piece && piece.color === color && piece.type === "P") {
          const checkFile = checkSquare % 8;
          const checkRank = Math.floor(checkSquare / 8);
          
          if (checkFile === adjacentFile) {
            const isAhead = color === "white" ? checkRank > rank : checkRank < rank;
            
            if (isAhead) {
              return false;
            }
          }
        }
      }
    }
  }
  
  return false;
}
