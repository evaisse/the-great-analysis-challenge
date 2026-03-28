"""
Chess board representation and basic operations
"""


mutable struct Board
    pieces::Matrix{Piece}
    state::GameState
    move_history::Vector{Move}
    position_history::Vector{UInt64}
    zobrist_hash::UInt64
    
    function Board()
        pieces = Matrix{Piece}(undef, 8, 8)
        fill!(pieces, EMPTY_PIECE)
        new(pieces, GameState(), Move[], UInt64[], UInt64(0))
    end
end

function setup_starting_position!(board::Board)
    # Clear board
    fill!(board.pieces, EMPTY_PIECE)
    
    # White pieces
    board.pieces[1, 1] = Piece(ROOK, WHITE)
    board.pieces[2, 1] = Piece(KNIGHT, WHITE)
    board.pieces[3, 1] = Piece(BISHOP, WHITE)
    board.pieces[4, 1] = Piece(QUEEN, WHITE)
    board.pieces[5, 1] = Piece(KING, WHITE)
    board.pieces[6, 1] = Piece(BISHOP, WHITE)
    board.pieces[7, 1] = Piece(KNIGHT, WHITE)
    board.pieces[8, 1] = Piece(ROOK, WHITE)
    
    for i in 1:8
        board.pieces[i, 2] = Piece(PAWN, WHITE)
    end
    
    # Black pieces
    board.pieces[1, 8] = Piece(ROOK, BLACK)
    board.pieces[2, 8] = Piece(KNIGHT, BLACK)
    board.pieces[3, 8] = Piece(BISHOP, BLACK)
    board.pieces[4, 8] = Piece(QUEEN, BLACK)
    board.pieces[5, 8] = Piece(KING, BLACK)
    board.pieces[6, 8] = Piece(BISHOP, BLACK)
    board.pieces[7, 8] = Piece(KNIGHT, BLACK)
    board.pieces[8, 8] = Piece(ROOK, BLACK)
    
    for i in 1:8
        board.pieces[i, 7] = Piece(PAWN, BLACK)
    end
    
    # Reset game state
    board.state = GameState()
    empty!(board.move_history)
    empty!(board.position_history)
    board.zobrist_hash = compute_zobrist_hash(board.pieces, board.state)
end

function get_piece(board::Board, square::Int)
    file, rank = square_to_coords(square)
    return board.pieces[file + 1, rank + 1]
end

function set_piece!(board::Board, square::Int, piece::Piece)
    file, rank = square_to_coords(square)
    board.pieces[file + 1, rank + 1] = piece
end

function is_valid_square(square::Int)
    return square >= 0 && square < 64
end

function is_enemy_piece(board::Board, square::Int, color::Color)
    if !is_valid_square(square)
        return false
    end
    piece = get_piece(board, square)
    return piece.type != EMPTY && piece.color != color
end

function is_friendly_piece(board::Board, square::Int, color::Color)
    if !is_valid_square(square)
        return false
    end
    piece = get_piece(board, square)
    return piece.type != EMPTY && piece.color == color
end

function is_empty_square(board::Board, square::Int)
    if !is_valid_square(square)
        return false
    end
    return get_piece(board, square).type == EMPTY
end

function find_king(board::Board, color::Color)
    for square in 0:63
        piece = get_piece(board, square)
        if piece.type == KING && piece.color == color
            return square
        end
    end
    return -1
end

function is_square_attacked(board::Board, square::Int, by_color::Color)
    # Check pawn attacks
    pawn_offsets = by_color == WHITE ? (-9, -7) : (7, 9)
    for offset in pawn_offsets
        attack_square = square + offset
        if is_valid_square(attack_square) && abs((square % 8) - (attack_square % 8)) == 1
            piece = get_piece(board, attack_square)
            if piece.type == PAWN && piece.color == by_color
                return true
            end
        end
    end
    
    # Check knight attacks
    for attack_square in knight_attacks(square)
        piece = get_piece(board, attack_square)
        if piece.type == KNIGHT && piece.color == by_color
            return true
        end
    end
    
    # Check diagonal attacks (bishop/queen)
    for ray in bishop_rays(square)
        for attack_square in ray
            piece = get_piece(board, attack_square)
            if piece.type != EMPTY
                if piece.color == by_color && (piece.type == BISHOP || piece.type == QUEEN)
                    return true
                end
                break
            end
        end
    end
    
    # Check straight attacks (rook/queen)
    for ray in rook_rays(square)
        for attack_square in ray
            piece = get_piece(board, attack_square)
            if piece.type != EMPTY
                if piece.color == by_color && (piece.type == ROOK || piece.type == QUEEN)
                    return true
                end
                break
            end
        end
    end
    
    # Check king attacks
    for attack_square in king_attacks(square)
        piece = get_piece(board, attack_square)
        if piece.type == KING && piece.color == by_color
            return true
        end
    end
    
    return false
end

function is_in_check(board::Board, color::Color)
    king_square = find_king(board, color)
    if king_square == -1
        return false
    end
    return is_square_attacked(board, king_square, color == WHITE ? BLACK : WHITE)
end

function Base.show(io::IO, board::Board)
    println(io, "  a b c d e f g h")
    for rank in 8:-1:1
        print(io, rank, " ")
        for file in 1:8
            piece = board.pieces[file, rank]
            print(io, piece_to_char(piece), " ")
        end
        println(io, rank)
    end
    println(io, "  a b c d e f g h")
    println(io)
    println(io, board.state.white_to_move ? "White to move" : "Black to move")
end
