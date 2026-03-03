"""
Chess move generation and validation
"""


function generate_pawn_moves(board::Board, square::Int, moves::Vector{Move})
    piece = get_piece(board, square)
    color = piece.color
    file, rank = square_to_coords(square)
    
    direction = color == WHITE ? 1 : -1
    start_rank = color == WHITE ? 1 : 6
    promotion_rank = color == WHITE ? 7 : 0
    
    # Forward move
    forward_square = square + direction * 8
    if is_valid_square(forward_square) && is_empty_square(board, forward_square)
        if rank + direction == promotion_rank
            # Promotion
            for promotion_piece in [QUEEN, ROOK, BISHOP, KNIGHT]
                move = Move(square, forward_square, piece, EMPTY_PIECE)
                move.promotion = promotion_piece
                push!(moves, move)
            end
        else
            push!(moves, Move(square, forward_square, piece, EMPTY_PIECE))
        end
        
        # Double forward from starting position
        if rank == start_rank
            double_forward = square + direction * 16
            if is_valid_square(double_forward) && is_empty_square(board, double_forward)
                push!(moves, Move(square, double_forward, piece, EMPTY_PIECE))
            end
        end
    end
    
    # Captures
    for df in [-1, 1]
        capture_square = square + direction * 8 + df
        if is_valid_square(capture_square) && abs((square % 8) - (capture_square % 8)) == 1
            if is_enemy_piece(board, capture_square, color)
                captured = get_piece(board, capture_square)
                if rank + direction == promotion_rank
                    # Promotion with capture
                    for promotion_piece in [QUEEN, ROOK, BISHOP, KNIGHT]
                        move = Move(square, capture_square, piece, captured)
                        move.promotion = promotion_piece
                        push!(moves, move)
                    end
                else
                    push!(moves, Move(square, capture_square, piece, captured))
                end
            elseif capture_square == board.state.en_passant_square
                # En passant
                captured_pawn_square = capture_square - direction * 8
                captured = get_piece(board, captured_pawn_square)
                move = Move(square, capture_square, piece, captured)
                move.is_en_passant = true
                push!(moves, move)
            end
        end
    end
end

function generate_knight_moves(board::Board, square::Int, moves::Vector{Move})
    piece = get_piece(board, square)
    color = piece.color
    
    knight_moves = [-17, -15, -10, -6, 6, 10, 15, 17]
    for move_offset in knight_moves
        to_square = square + move_offset
        if is_valid_square(to_square)
            file_diff = abs((square % 8) - (to_square % 8))
            rank_diff = abs((square ÷ 8) - (to_square ÷ 8))
            if (file_diff == 2 && rank_diff == 1) || (file_diff == 1 && rank_diff == 2)
                if is_empty_square(board, to_square)
                    push!(moves, Move(square, to_square, piece, EMPTY_PIECE))
                elseif is_enemy_piece(board, to_square, color)
                    captured = get_piece(board, to_square)
                    push!(moves, Move(square, to_square, piece, captured))
                end
            end
        end
    end
end

function generate_sliding_moves(board::Board, square::Int, moves::Vector{Move}, directions::Vector{Int})
    piece = get_piece(board, square)
    color = piece.color
    
    for direction in directions
        current = square + direction
        while is_valid_square(current)
            # Check board boundaries for horizontal moves
            if direction == -1 || direction == 1
                if (square ÷ 8) != (current ÷ 8)
                    break
                end
            end
            
            # Check diagonal moves
            if abs(direction) == 7 || abs(direction) == 9
                file_diff = abs((square % 8) - (current % 8))
                rank_diff = abs((square ÷ 8) - (current ÷ 8))
                if file_diff != rank_diff
                    break
                end
            end
            
            if is_empty_square(board, current)
                push!(moves, Move(square, current, piece, EMPTY_PIECE))
            else
                if is_enemy_piece(board, current, color)
                    captured = get_piece(board, current)
                    push!(moves, Move(square, current, piece, captured))
                end
                break
            end
            current += direction
        end
    end
end

function generate_king_moves(board::Board, square::Int, moves::Vector{Move})
    piece = get_piece(board, square)
    color = piece.color
    
    # Regular king moves
    for dr in -1:1, df in -1:1
        if dr == 0 && df == 0
            continue
        end
        to_square = square + dr * 8 + df
        if is_valid_square(to_square)
            file_diff = abs((square % 8) - (to_square % 8))
            rank_diff = abs((square ÷ 8) - (to_square ÷ 8))
            if file_diff <= 1 && rank_diff <= 1
                if is_empty_square(board, to_square)
                    push!(moves, Move(square, to_square, piece, EMPTY_PIECE))
                elseif is_enemy_piece(board, to_square, color)
                    captured = get_piece(board, to_square)
                    push!(moves, Move(square, to_square, piece, captured))
                end
            end
        end
    end
    
    # Castling
    if !is_in_check(board, color)
        if color == WHITE
            if board.state.white_can_castle_kingside && 
               get_piece(board, 7).type == ROOK && get_piece(board, 7).color == WHITE &&
               is_empty_square(board, 5) && is_empty_square(board, 6) &&
               !is_square_attacked(board, 5, BLACK) && !is_square_attacked(board, 6, BLACK)
                move = Move(square, 6, piece, EMPTY_PIECE)
                move.is_castle = true
                push!(moves, move)
            end
            if board.state.white_can_castle_queenside &&
               get_piece(board, 0).type == ROOK && get_piece(board, 0).color == WHITE &&
               is_empty_square(board, 1) && is_empty_square(board, 2) && is_empty_square(board, 3) &&
               !is_square_attacked(board, 2, BLACK) && !is_square_attacked(board, 3, BLACK)
                move = Move(square, 2, piece, EMPTY_PIECE)
                move.is_castle = true
                push!(moves, move)
            end
        else
            if board.state.black_can_castle_kingside &&
               get_piece(board, 63).type == ROOK && get_piece(board, 63).color == BLACK &&
               is_empty_square(board, 61) && is_empty_square(board, 62) &&
               !is_square_attacked(board, 61, WHITE) && !is_square_attacked(board, 62, WHITE)
                move = Move(square, 62, piece, EMPTY_PIECE)
                move.is_castle = true
                push!(moves, move)
            end
            if board.state.black_can_castle_queenside &&
               get_piece(board, 56).type == ROOK && get_piece(board, 56).color == BLACK &&
               is_empty_square(board, 57) && is_empty_square(board, 58) && is_empty_square(board, 59) &&
               !is_square_attacked(board, 58, WHITE) && !is_square_attacked(board, 59, WHITE)
                move = Move(square, 58, piece, EMPTY_PIECE)
                move.is_castle = true
                push!(moves, move)
            end
        end
    end
end

function generate_moves(board::Board)
    moves = Move[]
    current_color = board.state.white_to_move ? WHITE : BLACK
    
    for square in 0:63
        piece = get_piece(board, square)
        if piece.type == EMPTY || piece.color != current_color
            continue
        end
        
        if piece.type == PAWN
            generate_pawn_moves(board, square, moves)
        elseif piece.type == KNIGHT
            generate_knight_moves(board, square, moves)
        elseif piece.type == BISHOP
            generate_sliding_moves(board, square, moves, [-9, -7, 7, 9])
        elseif piece.type == ROOK
            generate_sliding_moves(board, square, moves, [-8, -1, 1, 8])
        elseif piece.type == QUEEN
            generate_sliding_moves(board, square, moves, [-9, -8, -7, -1, 1, 7, 8, 9])
        elseif piece.type == KING
            generate_king_moves(board, square, moves)
        end
    end
    
    return moves
end

function make_move!(board::Board, move::Move)
    # Store current position hash for repetition detection
    push!(board.position_history, board.zobrist_hash)

    # Backup current state in the move
    move.prev_en_passant = board.state.en_passant_square
    move.prev_white_can_castle_kingside = board.state.white_can_castle_kingside
    move.prev_white_can_castle_queenside = board.state.white_can_castle_queenside
    move.prev_black_can_castle_kingside = board.state.black_can_castle_kingside
    move.prev_black_can_castle_queenside = board.state.black_can_castle_queenside
    move.prev_halfmove_clock = board.state.halfmove_clock
    move.prev_fullmove_number = board.state.fullmove_number
    
    # Store move in history
    push!(board.move_history, move)
    
    # Update en passant square
    board.state.en_passant_square = -1
    
    # Handle special moves
    if move.is_castle
        # Move the rook
        if move.to == 6  # White kingside
            rook = get_piece(board, 7)
            set_piece!(board, 7, EMPTY_PIECE)
            set_piece!(board, 5, rook)
        elseif move.to == 2  # White queenside
            rook = get_piece(board, 0)
            set_piece!(board, 0, EMPTY_PIECE)
            set_piece!(board, 3, rook)
        elseif move.to == 62  # Black kingside
            rook = get_piece(board, 63)
            set_piece!(board, 63, EMPTY_PIECE)
            set_piece!(board, 61, rook)
        elseif move.to == 58  # Black queenside
            rook = get_piece(board, 56)
            set_piece!(board, 56, EMPTY_PIECE)
            set_piece!(board, 59, rook)
        end
    elseif move.is_en_passant
        # Remove captured pawn
        direction = move.piece.color == WHITE ? -8 : 8
        captured_square = move.to + direction
        set_piece!(board, captured_square, EMPTY_PIECE)
    end
    
    # Check for double pawn move (en passant setup)
    if move.piece.type == PAWN && abs(move.to - move.from) == 16
        board.state.en_passant_square = move.from + (move.to - move.from) ÷ 2
    end
    
    # Move the piece
    piece_to_place = move.piece
    if move.promotion != EMPTY
        piece_to_place = Piece(move.promotion, move.piece.color)
    end
    
    set_piece!(board, move.from, EMPTY_PIECE)
    set_piece!(board, move.to, piece_to_place)
    
    # Update castling rights
    if move.piece.type == KING
        if move.piece.color == WHITE
            board.state.white_can_castle_kingside = false
            board.state.white_can_castle_queenside = false
        else
            board.state.black_can_castle_kingside = false
            board.state.black_can_castle_queenside = false
        end
    elseif move.piece.type == ROOK
        if move.from == 0  # White queenside rook
            board.state.white_can_castle_queenside = false
        elseif move.from == 7  # White kingside rook
            board.state.white_can_castle_kingside = false
        elseif move.from == 56  # Black queenside rook
            board.state.black_can_castle_queenside = false
        elseif move.from == 63  # Black kingside rook
            board.state.black_can_castle_kingside = false
        end
    end

    # Capturing a rook on its original square also removes castling rights
    if move.captured.type == ROOK
        if move.to == 0
            board.state.white_can_castle_queenside = false
        elseif move.to == 7
            board.state.white_can_castle_kingside = false
        elseif move.to == 56
            board.state.black_can_castle_queenside = false
        elseif move.to == 63
            board.state.black_can_castle_kingside = false
        end
    end
    
    # Update move counters
    if move.piece.type == PAWN || move.captured.type != EMPTY
        board.state.halfmove_clock = 0
    else
        board.state.halfmove_clock += 1
    end
    
    # Switch turn first
    board.state.white_to_move = !board.state.white_to_move
    
    # Increment fullmove number after black moves (now it's white's turn)
    if board.state.white_to_move
        board.state.fullmove_number += 1
    end

    board.zobrist_hash = compute_zobrist_hash(board.pieces, board.state)
end

function undo_move!(board::Board)
    if isempty(board.move_history)
        return false
    end
    
    move = pop!(board.move_history)
    
    # Restore game state
    board.state.white_to_move = !board.state.white_to_move
    board.state.en_passant_square = move.prev_en_passant
    board.state.white_can_castle_kingside = move.prev_white_can_castle_kingside
    board.state.white_can_castle_queenside = move.prev_white_can_castle_queenside
    board.state.black_can_castle_kingside = move.prev_black_can_castle_kingside
    board.state.black_can_castle_queenside = move.prev_black_can_castle_queenside
    board.state.halfmove_clock = move.prev_halfmove_clock
    board.state.fullmove_number = move.prev_fullmove_number
    
    # Restore piece positions
    set_piece!(board, move.from, move.piece)
    set_piece!(board, move.to, move.captured)
    
    # Handle special moves
    if move.is_castle
        # Move the rook back
        if move.to == 6  # White kingside
            rook = get_piece(board, 5)
            set_piece!(board, 5, EMPTY_PIECE)
            set_piece!(board, 7, rook)
        elseif move.to == 2  # White queenside
            rook = get_piece(board, 3)
            set_piece!(board, 3, EMPTY_PIECE)
            set_piece!(board, 0, rook)
        elseif move.to == 62  # Black kingside
            rook = get_piece(board, 61)
            set_piece!(board, 61, EMPTY_PIECE)
            set_piece!(board, 63, rook)
        elseif move.to == 58  # Black queenside
            rook = get_piece(board, 59)
            set_piece!(board, 59, EMPTY_PIECE)
            set_piece!(board, 56, rook)
        end
    elseif move.is_en_passant
        # Restore captured pawn
        direction = move.piece.color == WHITE ? -8 : 8
        captured_square = move.to + direction
        set_piece!(board, captured_square, move.captured)
        set_piece!(board, move.to, EMPTY_PIECE)
    end

    if !isempty(board.position_history)
        board.zobrist_hash = pop!(board.position_history)
    else
        board.zobrist_hash = compute_zobrist_hash(board.pieces, board.state)
    end
    
    return true
end

function is_legal_move(board::Board, move::Move)
    # Make move temporarily
    make_move!(board, move)
    
    # Check if king is in check after move
    color = !board.state.white_to_move ? WHITE : BLACK
    legal = !is_in_check(board, color)
    
    # Undo move
    undo_move!(board)
    
    return legal
end

function get_legal_moves(board::Board)
    moves = generate_moves(board)
    legal_moves = Move[]
    
    for move in moves
        if is_legal_move(board, move)
            push!(legal_moves, move)
        end
    end
    
    return legal_moves
end

function parse_move(board::Board, move_str::AbstractString)
    if length(move_str) < 4
        return nothing
    end
    
    from_square = algebraic_to_square(move_str[1:2])
    to_square = algebraic_to_square(move_str[3:4])
    
    if !is_valid_square(from_square) || !is_valid_square(to_square)
        return nothing
    end
    
    piece = get_piece(board, from_square)
    captured = get_piece(board, to_square)
    move = Move(from_square, to_square, piece, captured)
    
    # Handle promotion
    if length(move_str) == 5
        promotion_char = uppercase(move_str[5])
        if promotion_char == 'Q'
            move.promotion = QUEEN
        elseif promotion_char == 'R'
            move.promotion = ROOK
        elseif promotion_char == 'B'
            move.promotion = BISHOP
        elseif promotion_char == 'N'
            move.promotion = KNIGHT
        end
    end
    
    return move
end

function move_to_string(move::Move)
    result = square_to_algebraic(move.from) * square_to_algebraic(move.to)
    if move.promotion != EMPTY
        if move.promotion == QUEEN
            result *= "Q"
        elseif move.promotion == ROOK
            result *= "R"
        elseif move.promotion == BISHOP
            result *= "B"
        elseif move.promotion == KNIGHT
            result *= "N"
        end
    end
    return result
end
