import { ZobristKey } from "./zobrist";
import { Square } from "./types";
export declare enum BoundType {
    Exact = "Exact",
    LowerBound = "LowerBound",
    UpperBound = "UpperBound"
}
export interface TTEntry {
    key: ZobristKey;
    depth: number;
    score: number;
    bound: BoundType;
    bestMove: number | null;
    age: number;
}
export declare class TranspositionTable {
    private entries;
    private age;
    private size;
    constructor(sizeMB?: number);
    private nextPowerOfTwo;
    private emptyEntry;
    private index;
    probe(key: ZobristKey): TTEntry | null;
    store(key: ZobristKey, depth: number, score: number, bound: BoundType, bestMove: number | null): void;
    clear(): void;
    newSearch(): void;
    getSize(): number;
    fillPercentage(): number;
}
export declare function encodeMove(from: Square, to: Square): number;
export declare function decodeMove(encoded: number): [Square, Square];
//# sourceMappingURL=transpositionTable.d.ts.map