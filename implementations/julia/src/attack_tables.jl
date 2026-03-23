"""
Precomputed attack and distance lookup tables.
"""

const KNIGHT_DELTAS = [
    (-1, -2), (1, -2),
    (-2, -1), (2, -1),
    (-2, 1), (2, 1),
    (-1, 2), (1, 2),
]

const KING_DELTAS = [
    (-1, -1), (0, -1), (1, -1),
    (-1, 0),            (1, 0),
    (-1, 1),  (0, 1),  (1, 1),
]

const BISHOP_DELTAS = [(-1, -1), (1, -1), (-1, 1), (1, 1)]
const ROOK_DELTAS = [(0, -1), (-1, 0), (1, 0), (0, 1)]
const QUEEN_DELTAS = vcat(BISHOP_DELTAS, ROOK_DELTAS)

function build_attack_table(deltas)
    table = Vector{Vector{Int}}(undef, 64)
    for square in 0:63
        file = square % 8
        rank = square ÷ 8
        attacks = Int[]
        for (df, dr) in deltas
            target_file = file + df
            target_rank = rank + dr
            if 0 <= target_file < 8 && 0 <= target_rank < 8
                push!(attacks, target_rank * 8 + target_file)
            end
        end
        table[square + 1] = attacks
    end
    return table
end

function build_ray_table(deltas)
    table = Vector{Vector{Vector{Int}}}(undef, 64)
    for square in 0:63
        file = square % 8
        rank = square ÷ 8
        rays = Vector{Vector{Int}}()
        for (df, dr) in deltas
            ray = Int[]
            target_file = file + df
            target_rank = rank + dr
            while 0 <= target_file < 8 && 0 <= target_rank < 8
                push!(ray, target_rank * 8 + target_file)
                target_file += df
                target_rank += dr
            end
            push!(rays, ray)
        end
        table[square + 1] = rays
    end
    return table
end

function build_distance_table(metric)
    table = Matrix{Int}(undef, 64, 64)
    for from in 0:63
        from_file = from % 8
        from_rank = from ÷ 8
        for to in 0:63
            file_distance = abs(from_file - (to % 8))
            rank_distance = abs(from_rank - (to ÷ 8))
            table[from + 1, to + 1] = metric(file_distance, rank_distance)
        end
    end
    return table
end

const KNIGHT_ATTACKS = build_attack_table(KNIGHT_DELTAS)
const KING_ATTACKS = build_attack_table(KING_DELTAS)
const BISHOP_RAYS = build_ray_table(BISHOP_DELTAS)
const ROOK_RAYS = build_ray_table(ROOK_DELTAS)
const QUEEN_RAYS = build_ray_table(QUEEN_DELTAS)
const CHEBYSHEV_DISTANCE = build_distance_table(max)
const MANHATTAN_DISTANCE = build_distance_table(+)

knight_attacks(square::Int) = KNIGHT_ATTACKS[square + 1]
king_attacks(square::Int) = KING_ATTACKS[square + 1]
bishop_rays(square::Int) = BISHOP_RAYS[square + 1]
rook_rays(square::Int) = ROOK_RAYS[square + 1]
queen_rays(square::Int) = QUEEN_RAYS[square + 1]
chebyshev_distance(from::Int, to::Int) = CHEBYSHEV_DISTANCE[from + 1, to + 1]
manhattan_distance(from::Int, to::Int) = MANHATTAN_DISTANCE[from + 1, to + 1]
