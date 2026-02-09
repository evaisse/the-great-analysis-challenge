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

class CastlingRights {
    public bool $white_kingside = true;
    public bool $white_queenside = true;
    public bool $black_kingside = true;
    public bool $black_queenside = true;

    public function copy(): CastlingRights {
        $copy = new CastlingRights();
        $copy->white_kingside = $this->white_kingside;
        $copy->white_queenside = $this->white_queenside;
        $copy->black_kingside = $this->black_kingside;
        $copy->black_queenside = $this->black_queenside;
        return $copy;
    }
}

class IrreversibleState {
    public CastlingRights $castling_rights;
    public ?array $en_passant_target;
    public int $halfmove_clock;
    public \GMP $zobrist_hash;

    public function __construct(CastlingRights $cr, ?array $ep, int $hc, \GMP $zh) {
        $this->castling_rights = $cr;
        $this->en_passant_target = $ep;
        $this->halfmove_clock = $hc;
        $this->zobrist_hash = $zh;
    }
}

class GameState {
    public CastlingRights $castling_rights;
    public ?array $en_passant_target;
    public int $halfmove_clock;
    public int $fullmove_number;
    public \GMP $zobrist_hash;
    public array $position_history;
    public array $irreversible_history;

    public function __construct(CastlingRights $cr, ?array $ep, int $hc, int $fn, \GMP $zh, array $ph, array $ih) {
        $this->castling_rights = $cr;
        $this->en_passant_target = $ep;
        $this->halfmove_clock = $hc;
        $this->fullmove_number = $fn;
        $this->zobrist_hash = $zh;
        $this->position_history = $ph;
        $this->irreversible_history = $ih;
    }
}
