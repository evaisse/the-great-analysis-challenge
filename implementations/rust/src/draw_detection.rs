use crate::types::*;

pub fn is_draw_by_repetition(state: &GameState) -> bool {
    let current_hash = state.zobrist_hash;
    let mut count = 1; // Count the current position

    if state.position_history.is_empty() {
        return false;
    }

    // Search back until the last irreversible move
    let history_len = state.position_history.len();
    let halfmove_limit = state.halfmove_clock as usize;
    let start_idx = history_len.saturating_sub(halfmove_limit);

    for i in (start_idx..history_len).rev() {
        if state.position_history[i] == current_hash {
            count += 1;
            if count >= 3 {
                return true;
            }
        }
    }
    
    false
}

pub fn is_draw_by_fifty_moves(state: &GameState) -> bool {
    state.halfmove_clock >= 100
}
