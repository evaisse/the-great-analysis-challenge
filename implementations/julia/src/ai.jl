"""
Chess AI engine with minimax and alpha-beta pruning
Aligned with AI_ALGORITHM_SPEC.md
"""


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

const PAWN_TABLE = [
    [0, 0, 0, 0, 0, 0, 0, 0],
    [50, 50, 50, 50, 50, 50, 50, 50],
    [10, 10, 20, 30, 30, 20, 10, 10],
    [5, 5, 10, 25, 25, 10, 5, 5],
    [0, 0, 0, 20, 20, 0, 0, 0],
    [5, -5, -10, 0, 0, -10, -5, 5],
    [5, 10, 10, -20, -20, 10, 10, 5],
    [0, 0, 0, 0, 0, 0, 0, 0]
]

const KNIGHT_TABLE = [
    [-50, -40, -30, -30, -30, -30, -40, -50],
    [-40, -20, 0, 0, 0, 0, -20, -40],
    [-30, 0, 10, 15, 15, 10, 0, -30],
    [-30, 5, 15, 20, 20, 15, 5, -30],
    [-30, 0, 15, 20, 20, 15, 0, -30],
    [-30, 5, 10, 15, 15, 10, 5, -30],
    [-40, -20, 0, 5, 5, 0, -20, -40],
    [-50, -40, -30, -30, -30, -30, -40, -50]
]

const BISHOP_TABLE = [
    [-20, -10, -10, -10, -10, -10, -10, -20],
    [-10, 0, 0, 0, 0, 0, 0, -10],
    [-10, 0, 5, 10, 10, 5, 0, -10],
    [-10, 5, 5, 10, 10, 5, 5, -10],
    [-10, 0, 10, 10, 10, 10, 0, -10],
    [-10, 10, 10, 10, 10, 10, 10, -10],
    [-10, 5, 0, 0, 0, 0, 5, -10],
    [-20, -10, -10, -10, -10, -10, -10, -20]
]

const ROOK_TABLE = [
    [0, 0, 0, 0, 0, 0, 0, 0],
    [5, 10, 10, 10, 10, 10, 10, 5],
    [-5, 0, 0, 0, 0, 0, 0, -5],
    [-5, 0, 0, 0, 0, 0, 0, -5],
    [-5, 0, 0, 0, 0, 0, 0, -5],
    [-5, 0, 0, 0, 0, 0, 0, -5],
    [-5, 0, 0, 0, 0, 0, 0, -5],
    [0, 0, 0, 5, 5, 0, 0, 0]
]

const QUEEN_TABLE = [
    [-20, -10, -10, -5, -5, -10, -10, -20],
    [-10, 0, 0, 0, 0, 0, 0, -10],
    [-10, 0, 5, 5, 5, 5, 0, -10],
    [-5, 0, 5, 5, 5, 5, 0, -5],
    [0, 0, 5, 5, 5, 5, 0, -5],
    [-10, 5, 5, 5, 5, 5, 0, -10],
    [-10, 0, 5, 0, 0, 0, 0, -10],
    [-20, -10, -10, -5, -5, -10, -10, -20]
]

const KING_TABLE = [
    [-30, -40, -40, -50, -50, -40, -40, -30],
    [-30, -40, -40, -50, -50, -40, -40, -30],
    [-30, -40, -40, -50, -50, -40, -40, -30],
    [-30, -40, -40, -50, -50, -40, -40, -30],
    [-20, -30, -30, -40, -40, -30, -30, -20],
    [-10, -20, -20, -20, -20, -20, -20, -10],
    [20, 20, 0, 0, 0, 0, 20, 20],
    [20, 30, 10, 0, 0, 10, 30, 20]
]

function evaluate_position(board::Board)
    score = 0

    for square in 0:63
        piece = get_piece(board, square)
        if piece.type != EMPTY
            file = square % 8
            rank = square ÷ 8
            eval_row = piece.color == WHITE ? rank : 7 - rank

            position_bonus = 0
            if piece.type == PAWN
                position_bonus = PAWN_TABLE[eval_row + 1][file + 1]
            elseif piece.type == KNIGHT
                position_bonus = KNIGHT_TABLE[eval_row + 1][file + 1]
            elseif piece.type == BISHOP
                position_bonus = BISHOP_TABLE[eval_row + 1][file + 1]
            elseif piece.type == ROOK
                position_bonus = ROOK_TABLE[eval_row + 1][file + 1]
            elseif piece.type == QUEEN
                position_bonus = QUEEN_TABLE[eval_row + 1][file + 1]
            elseif piece.type == KING
                position_bonus = KING_TABLE[eval_row + 1][file + 1]
            end

            value = PIECE_VALUES[piece.type] + position_bonus
            score += piece.color == WHITE ? value : -value
        end
    end

    return score
end

function score_move(board::Board, move::Move)
    score = 0

    attacker_value = PIECE_VALUES[move.piece.type]
    captured_piece = move.captured.type != EMPTY ? move.captured : get_piece(board, move.to)
    if captured_piece.type != EMPTY
        victim_value = PIECE_VALUES[captured_piece.type]
        score += victim_value * 10 - attacker_value
    end

    if move.promotion != EMPTY
        score += PIECE_VALUES[move.promotion] * 10
    end

    to_row = move.to ÷ 8
    to_col = move.to % 8
    if (to_row == 3 || to_row == 4) && (to_col == 3 || to_col == 4)
        score += 10
    end

    if move.is_castle
        score += 50
    end

    return score
end

function move_notation(move::Move)
    notation = square_to_algebraic(move.from) * square_to_algebraic(move.to)
    if move.promotion != EMPTY
        promo = if move.promotion == QUEEN
            "q"
        elseif move.promotion == ROOK
            "r"
        elseif move.promotion == BISHOP
            "b"
        else
            "n"
        end
        notation *= promo
    end
    return notation
end

function order_moves(board::Board, moves::Vector{Move})
    scored = [(score_move(board, move), move_notation(move), move) for move in moves]
    sort!(scored, by = x -> (-x[1], x[2]))
    return [item[3] for item in scored]
end

function minimax(board::Board, depth::Int, alpha::Int, beta::Int, maximizing::Bool)
    if depth == 0
        return evaluate_position(board)
    end

    moves = get_legal_moves(board)

    if isempty(moves)
        current_color = board.state.white_to_move ? WHITE : BLACK
        if is_in_check(board, current_color)
            return maximizing ? -100000 : 100000
        else
            return 0
        end
    end

    ordered_moves = order_moves(board, moves)

    if maximizing
        max_eval = -1000000
        current_alpha = alpha
        for move in ordered_moves
            make_move!(board, move)
            eval = minimax(board, depth - 1, current_alpha, beta, false)
            undo_move!(board)

            max_eval = max(max_eval, eval)
            current_alpha = max(current_alpha, eval)
            if beta <= current_alpha
                break
            end
        end
        return max_eval
    else
        min_eval = 1000000
        current_beta = beta
        for move in ordered_moves
            make_move!(board, move)
            eval = minimax(board, depth - 1, alpha, current_beta, true)
            undo_move!(board)

            min_eval = min(min_eval, eval)
            current_beta = min(current_beta, eval)
            if current_beta <= alpha
                break
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

    ordered_moves = order_moves(board, moves)
    maximizing = board.state.white_to_move

    best_move = nothing
    best_eval = maximizing ? -1000000 : 1000000

    alpha = -1000000
    beta = 1000000

    for move in ordered_moves
        make_move!(board, move)
        eval = minimax(board, depth - 1, alpha, beta, !maximizing)
        undo_move!(board)

        if maximizing
            if eval > best_eval || best_move === nothing
                best_eval = eval
                best_move = move
            end
            alpha = max(alpha, eval)
        else
            if eval < best_eval || best_move === nothing
                best_eval = eval
                best_move = move
            end
            beta = min(beta, eval)
        end
    end

    return best_move, best_eval
end
