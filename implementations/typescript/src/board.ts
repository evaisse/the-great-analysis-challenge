import {
  Piece,
  Color,
  Square,
  Move,
  CastlingRights,
  GameState,
  FILES,
  RANKS,
} from "./types";

export class Board {
  private state: GameState;

  constructor() {
    this.state = this.createInitialState();
  }

  private createInitialState(): GameState {
    const board: (Piece | null)[] = new Array(64).fill(null);

    const pieces: [Square, Piece][] = [
      [0, { type: "R", color: "white" }],
      [1, { type: "N", color: "white" }],
      [2, { type: "B", color: "white" }],
      [3, { type: "Q", color: "white" }],
      [4, { type: "K", color: "white" }],
      [5, { type: "B", color: "white" }],
      [6, { type: "N", color: "white" }],
      [7, { type: "R", color: "white" }],

      [56, { type: "R", color: "black" }],
      [57, { type: "N", color: "black" }],
      [58, { type: "B", color: "black" }],
      [59, { type: "Q", color: "black" }],
      [60, { type: "K", color: "black" }],
      [61, { type: "B", color: "black" }],
      [62, { type: "N", color: "black" }],
      [63, { type: "R", color: "black" }],
    ];

    for (let i = 8; i < 16; i++) {
      pieces.push([i, { type: "P", color: "white" }]);
    }
    for (let i = 48; i < 56; i++) {
      pieces.push([i, { type: "P", color: "black" }]);
    }

    for (const [square, piece] of pieces) {
      board[square] = piece;
    }

    return {
      board,
      turn: "white",
      castlingRights: {
        whiteKingside: true,
        whiteQueenside: true,
        blackKingside: true,
        blackQueenside: true,
      },
      enPassantTarget: null,
      halfmoveClock: 0,
      fullmoveNumber: 1,
      moveHistory: [],
    };
  }

  public reset(): void {
    this.state = this.createInitialState();
  }

  public getState(): GameState {
    return { 
      ...this.state,
      board: [...this.state.board],
      castlingRights: { ...this.state.castlingRights },
      moveHistory: [...this.state.moveHistory],
    };
  }

  public setState(state: GameState): void {
    this.state = { 
      ...state,
      board: [...state.board],
      castlingRights: { ...state.castlingRights },
      moveHistory: [...state.moveHistory],
    };
  }

  public getPiece(square: Square): Piece | null {
    return this.state.board[square];
  }

  public setPiece(square: Square, piece: Piece | null): void {
    this.state.board[square] = piece;
  }

  public getTurn(): Color {
    return this.state.turn;
  }

  public setTurn(color: Color): void {
    this.state.turn = color;
  }

  public getCastlingRights(): CastlingRights {
    return { ...this.state.castlingRights };
  }

  public setCastlingRights(rights: CastlingRights): void {
    this.state.castlingRights = { ...rights };
  }

  public getEnPassantTarget(): Square | null {
    return this.state.enPassantTarget;
  }

  public setEnPassantTarget(square: Square | null): void {
    this.state.enPassantTarget = square;
  }

  public squareToAlgebraic(square: Square): string {
    const file = square % 8;
    const rank = Math.floor(square / 8);
    return FILES[file] + RANKS[rank];
  }

  public algebraicToSquare(algebraic: string): Square {
    const file = FILES.indexOf(algebraic[0]);
    const rank = RANKS.indexOf(algebraic[1]);
    if (file === -1 || rank === -1) {
      throw new Error(`Invalid algebraic notation: ${algebraic}`);
    }
    return rank * 8 + file;
  }

  public makeMove(move: Move): void {
    const piece = this.getPiece(move.from);
    if (!piece) return;

    this.setPiece(move.to, piece);
    this.setPiece(move.from, null);

    if (move.castling) {
      const rank = piece.color === "white" ? 0 : 7;
      if (move.castling === "K" || move.castling === "k") {
        const rookFrom = rank * 8 + 7;
        const rookTo = rank * 8 + 5;
        const rook = this.getPiece(rookFrom);
        if (rook) {
          this.setPiece(rookTo, rook);
          this.setPiece(rookFrom, null);
        }
      } else {
        const rookFrom = rank * 8;
        const rookTo = rank * 8 + 3;
        const rook = this.getPiece(rookFrom);
        if (rook) {
          this.setPiece(rookTo, rook);
          this.setPiece(rookFrom, null);
        }
      }
    }

    if (move.enPassant) {
      const capturedPawnSquare = move.to + (piece.color === "white" ? -8 : 8);
      this.setPiece(capturedPawnSquare, null);
    }

    if (move.promotion) {
      this.setPiece(move.to, { type: move.promotion, color: piece.color });
    }

    const rights = this.getCastlingRights();
    if (piece.type === "K") {
      if (piece.color === "white") {
        rights.whiteKingside = false;
        rights.whiteQueenside = false;
      } else {
        rights.blackKingside = false;
        rights.blackQueenside = false;
      }
    } else if (piece.type === "R") {
      if (piece.color === "white") {
        if (move.from === 0) rights.whiteQueenside = false;
        if (move.from === 7) rights.whiteKingside = false;
      } else {
        if (move.from === 56) rights.blackQueenside = false;
        if (move.from === 63) rights.blackKingside = false;
      }
    }
    this.setCastlingRights(rights);

    if (piece.type === "P" && Math.abs(move.to - move.from) === 16) {
      const enPassantSquare = (move.from + move.to) / 2;
      this.setEnPassantTarget(enPassantSquare);
    } else {
      this.setEnPassantTarget(null);
    }

    if (piece.type === "P" || move.captured) {
      this.state.halfmoveClock = 0;
    } else {
      this.state.halfmoveClock++;
    }

    if (piece.color === "black") {
      this.state.fullmoveNumber++;
    }

    this.setTurn(piece.color === "white" ? "black" : "white");
    this.state.moveHistory.push(move);
  }

  public undoMove(): Move | null {
    const move = this.state.moveHistory.pop();
    if (!move) return null;

    const piece = this.getPiece(move.to);
    if (!piece) return null;

    if (move.promotion) {
      this.setPiece(move.from, { type: "P", color: piece.color });
    } else {
      this.setPiece(move.from, piece);
    }

    if (move.captured) {
      const capturedColor = piece.color === "white" ? "black" : "white";
      this.setPiece(move.to, { type: move.captured, color: capturedColor });
    } else {
      this.setPiece(move.to, null);
    }

    if (move.castling) {
      const rank = piece.color === "white" ? 0 : 7;
      if (move.castling === "K" || move.castling === "k") {
        const rookFrom = rank * 8 + 5;
        const rookTo = rank * 8 + 7;
        const rook = this.getPiece(rookFrom);
        if (rook) {
          this.setPiece(rookTo, rook);
          this.setPiece(rookFrom, null);
        }
      } else {
        const rookFrom = rank * 8 + 3;
        const rookTo = rank * 8;
        const rook = this.getPiece(rookFrom);
        if (rook) {
          this.setPiece(rookTo, rook);
          this.setPiece(rookFrom, null);
        }
      }
    }

    if (move.enPassant) {
      const capturedPawnSquare = move.to + (piece.color === "white" ? -8 : 8);
      const capturedColor = piece.color === "white" ? "black" : "white";
      this.setPiece(capturedPawnSquare, { type: "P", color: capturedColor });
    }

    this.setTurn(piece.color);

    return move;
  }

  public display(): string {
    let output = "  a b c d e f g h\n";

    for (let rank = 7; rank >= 0; rank--) {
      output += `${rank + 1} `;
      for (let file = 0; file < 8; file++) {
        const square = rank * 8 + file;
        const piece = this.getPiece(square);
        if (piece) {
          const char =
            piece.color === "white" ? piece.type : piece.type.toLowerCase();
          output += `${char} `;
        } else {
          output += ". ";
        }
      }
      output += `${rank + 1}\n`;
    }

    output += "  a b c d e f g h\n\n";
    output += `${this.state.turn === "white" ? "White" : "Black"} to move`;

    return output;
  }
}
