<?php

namespace Chess;

class DrawDetection {
    public static function is_draw_by_repetition($board): bool {
        $current_hash = $board->zobrist_hash;
        $count = 1;
        
        $history = $board->position_history;
        $halfmove_clock = $board->halfmove_clock;
        
        $history_len = count($history);
        $start_idx = max(0, $history_len - $halfmove_clock);
        
        for ($i = $history_len - 1; $i >= $start_idx; $i--) {
            if (gmp_cmp($history[$i], $current_hash) === 0) {
                $count++;
                if ($count >= 3) {
                    return true;
                }
            }
        }
        
        return false;
    }

    public static function is_draw_by_fifty_moves($board): bool {
        return $board->halfmove_clock >= 100;
    }

    public static function is_draw($board): bool {
        return self::is_draw_by_repetition($board) || self::is_draw_by_fifty_moves($board);
    }
}
