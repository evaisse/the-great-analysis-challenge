"""
Chess AI engine with minimax and alpha-beta pruning
"""

include("move_generator.jl")

# Piece values for evaluation
const PIECE_VALUES = Dict(
    EMPTY => 0,
    PAWN => 100,
    KNIGHT => 320,
    BISHOP => 330,
    ROOK => 500,
    QUEEN => 900,
    KING => 20000
)

# Position bonuses for center control
const CENTER_SQUARES = [27, 28, 35, 36]  # d4, d5, e4, e5

function evaluate_position(board::Board)
    score = 0
    
    # Check for checkmate/stalemate
    legal_moves = get_legal_moves(board)
    current_color = board.state.white_to_move ? WHITE : BLACK
    
    if isempty(legal_moves)
        if is_in_check(board, current_color)
            # Checkmate
            return current_color == WHITE ? -100000 : 100000
        else
            # Stalemate
            return 0
        end
    end
    
    # Material evaluation
    for square in 0:63
        piece = get_piece(board, square)
        if piece.type != EMPTY
            piece_value = PIECE_VALUES[piece.type]
            
            # Center control bonus
            if piece.type == PAWN || piece.type == KNIGHT || piece.type == BISHOP
                if square in CENTER_SQUARES
                    piece_value += 10
                end
            end
            
            # Pawn advancement bonus
            if piece.type == PAWN
                rank = square ÷ 8
                if piece.color == WHITE
                    piece_value += rank * 5
                else
                    piece_value += (7 - rank) * 5
                end
            end
            
            if piece.color == WHITE
                score += piece_value
            else
                score -= piece_value
            end
        end
    end
    
    return score
end

function minimax(board::Board, depth::Int, alpha::Int, beta::Int, maximizing::Bool)
    if depth == 0
        return evaluate_position(board)
    end
    
    moves = get_legal_moves(board)
    
    if isempty(moves)
        return evaluate_position(board)
    end
    
    if maximizing
        max_eval = -1000000
        for move in moves
            make_move!(board, move)
            eval = minimax(board, depth - 1, alpha, beta, false)
            undo_move!(board)
            
            max_eval = max(max_eval, eval)
            alpha = max(alpha, eval)
            
            if beta <= alpha
                break  # Beta cutoff
            end
        end
        return max_eval
    else
        min_eval = 1000000
        for move in moves
            make_move!(board, move)
            eval = minimax(board, depth - 1, alpha, beta, true)
            undo_move!(board)
            
            min_eval = min(min_eval, eval)
            beta = min(beta, eval)
            
            if beta <= alpha
                break  # Alpha cutoff
            end
        end
        return min_eval
    end
end

function find_best_move(board::Board, depth::Int)
    moves = get_legal_moves(board)
    
    if isempty(moves)
        return nothing, 0
    end
    
    best_move = moves[1]
    best_eval = board.state.white_to_move ? -1000000 : 1000000
    
    alpha = -1000000
    beta = 1000000
    
    for move in moves
        make_move!(board, move)
        eval = minimax(board, depth - 1, alpha, beta, !board.state.white_to_move)
        undo_move!(board)
        
        if board.state.white_to_move
            if eval > best_eval
                best_eval = eval
                best_move = move
            end
            alpha = max(alpha, eval)
        else
            if eval < best_eval
                best_eval = eval
                best_move = move
            end
            beta = min(beta, eval)
        end
    end
    
    return best_move, best_eval
end