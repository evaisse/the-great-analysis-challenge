/**
 * Pre-calculated attack tables for chess pieces
 * Square indices: 0-63 where 0 = a1, 7 = h1, 56 = a8, 63 = h8
 * Using `as const` for compile-time constant literal types
 */
export declare const KNIGHT_ATTACKS: readonly (readonly number[])[];
export declare const KING_ATTACKS: readonly (readonly number[])[];
export declare const RAY_TABLES: readonly (readonly (readonly number[])[])[];
export declare const CHEBYSHEV_DISTANCE: readonly (readonly number[])[];
export declare const MANHATTAN_DISTANCE: readonly (readonly number[])[];
export declare const RAY_DIRECTIONS: {
    readonly NORTH: 0;
    readonly NORTHEAST: 1;
    readonly EAST: 2;
    readonly SOUTHEAST: 3;
    readonly SOUTH: 4;
    readonly SOUTHWEST: 5;
    readonly WEST: 6;
    readonly NORTHWEST: 7;
};
export declare function getKnightAttacks(square: number): readonly number[];
export declare function getKingAttacks(square: number): readonly number[];
export declare function getRay(square: number, direction: number): readonly number[];
export declare function getChebyshevDistance(from: number, to: number): number;
export declare function getManhattanDistance(from: number, to: number): number;
//# sourceMappingURL=attackTables.d.ts.map