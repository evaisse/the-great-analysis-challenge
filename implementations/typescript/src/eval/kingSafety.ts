import { Board } from "../board";
import { Color, PieceType, Square } from "../types";

const PAWN_SHIELD_BONUS = 20;
const OPEN_FILE_PENALTY = -30;
const SEMI_OPEN_FILE_PENALTY = -15;
const ATTACKER_WEIGHT = 10;

export function evaluate(board: Board): number {
  let score = 0;
  
  score += evaluateKingSafety(board, "white");
  score -= evaluateKingSafety(board, "black");
  
  return score;
}

function evaluateKingSafety(board: Board, color: Color): number {
  const kingSquare = findKing(board, color);
  if (kingSquare === null) {
    return 0;
  }
  
  let score = 0;
  
  score += evaluatePawnShield(board, kingSquare, color);
  score += evaluateOpenFiles(board, kingSquare, color);
  score -= evaluateAttackers(board, kingSquare, color);
  
  return score;
}

function findKing(board: Board, color: Color): Square | null {
  for (let square = 0; square < 64; square++) {
    const piece = board.getPiece(square);
    if (piece && piece.color === color && piece.type === "K") {
      return square;
    }
  }
  return null;
}

function evaluatePawnShield(board: Board, kingSquare: Square, color: Color): number {
  const kingFile = kingSquare % 8;
  const kingRank = Math.floor(kingSquare / 8);
  let shieldCount = 0;
  
  const shieldRanks = color === "white" 
    ? [kingRank + 1, kingRank + 2]
    : [Math.max(0, kingRank - 1), Math.max(0, kingRank - 2)];
  
  for (let file = Math.max(0, kingFile - 1); file <= Math.min(7, kingFile + 1); file++) {
    for (const rank of shieldRanks) {
      if (rank < 8) {
        const square = rank * 8 + file;
        const piece = board.getPiece(square);
        if (piece && piece.color === color && piece.type === "P") {
          shieldCount++;
        }
      }
    }
  }
  
  return shieldCount * PAWN_SHIELD_BONUS;
}

function evaluateOpenFiles(board: Board, kingSquare: Square, color: Color): number {
  const kingFile = kingSquare % 8;
  let penalty = 0;
  
  for (let file = Math.max(0, kingFile - 1); file <= Math.min(7, kingFile + 1); file++) {
    const [ownPawns, enemyPawns] = countPawnsOnFile(board, file, color);
    
    if (ownPawns === 0 && enemyPawns === 0) {
      penalty += OPEN_FILE_PENALTY;
    } else if (ownPawns === 0) {
      penalty += SEMI_OPEN_FILE_PENALTY;
    }
  }
  
  return penalty;
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

function evaluateAttackers(board: Board, kingSquare: Square, color: Color): number {
  const kingFile = kingSquare % 8;
  const kingRank = Math.floor(kingSquare / 8);
  let attackerCount = 0;
  
  const adjacentSquares: [number, number][] = [
    [-1, -1], [-1, 0], [-1, 1],
    [0, -1],           [0, 1],
    [1, -1],  [1, 0],  [1, 1],
  ];
  
  for (const [dr, df] of adjacentSquares) {
    const newRank = kingRank + dr;
    const newFile = kingFile + df;
    
    if (newRank >= 0 && newRank < 8 && newFile >= 0 && newFile < 8) {
      const targetSquare = newRank * 8 + newFile;
      if (isAttackedByEnemy(board, targetSquare, color)) {
        attackerCount++;
      }
    }
  }
  
  return attackerCount * ATTACKER_WEIGHT;
}

function isAttackedByEnemy(board: Board, square: Square, color: Color): boolean {
  for (let attackerSquare = 0; attackerSquare < 64; attackerSquare++) {
    const piece = board.getPiece(attackerSquare);
    if (piece && piece.color !== color) {
      if (canAttack(board, attackerSquare, square, piece.type, piece.color)) {
        return true;
      }
    }
  }
  return false;
}

function canAttack(board: Board, from: Square, to: Square, pieceType: PieceType, color: Color): boolean {
  const fromRank = Math.floor(from / 8);
  const fromFile = from % 8;
  const toRank = Math.floor(to / 8);
  const toFile = to % 8;
  const rankDiff = Math.abs(toRank - fromRank);
  const fileDiff = Math.abs(toFile - fromFile);
  
  switch (pieceType) {
    case "P": {
      const forward = color === "white" ? 1 : -1;
      return toRank - fromRank === forward && fileDiff === 1;
    }
    case "N":
      return (rankDiff === 2 && fileDiff === 1) || (rankDiff === 1 && fileDiff === 2);
    case "K":
      return rankDiff <= 1 && fileDiff <= 1;
    default:
      return false;
  }
}
