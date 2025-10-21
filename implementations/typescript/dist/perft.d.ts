import { Board } from './board';
import { MoveGenerator } from './moveGenerator';
export declare class Perft {
    private board;
    private moveGenerator;
    constructor(board: Board, moveGenerator: MoveGenerator);
    perft(depth: number): number;
    perftDivide(depth: number): Map<string, number>;
}
//# sourceMappingURL=perft.d.ts.map