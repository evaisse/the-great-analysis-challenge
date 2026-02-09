from lib.types import GameState

def is_draw_by_repetition(board) -> bool:
    current_hash = board.zobrist_hash
    count = 1
    
    # Position history contains hashes of previous positions
    history = board.position_history
    halfmove_clock = board.halfmove_clock
    
    # Search back until the last irreversible move
    start_idx = max(0, len(history) - halfmove_clock)
    
    for i in range(len(history) - 1, start_idx - 1, -1):
        if history[i] == current_hash:
            count += 1
            if count >= 3:
                return True
    
    return False

def is_draw_by_fifty_moves(board) -> bool:
    return board.halfmove_clock >= 100

def is_draw(board) -> bool:
    return is_draw_by_repetition(board) or is_draw_by_fifty_moves(board)
