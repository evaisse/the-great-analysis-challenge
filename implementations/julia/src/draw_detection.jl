"""
Draw detection helpers (repetition, fifty-move rule)
"""

function is_draw_by_repetition(board::Board)
    current_hash = board.zobrist_hash
    count = 1

    history_len = length(board.position_history)
    if history_len == 0
        return false
    end

    start_idx = max(1, history_len - board.state.halfmove_clock)

    for i in history_len:-1:start_idx
        if board.position_history[i] == current_hash
            count += 1
            if count >= 3
                return true
            end
        end
    end

    return false
end

function is_draw_by_fifty_moves(board::Board)
    return board.state.halfmove_clock >= 100
end
