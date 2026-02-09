export type Square = number;
export declare function createSquare(value: number): Square;
export declare function isValidSquare(value: number): value is Square;
export declare function unsafeSquare(value: number): Square;
export declare function squareToRank(square: Square): Rank;
export declare function squareToFile(square: Square): File;
export declare function squareToAlgebraic(square: Square): string;
export declare function algebraicToSquare(algebraic: string): Square | null;
export declare function squareOffset(square: Square, dx: number, dy: number): Square | null;
export declare function squareDistance(a: Square, b: Square): number;
export type Rank = number;
export type File = number;
export declare function createRank(value: number): Rank;
export declare function createFile(value: number): File;
export declare function rankFileToSquare(rank: Rank, file: File): Square;
//# sourceMappingURL=square.d.ts.map