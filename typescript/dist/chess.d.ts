export declare class ChessEngine {
    private board;
    private moveGenerator;
    private fenParser;
    private ai;
    private perft;
    private rl;
    constructor();
    start(): void;
    private processCommand;
    private handleMove;
    private handleUndo;
    private handleNew;
    private handleAI;
    private handleFen;
    private handleExport;
    private handleEval;
    private evaluatePosition;
    private handlePerft;
    private handleHelp;
    private checkGameEnd;
}
//# sourceMappingURL=chess.d.ts.map