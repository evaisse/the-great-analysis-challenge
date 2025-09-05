import { Board } from './board';
import { Piece, Color, CastlingRights, Square } from './types';

export class FenParser {
  private board: Board;

  constructor(board: Board) {
    this.board = board;
  }

  public parseFen(fen: string): void {
    const parts = fen.split(' ');
    if (parts.length < 4) {
      throw new Error('ERROR: Invalid FEN string');
    }

    const [pieces, turn, castling, enPassant, halfmove = '0', fullmove = '1'] = parts;

    for (let i = 0; i < 64; i++) {
      this.board.setPiece(i, null);
    }

    let square = 56;
    for (const char of pieces) {
      if (char === '/') {
        square -= 16;
      } else if ('12345678'.includes(char)) {
        square += parseInt(char);
      } else {
        const piece = this.charToPiece(char);
        if (piece) {
          this.board.setPiece(square, piece);
          square++;
        }
      }
    }

    this.board.setTurn(turn === 'w' ? 'white' : 'black');

    const rights: CastlingRights = {
      whiteKingside: castling.includes('K'),
      whiteQueenside: castling.includes('Q'),
      blackKingside: castling.includes('k'),
      blackQueenside: castling.includes('q')
    };
    this.board.setCastlingRights(rights);

    if (enPassant !== '-') {
      try {
        const epSquare = this.board.algebraicToSquare(enPassant);
        this.board.setEnPassantTarget(epSquare);
      } catch {
        this.board.setEnPassantTarget(null);
      }
    } else {
      this.board.setEnPassantTarget(null);
    }

    const state = this.board.getState();
    state.halfmoveClock = parseInt(halfmove) || 0;
    state.fullmoveNumber = parseInt(fullmove) || 1;
    this.board.setState(state);
  }

  public exportFen(): string {
    const pieces = this.getPiecesString();
    const turn = this.board.getTurn() === 'white' ? 'w' : 'b';
    const castling = this.getCastlingString();
    const enPassant = this.getEnPassantString();
    const state = this.board.getState();
    
    return `${pieces} ${turn} ${castling} ${enPassant} ${state.halfmoveClock} ${state.fullmoveNumber}`;
  }

  private getPiecesString(): string {
    let result = '';
    
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
        result += '/';
      }
    }
    
    return result;
  }

  private getCastlingString(): string {
    const rights = this.board.getCastlingRights();
    let result = '';
    
    if (rights.whiteKingside) result += 'K';
    if (rights.whiteQueenside) result += 'Q';
    if (rights.blackKingside) result += 'k';
    if (rights.blackQueenside) result += 'q';
    
    return result || '-';
  }

  private getEnPassantString(): string {
    const target = this.board.getEnPassantTarget();
    if (target === null) {
      return '-';
    }
    return this.board.squareToAlgebraic(target);
  }

  private charToPiece(char: string): Piece | null {
    const isWhite = char === char.toUpperCase();
    const type = char.toUpperCase();
    
    switch (type) {
      case 'P': return { type: 'P', color: isWhite ? 'white' : 'black' };
      case 'N': return { type: 'N', color: isWhite ? 'white' : 'black' };
      case 'B': return { type: 'B', color: isWhite ? 'white' : 'black' };
      case 'R': return { type: 'R', color: isWhite ? 'white' : 'black' };
      case 'Q': return { type: 'Q', color: isWhite ? 'white' : 'black' };
      case 'K': return { type: 'K', color: isWhite ? 'white' : 'black' };
      default: return null;
    }
  }

  private pieceToChar(piece: Piece): string {
    const char = piece.type;
    return piece.color === 'white' ? char : char.toLowerCase();
  }
}