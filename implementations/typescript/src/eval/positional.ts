import { Board } from "../board";
import { Color, PieceType, Square } from "../types";

const BISHOP_PAIR_BONUS = 30;
const ROOK_OPEN_FILE_BONUS = 25;
const ROOK_SEMI_OPEN_FILE_BONUS = 15;
const ROOK_SEVENTH_RANK_BONUS = 20;
const KNIGHT_OUTPOST_BONUS = 20;

export function evaluate(board: Board): number {
  let score = 0;
  
  score += evaluateColor(board, "white");
  score -= evaluateColor(board, "black");
  
  return score;
}

function evaluateColor(board: Board, color: Color): number {
  let score = 0;
  
  if (hasBishopPair(board, color)) {
    score += BISHOP_PAIR_BONUS;
  }
  
  for (let square = 0; square < 64; square++) {
    const piece = board.getPiece(square);
    if (piece && piece.color === color) {
      switch (piece.type) {
        case "R":
          score += evaluateRook(board, square, color);
          break;
        case "N":
          score += evaluateKnight(board, square, color);
          break;
      }
    }
  }
  
  return score;
}

function hasBishopPair(board: Board, color: Color): boolean {
  let bishopCount = 0;
  
  for (let square = 0; square < 64; square++) {
    const piece = board.getPiece(square);
    if (piece && piece.color === color && piece.type === "B") {
      bishopCount++;
    }
  }
  
  return bishopCount >= 2;
}

function evaluateRook(board: Board, square: Square, color: Color): number {
  const file = square % 8;
  const rank = Math.floor(square / 8);
  let bonus = 0;
  
  const [ownPawns, enemyPawns] = countPawnsOnFile(board, file, color);
  
  if (ownPawns === 0 && enemyPawns === 0) {
    bonus += ROOK_OPEN_FILE_BONUS;
  } else if (ownPawns === 0) {
    bonus += ROOK_SEMI_OPEN_FILE_BONUS;
  }
  
  const seventhRank = color === "white" ? 6 : 1;
  if (rank === seventhRank) {
    bonus += ROOK_SEVENTH_RANK_BONUS;
  }
  
  return bonus;
}

function evaluateKnight(board: Board, square: Square, color: Color): number {
  if (isOutpost(board, square, color)) {
    return KNIGHT_OUTPOST_BONUS;
  } else {
    return 0;
  }
}

function isOutpost(board: Board, square: Square, color: Color): boolean {
  const file = square % 8;
  const rank = Math.floor(square / 8);
  
  const protectedByPawn = isProtectedByPawn(board, square, color);
  if (!protectedByPawn) {
    return false;
  }
  
  const cannotBeAttacked = !canBeAttackedByEnemyPawn(board, square, file, rank, color);
  
  return protectedByPawn && cannotBeAttacked;
}

function isProtectedByPawn(board: Board, square: Square, color: Color): boolean {
  const file = square % 8;
  const rank = Math.floor(square / 8);
  
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

function canBeAttackedByEnemyPawn(board: Board, square: Square, file: number, rank: number, color: Color): boolean {
  const startRank = color === "white" ? rank + 1 : 0;
  const endRank = color === "white" ? 8 : rank;
  
  for (let checkRank = startRank; color === "white" ? checkRank < endRank : checkRank < endRank; checkRank++) {
    const adjacentFiles = [Math.max(0, file - 1), Math.min(7, file + 1)];
    for (const adjacentFile of adjacentFiles) {
      if (adjacentFile !== file) {
        const checkSquare = checkRank * 8 + adjacentFile;
        const piece = board.getPiece(checkSquare);
        if (piece && piece.color !== color && piece.type === "P") {
          return true;
        }
      }
    }
  }
  
  return false;
}

function countPawnsOnFile(board: Board, file: number, color: Color): [number, number] {
  let ownPawns = 0;
  let enemyPawns = 0;
  
  for (let rank = 0; rank < 8; rank++) {
    const square = rank * 8 + file;
    const piece = board.getPiece(square);
    if (piece && piece.type === "P") {
      if (piece.color === color) {
        ownPawns++;
      } else {
        enemyPawns++;
      }
    }
  }
  
  return [ownPawns, enemyPawns];
}
