const KNIGHT_DELTAS = [
    [-1, -2],
    [1, -2],
    [-2, -1],
    [2, -1],
    [-2, 1],
    [2, 1],
    [-1, 2],
    [1, 2],
];

const KING_DELTAS = [
    [-1, -1],
    [0, -1],
    [1, -1],
    [-1, 0],
    [1, 0],
    [-1, 1],
    [0, 1],
    [1, 1],
];

const BISHOP_DELTAS = [
    [-1, -1],
    [1, -1],
    [-1, 1],
    [1, 1],
];

const ROOK_DELTAS = [
    [0, -1],
    [-1, 0],
    [1, 0],
    [0, 1],
];

const QUEEN_DELTAS = [...BISHOP_DELTAS, ...ROOK_DELTAS];

function buildAttackTable(deltas) {
    return Object.freeze(
        Array.from({ length: 64 }, (_, square) => {
            const file = square % 8;
            const rank = Math.floor(square / 8);
            const attacks = [];

            for (const [df, dr] of deltas) {
                const targetFile = file + df;
                const targetRank = rank + dr;

                if (targetFile >= 0 && targetFile < 8 && targetRank >= 0 && targetRank < 8) {
                    attacks.push(targetRank * 8 + targetFile);
                }
            }

            return Object.freeze(attacks);
        })
    );
}

function buildRayTable(deltas) {
    return Object.freeze(
        Array.from({ length: 64 }, (_, square) => {
            const file = square % 8;
            const rank = Math.floor(square / 8);

            return Object.freeze(
                deltas.map(([df, dr]) => {
                    const ray = [];
                    let targetFile = file + df;
                    let targetRank = rank + dr;

                    while (targetFile >= 0 && targetFile < 8 && targetRank >= 0 && targetRank < 8) {
                        ray.push(targetRank * 8 + targetFile);
                        targetFile += df;
                        targetRank += dr;
                    }

                    return Object.freeze(ray);
                })
            );
        })
    );
}

function buildDistanceTable(metric) {
    return Object.freeze(
        Array.from({ length: 64 }, (_, from) => {
            const fromFile = from % 8;
            const fromRank = Math.floor(from / 8);

            return Object.freeze(
                Array.from({ length: 64 }, (_, to) => {
                    const fileDistance = Math.abs(fromFile - (to % 8));
                    const rankDistance = Math.abs(fromRank - Math.floor(to / 8));
                    return metric(fileDistance, rankDistance);
                })
            );
        })
    );
}

export const KNIGHT_ATTACKS = buildAttackTable(KNIGHT_DELTAS);
export const KING_ATTACKS = buildAttackTable(KING_DELTAS);

export const SLIDING_RAYS = Object.freeze({
    b: buildRayTable(BISHOP_DELTAS),
    r: buildRayTable(ROOK_DELTAS),
    q: buildRayTable(QUEEN_DELTAS),
});

export const CHEBYSHEV_DISTANCE = buildDistanceTable((fileDistance, rankDistance) => Math.max(fileDistance, rankDistance));
export const MANHATTAN_DISTANCE = buildDistanceTable((fileDistance, rankDistance) => fileDistance + rankDistance);
