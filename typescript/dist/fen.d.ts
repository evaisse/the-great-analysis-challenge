import { Board } from './board';
export declare class FenParser {
    private board;
    constructor(board: Board);
    parseFen(fen: string): void;
    exportFen(): string;
    private getPiecesString;
    private getCastlingString;
    private getEnPassantString;
    private charToPiece;
    private pieceToChar;
}
//# sourceMappingURL=fen.d.ts.map