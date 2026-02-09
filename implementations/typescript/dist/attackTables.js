"use strict";
/**
 * Pre-calculated attack tables for chess pieces
 * Square indices: 0-63 where 0 = a1, 7 = h1, 56 = a8, 63 = h8
 * Using `as const` for compile-time constant literal types
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.RAY_DIRECTIONS = exports.MANHATTAN_DISTANCE = exports.CHEBYSHEV_DISTANCE = exports.RAY_TABLES = exports.KING_ATTACKS = exports.KNIGHT_ATTACKS = void 0;
exports.getKnightAttacks = getKnightAttacks;
exports.getKingAttacks = getKingAttacks;
exports.getRay = getRay;
exports.getChebyshevDistance = getChebyshevDistance;
exports.getManhattanDistance = getManhattanDistance;
// Helper functions for table generation
function rankOf(square) {
    return Math.floor(square / 8);
}
function fileOf(square) {
    return square % 8;
}
function isValidSquare(square) {
    return square >= 0 && square < 64;
}
// Generate knight attack table
function generateKnightAttacks() {
    const knightOffsets = [-17, -15, -10, -6, 6, 10, 15, 17];
    const attacks = [];
    for (let square = 0; square < 64; square++) {
        const fromFile = fileOf(square);
        const squareAttacks = [];
        for (const offset of knightOffsets) {
            const to = square + offset;
            const toFile = fileOf(to);
            // Validate the move doesn't wrap around the board
            if (isValidSquare(to) && Math.abs(toFile - fromFile) <= 2) {
                squareAttacks.push(to);
            }
        }
        attacks.push(squareAttacks);
    }
    return attacks;
}
// Generate king attack table
function generateKingAttacks() {
    const kingOffsets = [-9, -8, -7, -1, 1, 7, 8, 9];
    const attacks = [];
    for (let square = 0; square < 64; square++) {
        const fromFile = fileOf(square);
        const squareAttacks = [];
        for (const offset of kingOffsets) {
            const to = square + offset;
            const toFile = fileOf(to);
            // Validate the move doesn't wrap around the board
            if (isValidSquare(to) && Math.abs(toFile - fromFile) <= 1) {
                squareAttacks.push(to);
            }
        }
        attacks.push(squareAttacks);
    }
    return attacks;
}
// Generate ray tables for sliding pieces (8 directions × 64 squares)
// Directions: N, NE, E, SE, S, SW, W, NW
function generateRayTables() {
    const directions = [
        { offset: 8, name: "N" }, // North
        { offset: 9, name: "NE" }, // Northeast
        { offset: 1, name: "E" }, // East
        { offset: -7, name: "SE" }, // Southeast
        { offset: -8, name: "S" }, // South
        { offset: -9, name: "SW" }, // Southwest
        { offset: -1, name: "W" }, // West
        { offset: 7, name: "NW" }, // Northwest
    ];
    const rays = [];
    for (const dir of directions) {
        const directionRays = [];
        for (let square = 0; square < 64; square++) {
            const ray = [];
            let current = square;
            const startFile = fileOf(square);
            while (true) {
                const next = current + dir.offset;
                if (!isValidSquare(next))
                    break;
                const currentFile = fileOf(current);
                const nextFile = fileOf(next);
                // Check for board wrapping
                if (dir.offset === 1 || dir.offset === -1) {
                    // Horizontal movement
                    if (Math.abs(nextFile - currentFile) !== 1)
                        break;
                }
                else if (Math.abs(dir.offset) === 7 || Math.abs(dir.offset) === 9) {
                    // Diagonal movement
                    if (Math.abs(nextFile - currentFile) !== 1)
                        break;
                }
                ray.push(next);
                current = next;
            }
            directionRays.push(ray);
        }
        rays.push(directionRays);
    }
    return rays;
}
// Generate Chebyshev distance table (max of rank/file distance)
function generateChebyshevDistances() {
    const distances = [];
    for (let from = 0; from < 64; from++) {
        const fromRank = rankOf(from);
        const fromFile = fileOf(from);
        const squareDistances = [];
        for (let to = 0; to < 64; to++) {
            const toRank = rankOf(to);
            const toFile = fileOf(to);
            const rankDist = Math.abs(toRank - fromRank);
            const fileDist = Math.abs(toFile - fromFile);
            squareDistances.push(Math.max(rankDist, fileDist));
        }
        distances.push(squareDistances);
    }
    return distances;
}
// Generate Manhattan distance table (sum of rank/file distance)
function generateManhattanDistances() {
    const distances = [];
    for (let from = 0; from < 64; from++) {
        const fromRank = rankOf(from);
        const fromFile = fileOf(from);
        const squareDistances = [];
        for (let to = 0; to < 64; to++) {
            const toRank = rankOf(to);
            const toFile = fileOf(to);
            const rankDist = Math.abs(toRank - fromRank);
            const fileDist = Math.abs(toFile - fromFile);
            squareDistances.push(rankDist + fileDist);
        }
        distances.push(squareDistances);
    }
    return distances;
}
// Pre-calculated attack tables
exports.KNIGHT_ATTACKS = generateKnightAttacks();
exports.KING_ATTACKS = generateKingAttacks();
exports.RAY_TABLES = generateRayTables();
exports.CHEBYSHEV_DISTANCE = generateChebyshevDistances();
exports.MANHATTAN_DISTANCE = generateManhattanDistances();
// Ray direction indices for convenient access
exports.RAY_DIRECTIONS = {
    NORTH: 0,
    NORTHEAST: 1,
    EAST: 2,
    SOUTHEAST: 3,
    SOUTH: 4,
    SOUTHWEST: 5,
    WEST: 6,
    NORTHWEST: 7,
};
// Export singleton getter functions for consistency
function getKnightAttacks(square) {
    return exports.KNIGHT_ATTACKS[square];
}
function getKingAttacks(square) {
    return exports.KING_ATTACKS[square];
}
function getRay(square, direction) {
    return exports.RAY_TABLES[direction][square];
}
function getChebyshevDistance(from, to) {
    return exports.CHEBYSHEV_DISTANCE[from][to];
}
function getManhattanDistance(from, to) {
    return exports.MANHATTAN_DISTANCE[from][to];
}
//# sourceMappingURL=attackTables.js.map