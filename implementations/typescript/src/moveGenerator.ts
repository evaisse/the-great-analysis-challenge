import { Board } from "./board";
import {
  Color,
  LegalMove,
  Piece,
  PieceType,
  SQUARES,
  Square,
  isSquareValue,
  legalMove,
  offsetSquare,
  square,
} from "./types";
import { KING_ATTACKS, KNIGHT_ATTACKS, RAY_TABLES } from "./attackTables";

export class MoveGenerator {
  private board: Board;

  constructor(board: Board) {
    this.board = board;
  }

  public generateAllMoves(color: Color): LegalMove[] {
    const moves: LegalMove[] = [];

    for (const square of SQUARES) {
      const piece = this.board.getPiece(square);
      if (piece && piece.color === color) {
        moves.push(...this.generatePieceMoves(square, piece));
      }
    }

    return moves;
  }

  public generatePieceMoves(
    from: Square,
    piece: Piece,
    includeCastling: boolean = true,
  ): LegalMove[] {
    switch (piece.type) {
      case "P":
        return this.generatePawnMoves(from, piece);
      case "N":
        return this.generateKnightMoves(from, piece);
      case "B":
        return this.generateBishopMoves(from, piece);
      case "R":
        return this.generateRookMoves(from, piece);
      case "Q":
        return this.generateQueenMoves(from, piece);
      case "K":
        return this.generateKingMoves(from, piece, includeCastling);
      default:
        return [];
    }
  }

  private generatePawnMoves(from: Square, piece: Piece): LegalMove[] {
    const moves: LegalMove[] = [];
    const rankStep = piece.color === "white" ? 1 : -1;
    const startRank = piece.color === "white" ? 1 : 6;
    const promotionRank = piece.color === "white" ? 7 : 0;
    const rank = Math.floor(Number(from) / 8);
    const file = Number(from) % 8;

    const oneSquareForward = offsetSquare(from, 0, rankStep);
    if (oneSquareForward && !this.board.getPiece(oneSquareForward)) {
      if (Math.floor(Number(oneSquareForward) / 8) === promotionRank) {
        (["Q", "R", "B", "N"] as PieceType[]).forEach((promo) => {
          moves.push(legalMove({
            from,
            to: oneSquareForward,
            piece: "P",
            promotion: promo,
          }));
        });
      } else {
        moves.push(legalMove({ from, to: oneSquareForward, piece: "P" }));
      }

      if (rank === startRank) {
        const twoSquaresForward = offsetSquare(from, 0, rankStep * 2);
        if (twoSquaresForward && !this.board.getPiece(twoSquaresForward)) {
          moves.push(legalMove({ from, to: twoSquaresForward, piece: "P" }));
        }
      }
    }

    ([-1, 1] as const).forEach((fileOffset) => {
      const to = offsetSquare(from, fileOffset, rankStep);

      if (to && Math.abs((Number(to) % 8) - file) === 1) {
        const target = this.board.getPiece(to);
        if (target && target.color !== piece.color) {
          if (Math.floor(Number(to) / 8) === promotionRank) {
            (["Q", "R", "B", "N"] as PieceType[]).forEach((promo) => {
              moves.push(legalMove({
                from,
                to,
                piece: "P",
                captured: target.type,
                promotion: promo,
              }));
            });
          } else {
            moves.push(
              legalMove({ from, to, piece: "P", captured: target.type }),
            );
          }
        }
      }
    });

    const enPassantTarget = this.board.getEnPassantTarget();
    if (enPassantTarget !== null) {
      const epRank = Math.floor(enPassantTarget / 8);
      const expectedPawnRank = piece.color === "white" ? 4 : 3;

      if (rank === expectedPawnRank) {
        [-1, 1].forEach((offset) => {
          const adjacentSquare = offsetSquare(from, offset, 0);

          if (adjacentSquare && Math.abs((Number(adjacentSquare) % 8) - file) === 1) {
            const targetPawnSquare = adjacentSquare;
            const targetPawn = this.board.getPiece(targetPawnSquare);

            if (
              targetPawn &&
              targetPawn.type === "P" &&
              targetPawn.color !== piece.color
            ) {
              const captureSquare = enPassantTarget;
              if (
                captureSquare ===
                square(Number(targetPawnSquare) + rankStep * 8)
              ) {
                moves.push(legalMove({
                  from,
                  to: captureSquare,
                  piece: "P",
                  enPassant: true,
                  captured: "P",
                }));
              }
            }
          }
        });
      }
    }

    return moves;
  }

  private generateKnightMoves(from: Square, piece: Piece): LegalMove[] {
    const moves: LegalMove[] = [];
    KNIGHT_ATTACKS[from].forEach((to) => {
      const target = this.board.getPiece(to);
      if (!target || target.color !== piece.color) {
        moves.push(
          legalMove({ from, to, piece: "N", captured: target?.type }),
        );
      }
    });

    return moves;
  }

  private generateBishopMoves(from: Square, piece: Piece): LegalMove[] {
    return this.generateSlidingMoves(from, piece, [-9, -7, 7, 9], true);
  }

  private generateRookMoves(from: Square, piece: Piece): LegalMove[] {
    return this.generateSlidingMoves(from, piece, [-8, -1, 1, 8], false);
  }

  private generateQueenMoves(from: Square, piece: Piece): LegalMove[] {
    return this.generateSlidingMoves(
      from,
      piece,
      [-9, -8, -7, -1, 1, 7, 8, 9],
      null,
    );
  }

  private generateKingMoves(
    from: Square,
    piece: Piece,
    includeCastling: boolean = true,
  ): LegalMove[] {
    const moves: LegalMove[] = [];
    KING_ATTACKS[from].forEach((to) => {
      const target = this.board.getPiece(to);
      if (!target || target.color !== piece.color) {
        moves.push(
          legalMove({ from, to, piece: "K", captured: target?.type }),
        );
      }
    });

    if (!includeCastling) return moves;

    const rights = this.board.getCastlingRights();
    if (piece.color === "white" && from === SQUARES[4]) {
      if (
        rights.whiteKingside &&
        !this.board.getPiece(SQUARES[5]) &&
        !this.board.getPiece(SQUARES[6]) &&
        this.board.getPiece(SQUARES[7])?.type === "R"
      ) {
        if (
          !this.isSquareAttacked(SQUARES[4], "black") &&
          !this.isSquareAttacked(SQUARES[5], "black") &&
          !this.isSquareAttacked(SQUARES[6], "black")
        ) {
          moves.push(
            legalMove({
              from: SQUARES[4],
              to: SQUARES[6],
              piece: "K",
              castling: "K",
            }),
          );
        }
      }
      if (
        rights.whiteQueenside &&
        !this.board.getPiece(SQUARES[3]) &&
        !this.board.getPiece(SQUARES[2]) &&
        !this.board.getPiece(SQUARES[1]) &&
        this.board.getPiece(SQUARES[0])?.type === "R"
      ) {
        if (
          !this.isSquareAttacked(SQUARES[4], "black") &&
          !this.isSquareAttacked(SQUARES[3], "black") &&
          !this.isSquareAttacked(SQUARES[2], "black")
        ) {
          moves.push(
            legalMove({
              from: SQUARES[4],
              to: SQUARES[2],
              piece: "K",
              castling: "Q",
            }),
          );
        }
      }
    } else if (piece.color === "black" && from === SQUARES[60]) {
      if (
        rights.blackKingside &&
        !this.board.getPiece(SQUARES[61]) &&
        !this.board.getPiece(SQUARES[62]) &&
        this.board.getPiece(SQUARES[63])?.type === "R"
      ) {
        if (
          !this.isSquareAttacked(SQUARES[60], "white") &&
          !this.isSquareAttacked(SQUARES[61], "white") &&
          !this.isSquareAttacked(SQUARES[62], "white")
        ) {
          moves.push(
            legalMove({
              from: SQUARES[60],
              to: SQUARES[62],
              piece: "K",
              castling: "k",
            }),
          );
        }
      }
      if (
        rights.blackQueenside &&
        !this.board.getPiece(SQUARES[59]) &&
        !this.board.getPiece(SQUARES[58]) &&
        !this.board.getPiece(SQUARES[57]) &&
        this.board.getPiece(SQUARES[56])?.type === "R"
      ) {
        if (
          !this.isSquareAttacked(SQUARES[60], "white") &&
          !this.isSquareAttacked(SQUARES[59], "white") &&
          !this.isSquareAttacked(SQUARES[58], "white")
        ) {
          moves.push(
            legalMove({
              from: SQUARES[60],
              to: SQUARES[58],
              piece: "K",
              castling: "q",
            }),
          );
        }
      }
    }

    return moves;
  }

  private generateSlidingMoves(
    from: Square,
    piece: Piece,
    directions: number[],
    isDiagonal: boolean | null,
  ): LegalMove[] {
    const moves: LegalMove[] = [];
    for (const direction of directions) {
      const rayTable = RAY_TABLES.get(direction)!;
      for (const to of rayTable[from]) {
        const target = this.board.getPiece(to);
        if (!target) {
          moves.push(legalMove({ from, to, piece: piece.type }));
        } else if (target.color !== piece.color) {
          moves.push(
            legalMove({
              from,
              to,
              piece: piece.type,
              captured: target.type,
            }),
          );
          break;
        } else {
          break;
        }
      }
    }

    return moves;
  }

  public isSquareAttacked(square: Square, byColor: Color): boolean {
    for (const from of SQUARES) {
      const piece = this.board.getPiece(from);
      if (piece && piece.color === byColor) {
        if (piece.type === "P") {
          const rankStep = piece.color === "white" ? 1 : -1;
          if (
            offsetSquare(from, -1, rankStep) === square ||
            offsetSquare(from, 1, rankStep) === square
          ) {
            return true;
          }
          continue;
        }

        const moves = this.generatePieceMoves(from, piece, false);
        if (moves.some((move) => move.to === square)) {
          return true;
        }
      }
    }
    return false;
  }

  public isInCheck(color: Color): boolean {
    for (const square of SQUARES) {
      const piece = this.board.getPiece(square);
      if (piece && piece.type === "K" && piece.color === color) {
        return this.isSquareAttacked(
          square,
          color === "white" ? "black" : "white",
        );
      }
    }
    return false;
  }

  public getLegalMoves(color: Color): LegalMove[] {
    const moves = this.generateAllMoves(color);
    const legalMoves: LegalMove[] = [];

    for (const move of moves) {
      this.board.makeMove(move);

      if (!this.isInCheck(color)) {
        legalMoves.push(move);
      }

      this.board.undoMove();
    }

    return legalMoves;
  }

  public isCheckmate(color: Color): boolean {
    return this.isInCheck(color) && this.getLegalMoves(color).length === 0;
  }

  public isStalemate(color: Color): boolean {
    return !this.isInCheck(color) && this.getLegalMoves(color).length === 0;
  }

  private isValidSquare(value: number): value is Square {
    return isSquareValue(value);
  }
}
