import { Board } from "./board";
import { Piece, CastlingRights, Square, GameState } from "./types";
import { zobrist } from "./zobrist";

export class FenParser {
  private board: Board;

  constructor(board: Board) {
    this.board = board;
  }

  public parseFen(fen: string): void {
    const parts = fen.trim().split(/\s+/);
    if (parts.length < 4) {
      throw new Error("ERROR: Invalid FEN string");
    }

    const [pieces, turn, castling, enPassant, halfmove = "0", fullmove = "1"] =
      parts;

    const boardState: (Piece | null)[] = new Array(64).fill(null);
    let square = 56;
    for (const char of pieces) {
      if (char === "/") {
        square -= 16;
      } else if ("12345678".includes(char)) {
        square += parseInt(char, 10);
      } else {
        const piece = this.charToPiece(char);
        if (piece) {
          boardState[square] = piece;
          square++;
        }
      }
    }

    const color = turn === "w" ? "white" : "black";

    const rights: CastlingRights = {
      whiteKingside: castling.includes("K"),
      whiteQueenside: castling.includes("Q"),
      blackKingside: castling.includes("k"),
      blackQueenside: castling.includes("q"),
    };

    let enPassantTarget: Square | null = null;
    if (enPassant !== "-") {
      try {
        enPassantTarget = this.board.algebraicToSquare(
          enPassant.toLowerCase(),
        );
      } catch {
        enPassantTarget = null;
      }
    }

    const halfmoveClock = parseInt(halfmove, 10) || 0;
    const fullmoveNumber = parseInt(fullmove, 10) || 1;

    const newState: GameState = {
      board: boardState,
      turn: color,
      castlingRights: rights,
      enPassantTarget,
      halfmoveClock,
      fullmoveNumber,
      moveHistory: [],
      positionHistory: [],
      irreversibleHistory: [],
      zobristHash: 0n,
    };

    newState.zobristHash = zobrist.computeHash(newState);
    this.board.setState(newState);
  }

  public exportFen(): string {
    const pieces = this.getPiecesString();
    const turn = this.board.getTurn() === "white" ? "w" : "b";
    const castling = this.getCastlingString();
    const enPassant = this.getEnPassantString();
    const state = this.board.getState();

    return `${pieces} ${turn} ${castling} ${enPassant} ${state.halfmoveClock} ${state.fullmoveNumber}`;
  }

  private getPiecesString(): string {
    let result = "";

    for (let rank = 7; rank >= 0; rank--) {
      let emptyCount = 0;

      for (let file = 0; file < 8; file++) {
        const square = rank * 8 + file;
        const piece = this.board.getPiece(square);

        if (piece) {
          if (emptyCount > 0) {
            result += emptyCount.toString();
            emptyCount = 0;
          }
          result += this.pieceToChar(piece);
        } else {
          emptyCount++;
        }
      }

      if (emptyCount > 0) {
        result += emptyCount.toString();
      }

      if (rank > 0) {
        result += "/";
      }
    }

    return result;
  }

  private getCastlingString(): string {
    const rights = this.board.getCastlingRights();
    let result = "";

    if (rights.whiteKingside) result += "K";
    if (rights.whiteQueenside) result += "Q";
    if (rights.blackKingside) result += "k";
    if (rights.blackQueenside) result += "q";

    return result || "-";
  }

  private getEnPassantString(): string {
    const target = this.board.getEnPassantTarget();
    if (target === null) {
      return "-";
    }
    return this.board.squareToAlgebraic(target);
  }

  private charToPiece(char: string): Piece | null {
    const isWhite = char === char.toUpperCase();
    const type = char.toUpperCase();

    switch (type) {
      case "P":
        return { type: "P", color: isWhite ? "white" : "black" };
      case "N":
        return { type: "N", color: isWhite ? "white" : "black" };
      case "B":
        return { type: "B", color: isWhite ? "white" : "black" };
      case "R":
        return { type: "R", color: isWhite ? "white" : "black" };
      case "Q":
        return { type: "Q", color: isWhite ? "white" : "black" };
      case "K":
        return { type: "K", color: isWhite ? "white" : "black" };
      default:
        return null;
    }
  }

  private pieceToChar(piece: Piece): string {
    const char = piece.type;
    return piece.color === "white" ? char : char.toLowerCase();
  }
}
