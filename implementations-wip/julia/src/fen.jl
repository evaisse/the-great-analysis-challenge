"""
FEN (Forsyth-Edwards Notation) parser and serializer
"""

include("board.jl")

function parse_fen!(board::Board, fen::String)
    parts = split(fen, ' ')
    if length(parts) != 6
        return false
    end
    
    try
        # Parse piece placement
        fill!(board.pieces, EMPTY_PIECE)
        ranks = split(parts[1], '/')
        if length(ranks) != 8
            return false
        end
        
        for (rank_idx, rank_str) in enumerate(ranks)
            rank = 9 - rank_idx  # FEN ranks are from 8 to 1
            file = 1
            
            for c in rank_str
                if isdigit(c)
                    # Empty squares
                    empty_count = parse(Int, string(c))
                    file += empty_count
                else
                    # Piece
                    if file > 8
                        return false
                    end
                    piece = char_to_piece(c)
                    board.pieces[file, rank] = piece
                    file += 1
                end
            end
        end
        
        # Parse active color
        board.state.white_to_move = parts[2] == "w"
        
        # Parse castling rights
        castling = parts[3]
        board.state.white_can_castle_kingside = 'K' in castling
        board.state.white_can_castle_queenside = 'Q' in castling
        board.state.black_can_castle_kingside = 'k' in castling
        board.state.black_can_castle_queenside = 'q' in castling
        
        # Parse en passant
        if parts[4] == "-"
            board.state.en_passant_square = -1
        else
            board.state.en_passant_square = algebraic_to_square(parts[4])
        end
        
        # Parse halfmove clock
        board.state.halfmove_clock = parse(Int, parts[5])
        
        # Parse fullmove number
        board.state.fullmove_number = parse(Int, parts[6])
        
        return true
        
    catch
        return false
    end
end

function board_to_fen(board::Board)
    # Piece placement
    fen_parts = String[]
    
    for rank in 8:-1:1
        rank_str = ""
        empty_count = 0
        
        for file in 1:8
            piece = board.pieces[file, rank]
            
            if piece.type == EMPTY
                empty_count += 1
            else
                if empty_count > 0
                    rank_str *= string(empty_count)
                    empty_count = 0
                end
                rank_str *= string(piece_to_char(piece))
            end
        end
        
        if empty_count > 0
            rank_str *= string(empty_count)
        end
        
        push!(fen_parts, rank_str)
    end
    
    piece_placement = join(fen_parts, "/")
    
    # Active color
    active_color = board.state.white_to_move ? "w" : "b"
    
    # Castling rights
    castling = ""
    if board.state.white_can_castle_kingside
        castling *= "K"
    end
    if board.state.white_can_castle_queenside
        castling *= "Q"
    end
    if board.state.black_can_castle_kingside
        castling *= "k"
    end
    if board.state.black_can_castle_queenside
        castling *= "q"
    end
    if castling == ""
        castling = "-"
    end
    
    # En passant
    en_passant = board.state.en_passant_square == -1 ? "-" : square_to_algebraic(board.state.en_passant_square)
    
    # Halfmove clock and fullmove number
    halfmove = string(board.state.halfmove_clock)
    fullmove = string(board.state.fullmove_number)
    
    return "$piece_placement $active_color $castling $en_passant $halfmove $fullmove"
end