"""
Zobrist hashing for board repetition detection
"""

struct ZobristKeys
    pieces::Matrix{UInt64}  # 12 x 64
    side_to_move::UInt64
    castling::Vector{UInt64}  # 4
    en_passant::Vector{UInt64}  # 8
end

function xorshift64(state::UInt64)
    state = state ⊻ (state << 13)
    state = state ⊻ (state >> 7)
    state = state ⊻ (state << 17)
    return state
end

function generate_zobrist_keys()
    pieces = zeros(UInt64, 12, 64)
    castling = zeros(UInt64, 4)
    en_passant = zeros(UInt64, 8)

    state = UInt64(0x123456789abcdef0)

    for p in 1:12
        for s in 1:64
            state = xorshift64(state)
            pieces[p, s] = state
        end
    end

    state = xorshift64(state)
    side_to_move = state

    for i in 1:4
        state = xorshift64(state)
        castling[i] = state
    end

    for i in 1:8
        state = xorshift64(state)
        en_passant[i] = state
    end

    return ZobristKeys(pieces, side_to_move, castling, en_passant)
end

const ZOBRIST_KEYS = generate_zobrist_keys()

function piece_index(piece::Piece)
    base = if piece.type == PAWN
        0
    elseif piece.type == KNIGHT
        1
    elseif piece.type == BISHOP
        2
    elseif piece.type == ROOK
        3
    elseif piece.type == QUEEN
        4
    elseif piece.type == KING
        5
    else
        0
    end

    return piece.color == BLACK ? base + 6 : base
end

function compute_zobrist_hash(pieces::Matrix{Piece}, state::GameState)
    hash = UInt64(0)

    for rank in 0:7
        for file in 0:7
            piece = pieces[file + 1, rank + 1]
            if piece.type != EMPTY
                idx = piece_index(piece)
                square = rank * 8 + file
                hash = hash ⊻ ZOBRIST_KEYS.pieces[idx + 1, square + 1]
            end
        end
    end

    if !state.white_to_move
        hash = hash ⊻ ZOBRIST_KEYS.side_to_move
    end

    if state.white_can_castle_kingside
        hash = hash ⊻ ZOBRIST_KEYS.castling[1]
    end
    if state.white_can_castle_queenside
        hash = hash ⊻ ZOBRIST_KEYS.castling[2]
    end
    if state.black_can_castle_kingside
        hash = hash ⊻ ZOBRIST_KEYS.castling[3]
    end
    if state.black_can_castle_queenside
        hash = hash ⊻ ZOBRIST_KEYS.castling[4]
    end

    if state.en_passant_square != -1
        file = state.en_passant_square % 8
        hash = hash ⊻ ZOBRIST_KEYS.en_passant[file + 1]
    end

    return hash
end
