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
    public ?array $captured_piece = null;
    
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

    public function to_fen(?CastlingConfig $config = null, bool $chess960_mode = false): string {
        if ($chess960_mode && $config !== null) {
            $white_files = [];
            $black_files = [];

            if ($this->white_queenside) {
                $white_files[] = $config->white_queenside_rook_col;
            }
            if ($this->white_kingside) {
                $white_files[] = $config->white_kingside_rook_col;
            }
            if ($this->black_queenside) {
                $black_files[] = $config->black_queenside_rook_col;
            }
            if ($this->black_kingside) {
                $black_files[] = $config->black_kingside_rook_col;
            }

            sort($white_files);
            sort($black_files);

            $fen = '';
            foreach ($white_files as $file) {
                $fen .= chr(ord('A') + $file);
            }
            foreach ($black_files as $file) {
                $fen .= chr(ord('a') + $file);
            }

            return $fen !== '' ? $fen : '-';
        }

        $fen = '';
        if ($this->white_kingside) {
            $fen .= 'K';
        }
        if ($this->white_queenside) {
            $fen .= 'Q';
        }
        if ($this->black_kingside) {
            $fen .= 'k';
        }
        if ($this->black_queenside) {
            $fen .= 'q';
        }

        return $fen !== '' ? $fen : '-';
    }
}

class CastlingConfig {
    public int $white_king_col = 4;
    public int $white_kingside_rook_col = 7;
    public int $white_queenside_rook_col = 0;
    public int $black_king_col = 4;
    public int $black_kingside_rook_col = 7;
    public int $black_queenside_rook_col = 0;

    public function copy(): CastlingConfig {
        $copy = new CastlingConfig();
        $copy->white_king_col = $this->white_king_col;
        $copy->white_kingside_rook_col = $this->white_kingside_rook_col;
        $copy->white_queenside_rook_col = $this->white_queenside_rook_col;
        $copy->black_king_col = $this->black_king_col;
        $copy->black_kingside_rook_col = $this->black_kingside_rook_col;
        $copy->black_queenside_rook_col = $this->black_queenside_rook_col;
        return $copy;
    }

    public function is_classical(): bool {
        return $this->white_king_col === 4 &&
            $this->white_kingside_rook_col === 7 &&
            $this->white_queenside_rook_col === 0 &&
            $this->black_king_col === 4 &&
            $this->black_kingside_rook_col === 7 &&
            $this->black_queenside_rook_col === 0;
    }
}

class IrreversibleState {
    public CastlingRights $castling_rights;
    public CastlingConfig $castling_config;
    public bool $chess960_mode;
    public ?array $en_passant_target;
    public int $halfmove_clock;
    public int $zobrist_hash;

    public function __construct(CastlingRights $cr, CastlingConfig $cc, bool $chess960_mode, ?array $ep, int $hc, int $zh) {
        $this->castling_rights = $cr;
        $this->castling_config = $cc;
        $this->chess960_mode = $chess960_mode;
        $this->en_passant_target = $ep;
        $this->halfmove_clock = $hc;
        $this->zobrist_hash = $zh;
    }
}

class GameState {
    public CastlingRights $castling_rights;
    public CastlingConfig $castling_config;
    public bool $chess960_mode;
    public ?array $en_passant_target;
    public int $halfmove_clock;
    public int $fullmove_number;
    public int $zobrist_hash;
    public array $position_history;
    public array $irreversible_history;

    public function __construct(CastlingRights $cr, CastlingConfig $cc, bool $chess960_mode, ?array $ep, int $hc, int $fn, int $zh, array $ph, array $ih) {
        $this->castling_rights = $cr;
        $this->castling_config = $cc;
        $this->chess960_mode = $chess960_mode;
        $this->en_passant_target = $ep;
        $this->halfmove_clock = $hc;
        $this->fullmove_number = $fn;
        $this->zobrist_hash = $zh;
        $this->position_history = $ph;
        $this->irreversible_history = $ih;
    }
}
