"""
Chess piece types and utilities
"""

# Piece types
@enum PieceType begin
    EMPTY = 0
    PAWN = 1
    KNIGHT = 2
    BISHOP = 3
    ROOK = 4
    QUEEN = 5
    KING = 6
end

# Colors
@enum Color begin
    WHITE = 0
    BLACK = 1
end

# Piece representation: combines type and color
struct Piece
    type::PieceType
    color::Color
end

# Empty piece
const EMPTY_PIECE = Piece(EMPTY, WHITE)

# Move representation with state backup
mutable struct Move
    from::Int
    to::Int
    piece::Piece
    captured::Piece
    promotion::PieceType
    is_castle::Bool
    is_en_passant::Bool
    
    # Backup of game state before move
    prev_en_passant::Int
    prev_white_can_castle_kingside::Bool
    prev_white_can_castle_queenside::Bool
    prev_black_can_castle_kingside::Bool
    prev_black_can_castle_queenside::Bool
    prev_halfmove_clock::Int
    prev_fullmove_number::Int
    
    Move(from, to) = new(from, to, EMPTY_PIECE, EMPTY_PIECE, EMPTY, false, false, -1, true, true, true, true, 0, 1)
    Move(from, to, piece, captured) = new(from, to, piece, captured, EMPTY, false, false, -1, true, true, true, true, 0, 1)
end

# Game state
mutable struct GameState
    white_to_move::Bool
    white_can_castle_kingside::Bool
    white_can_castle_queenside::Bool
    black_can_castle_kingside::Bool
    black_can_castle_queenside::Bool
    en_passant_square::Int
    halfmove_clock::Int
    fullmove_number::Int
    
    GameState() = new(true, true, true, true, true, -1, 0, 1)
end

# Board coordinates
square_to_coords(square) = (square % 8, square ÷ 8)
coords_to_square(file, rank) = rank * 8 + file
algebraic_to_square(alg) = coords_to_square(Int(alg[1]) - Int('a'), Int(alg[2]) - Int('1'))
square_to_algebraic(square) = string(Char(Int('a') + square % 8), Char(Int('1') + square ÷ 8))

# Piece symbols
function piece_to_char(piece::Piece)
    if piece.type == EMPTY
        return '.'
    end
    
    symbol = if piece.type == PAWN
        'P'
    elseif piece.type == KNIGHT
        'N'
    elseif piece.type == BISHOP
        'B'
    elseif piece.type == ROOK
        'R'
    elseif piece.type == QUEEN
        'Q'
    elseif piece.type == KING
        'K'
    else
        '?'
    end
    
    return piece.color == WHITE ? symbol : lowercase(symbol)
end

function char_to_piece(c::Char)
    color = isuppercase(c) ? WHITE : BLACK
    piece_type = if lowercase(c) == 'p'
        PAWN
    elseif lowercase(c) == 'n'
        KNIGHT
    elseif lowercase(c) == 'b'
        BISHOP
    elseif lowercase(c) == 'r'
        ROOK
    elseif lowercase(c) == 'q'
        QUEEN
    elseif lowercase(c) == 'k'
        KING
    else
        EMPTY
    end
    return Piece(piece_type, color)
end