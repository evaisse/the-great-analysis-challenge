import { Piece, Color, Square, Move, CastlingRights, GameState } from "./types";
export declare class Board {
    private state;
    constructor();
    private createInitialState;
    reset(): void;
    getState(): GameState;
    setState(state: GameState): void;
    isDraw(): boolean;
    isDrawByRepetition(): boolean;
    isDrawByFiftyMoveRule(): boolean;
    getHash(): bigint;
    getDrawInfo(): string | null;
    getPiece(square: Square): Piece | null;
    setPiece(square: Square, piece: Piece | null): void;
    getTurn(): Color;
    setTurn(color: Color): void;
    getCastlingRights(): CastlingRights;
    setCastlingRights(rights: CastlingRights): void;
    getEnPassantTarget(): Square | null;
    setEnPassantTarget(square: Square | null): void;
    squareToAlgebraic(square: Square): string;
    algebraicToSquare(algebraic: string): Square;
    makeMove(move: Move): void;
    undoMove(): Move | null;
    display(): string;
}
//# sourceMappingURL=board.d.ts.map