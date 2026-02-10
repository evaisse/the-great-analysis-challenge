import { Board } from "./board";
import { Move, Piece, Color, Square } from "./types";
export declare class MoveGenerator {
    private board;
    constructor(board: Board);
    generateAllMoves(color: Color): Move[];
    generatePieceMoves(from: Square, piece: Piece, includeCastling?: boolean): Move[];
    private generatePawnMoves;
    private generateKnightMoves;
    private generateBishopMoves;
    private generateRookMoves;
    private generateQueenMoves;
    private generateKingMoves;
    private generateSlidingMoves;
    isSquareAttacked(square: Square, byColor: Color): boolean;
    isInCheck(color: Color): boolean;
    getLegalMoves(color: Color): Move[];
    isCheckmate(color: Color): boolean;
    isStalemate(color: Color): boolean;
    private isValidSquare;
}
//# sourceMappingURL=moveGenerator.d.ts.map