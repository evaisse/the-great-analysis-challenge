<?php

namespace Chess;

require_once __DIR__ . '/constants.php';

/**
 * Move structure
 */
class Move {
    public int $from_row;
    public int $from_col;
    public int $to_row;
    public int $to_col;
    public ?int $promotion;
    public bool $is_castling;
    public bool $is_en_passant;
    
    public function __construct(
        int $from_row,
        int $from_col,
        int $to_row,
        int $to_col,
        ?int $promotion = null,
        bool $is_castling = false,
        bool $is_en_passant = false
    ) {
        $this->from_row = $from_row;
        $this->from_col = $from_col;
        $this->to_row = $to_row;
        $this->to_col = $to_col;
        $this->promotion = $promotion;
        $this->is_castling = $is_castling;
        $this->is_en_passant = $is_en_passant;
    }
    
    public function to_string(): string {
        $from = chr(ord('a') + $this->from_col) . (8 - $this->from_row);
        $to = chr(ord('a') + $this->to_col) . (8 - $this->to_row);
        $promo = $this->promotion ? $this->piece_to_char($this->promotion) : '';
        return $from . $to . $promo;
    }
    
    private function piece_to_char(int $piece): string {
        return match($piece) {
            CHESS_QUEEN => 'Q',
            CHESS_ROOK => 'R',
            CHESS_BISHOP => 'B',
            CHESS_KNIGHT => 'N',
            default => ''
        };
    }
}
