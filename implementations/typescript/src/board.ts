import {
  Piece,
  Color,
  SideToMove,
  Square,
  LegalMove,
  CastlingRights,
  GameState,
  SQUARES,
  nextTurn,
  square,
  squareFromAlgebraic,
  squareToAlgebraic,
} from "./types";
import { zobrist } from "./zobrist";
import * as drawDetection from "./drawDetection";

export class Board {
  private state: GameState<SideToMove>;

  constructor() {
    this.state = this.createInitialState();
  }

  private createInitialState(): GameState<"white"> {
    const board: (Piece | null)[] = new Array(64).fill(null);

    const pieces: [Square, Piece][] = [
      [SQUARES[0], { type: "R", color: "white" }],
      [SQUARES[1], { type: "N", color: "white" }],
      [SQUARES[2], { type: "B", color: "white" }],
      [SQUARES[3], { type: "Q", color: "white" }],
      [SQUARES[4], { type: "K", color: "white" }],
      [SQUARES[5], { type: "B", color: "white" }],
      [SQUARES[6], { type: "N", color: "white" }],
      [SQUARES[7], { type: "R", color: "white" }],

      [SQUARES[56], { type: "R", color: "black" }],
      [SQUARES[57], { type: "N", color: "black" }],
      [SQUARES[58], { type: "B", color: "black" }],
      [SQUARES[59], { type: "Q", color: "black" }],
      [SQUARES[60], { type: "K", color: "black" }],
      [SQUARES[61], { type: "B", color: "black" }],
      [SQUARES[62], { type: "N", color: "black" }],
      [SQUARES[63], { type: "R", color: "black" }],
    ];

    for (let i = 8; i < 16; i++) {
      pieces.push([SQUARES[i], { type: "P", color: "white" }]);
    }
    for (let i = 48; i < 56; i++) {
      pieces.push([SQUARES[i], { type: "P", color: "black" }]);
    }

    for (const [square, piece] of pieces) {
      board[square] = piece;
    }

    const state: GameState<"white"> = {
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
      zobristHash: 0n,
      positionHistory: [],
      irreversibleHistory: [],
    };
    state.zobristHash = zobrist.computeHash(state);
    return state;
  }

  public reset(): void {
    this.state = this.createInitialState();
  }

  public getState(): GameState<SideToMove> {
    return { ...this.state };
  }

  public setState(state: GameState<SideToMove>): void {
    this.state = { ...state };
  }

  public isDraw(): boolean {
    return (
      drawDetection.isDrawByRepetition(this.state) ||
      drawDetection.isDrawByFiftyMoves(this.state)
    );
  }

  public isDrawByRepetition(): boolean {
    return drawDetection.isDrawByRepetition(this.state);
  }

  public isDrawByFiftyMoveRule(): boolean {
    return drawDetection.isDrawByFiftyMoves(this.state);
  }

  public getHash(): bigint {
    return this.state.zobristHash;
  }

  public getDrawInfo(): string | null {
    if (this.isDrawByFiftyMoveRule()) return "50-move rule";
    if (this.isDrawByRepetition()) return "repetition";
    return null;
  }

  public getPiece(square: Square): Piece | null {
    return this.state.board[square];
  }

  public setPiece(square: Square, piece: Piece | null): void {
    this.state.board[square] = piece;
  }

  public getTurn(): SideToMove {
    return this.state.turn;
  }

  public setTurn(color: SideToMove): void {
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
    return squareToAlgebraic(square);
  }

  public algebraicToSquare(algebraic: string): Square {
    return squareFromAlgebraic(algebraic);
  }

  public makeMove(move: LegalMove): void {
    const piece = this.getPiece(move.from);
    if (!piece) return;

    // Save irreversible state
    this.state.irreversibleHistory.push({
      castlingRights: { ...this.state.castlingRights },
      enPassantTarget: this.state.enPassantTarget,
      halfmoveClock: this.state.halfmoveClock,
      zobristHash: this.state.zobristHash,
    });
    this.state.positionHistory.push(this.state.zobristHash);

    let hash = this.state.zobristHash;

    // 1. Remove moving piece from source
    hash ^= zobrist.pieces[zobrist.getPieceIndex(piece)][move.from];

    // 2. Handle capture
    if (move.captured) {
      const capturedColor = piece.color === "white" ? "black" : "white";
      const capturedPiece: Piece = { type: move.captured, color: capturedColor };
      if (move.enPassant) {
        const capturedSq = square(
          Number(move.to) + (piece.color === "white" ? -8 : 8),
        );
        hash ^=
          zobrist.pieces[zobrist.getPieceIndex(capturedPiece)][capturedSq];
        this.setPiece(capturedSq, null);
      } else {
        hash ^= zobrist.pieces[zobrist.getPieceIndex(capturedPiece)][move.to];
        // Dest square will be overwritten below
      }
      this.state.halfmoveClock = 0;
    } else if (piece.type === "P") {
      this.state.halfmoveClock = 0;
    } else {
      this.state.halfmoveClock++;
    }

    // 3. Place piece at destination (handling promotion)
    if (move.promotion) {
      const promoPiece: Piece = { type: move.promotion, color: piece.color };
      hash ^= zobrist.pieces[zobrist.getPieceIndex(promoPiece)][move.to];
      this.setPiece(move.to, promoPiece);
    } else {
      hash ^= zobrist.pieces[zobrist.getPieceIndex(piece)][move.to];
      this.setPiece(move.to, piece);
    }
    this.setPiece(move.from, null);

    // 4. Handle castling rook
    if (move.castling) {
      const rank = piece.color === "white" ? 0 : 7;
      let rookFrom: Square;
      let rookTo: Square;
      if (move.castling === "K" || move.castling === "k") {
        rookFrom = square(rank * 8 + 7);
        rookTo = square(rank * 8 + 5);
      } else {
        rookFrom = square(rank * 8);
        rookTo = square(rank * 8 + 3);
      }
      const rook = this.getPiece(rookFrom);
      if (rook) {
        hash ^= zobrist.pieces[zobrist.getPieceIndex(rook)][rookFrom];
        hash ^= zobrist.pieces[zobrist.getPieceIndex(rook)][rookTo];
        this.setPiece(rookTo, rook);
        this.setPiece(rookFrom, null);
      }
    }

    // 5. Update castling rights in hash
    if (this.state.castlingRights.whiteKingside) hash ^= zobrist.castling[0];
    if (this.state.castlingRights.whiteQueenside) hash ^= zobrist.castling[1];
    if (this.state.castlingRights.blackKingside) hash ^= zobrist.castling[2];
    if (this.state.castlingRights.blackQueenside) hash ^= zobrist.castling[3];

    if (piece.type === "K") {
      if (piece.color === "white") {
        this.state.castlingRights.whiteKingside = false;
        this.state.castlingRights.whiteQueenside = false;
      } else {
        this.state.castlingRights.blackKingside = false;
        this.state.castlingRights.blackQueenside = false;
      }
    }

    if (move.from === SQUARES[0] || move.to === SQUARES[0])
      this.state.castlingRights.whiteQueenside = false;
    if (move.from === SQUARES[7] || move.to === SQUARES[7])
      this.state.castlingRights.whiteKingside = false;
    if (move.from === SQUARES[56] || move.to === SQUARES[56])
      this.state.castlingRights.blackQueenside = false;
    if (move.from === SQUARES[63] || move.to === SQUARES[63])
      this.state.castlingRights.blackKingside = false;

    if (this.state.castlingRights.whiteKingside) hash ^= zobrist.castling[0];
    if (this.state.castlingRights.whiteQueenside) hash ^= zobrist.castling[1];
    if (this.state.castlingRights.blackKingside) hash ^= zobrist.castling[2];
    if (this.state.castlingRights.blackQueenside) hash ^= zobrist.castling[3];

    // 6. Update en passant target in hash
    if (this.state.enPassantTarget !== null) {
      hash ^= zobrist.enPassant[this.state.enPassantTarget % 8];
    }

    if (piece.type === "P" && Math.abs(move.to - move.from) === 16) {
      const enPassantSquare = square((Number(move.from) + Number(move.to)) / 2);
      this.state.enPassantTarget = enPassantSquare;
      hash ^= zobrist.enPassant[enPassantSquare % 8];
    } else {
      this.state.enPassantTarget = null;
    }

    // 7. Update side to move and fullmove
    hash ^= zobrist.sideToMove;
    if (piece.color === "black") {
      this.state.fullmoveNumber++;
    }

    this.state.zobristHash = hash;
    this.setTurn(nextTurn(piece.color));
    this.state.moveHistory.push(move);
  }

  public undoMove(): LegalMove | null {
    const move = this.state.moveHistory.pop();
    if (!move) return null;

    const oldState = this.state.irreversibleHistory.pop();
    if (!oldState) throw new Error("No irreversible history for undo");
    this.state.positionHistory.pop();

    const piece = this.getPiece(move.to);
    if (!piece) return null;

    // Restore irreversible state
    this.state.castlingRights = { ...oldState.castlingRights };
    this.state.enPassantTarget = oldState.enPassantTarget;
    this.state.halfmoveClock = oldState.halfmoveClock;
    this.state.zobristHash = oldState.zobristHash;

    if (move.promotion) {
      this.setPiece(move.from, { type: "P", color: piece.color });
    } else {
      this.setPiece(move.from, piece);
    }

    if (move.captured) {
      const capturedColor = piece.color === "white" ? "black" : "white";
      const capturedPiece: Piece = { type: move.captured, color: capturedColor };
      if (move.enPassant) {
        const capturedPawnSquare = square(
          Number(move.to) + (piece.color === "white" ? -8 : 8),
        );
        this.setPiece(capturedPawnSquare, capturedPiece);
        this.setPiece(move.to, null);
      } else {
        this.setPiece(move.to, capturedPiece);
      }
    } else {
      this.setPiece(move.to, null);
    }

    if (move.castling) {
      const rank = piece.color === "white" ? 0 : 7;
      let rookFrom: Square;
      let rookTo: Square;
      if (move.castling === "K" || move.castling === "k") {
        rookFrom = square(rank * 8 + 5);
        rookTo = square(rank * 8 + 7);
      } else {
        rookFrom = square(rank * 8 + 3);
        rookTo = square(rank * 8);
      }
      const rook = this.getPiece(rookFrom);
      if (rook) {
        this.setPiece(rookTo, rook);
        this.setPiece(rookFrom, null);
      }
    }

    if (piece.color === "black") {
      this.state.fullmoveNumber--;
    }
    this.setTurn(piece.color);

    return move;
  }

  public display(): string {
    let output = "  a b c d e f g h\n";

    for (let rank = 7; rank >= 0; rank--) {
      output += `${rank + 1} `;
      for (let file = 0; file < 8; file++) {
        const square = SQUARES[rank * 8 + file];
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
