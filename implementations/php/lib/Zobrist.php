<?php

namespace Chess;

require_once __DIR__ . '/constants.php';

class Zobrist {
    public array $pieces;
    public \GMP $side_to_move;
    public array $castling;
    public array $en_passant;

    private static ?Zobrist $instance = null;

    public static function getInstance(): Zobrist {
        if (self::$instance === null) {
            self::$instance = new Zobrist();
        }
        return self::$instance;
    }

    private function __construct() {
        $this->pieces = array_fill(0, 12, array_fill(0, 64, null));
        $this->castling = array_fill(0, 4, null);
        $this->en_passant = array_fill(0, 8, null);

        $state = gmp_init("0x123456789ABCDEF0");
        $mask64 = gmp_init("0xFFFFFFFFFFFFFFFF");

        $next_rand = function() use (&$state, $mask64) {
            // state ^= state << 13
            $state = gmp_xor($state, gmp_and(gmp_mul($state, gmp_pow(2, 13)), $mask64));
            // state ^= state >> 7
            $state = gmp_xor($state, gmp_div($state, gmp_pow(2, 7)));
            // state ^= state << 17
            $state = gmp_xor($state, gmp_and(gmp_mul($state, gmp_pow(2, 17)), $mask64));
            return $state;
        };

        for ($p = 0; $p < 12; $p++) {
            for ($s = 0; $s < 64; $s++) {
                $this->pieces[$p][$s] = $next_rand();
            }
        }

        $this->side_to_move = $next_rand();

        for ($i = 0; $i < 4; $i++) {
            $this->castling[$i] = $next_rand();
        }

        for ($i = 0; $i < 8; $i++) {
            $this->en_passant[$i] = $next_rand();
        }
    }

    public function get_piece_index(int $type, int $color): int {
        $idx = match($type) {
            CHESS_PAWN => 0,
            CHESS_KNIGHT => 1,
            CHESS_BISHOP => 2,
            CHESS_ROOK => 3,
            CHESS_QUEEN => 4,
            CHESS_KING => 5,
            default => 0
        };
        if ($color === CHESS_BLACK) {
            $idx += 6;
        }
        return $idx;
    }

    public function compute_hash($board): \GMP {
        $hash = gmp_init(0);
        
        for ($row = 0; $row < 8; $row++) {
            for ($col = 0; $col < 8; $col++) {
                [$piece, $color] = $board->squares[$row][$col];
                if ($piece !== CHESS_EMPTY) {
                    $square = (7 - $row) * 8 + $col; // a1=0
                    $idx = $this->get_piece_index($piece, $color);
                    $hash = gmp_xor($hash, $this->pieces[$idx][$square]);
                }
            }
        }

        if ($board->current_player === CHESS_BLACK) {
            $hash = gmp_xor($hash, $this->side_to_move);
        }

        $rights = $board->castling_rights;
        if ($rights->white_kingside) $hash = gmp_xor($hash, $this->castling[0]);
        if ($rights->white_queenside) $hash = gmp_xor($hash, $this->castling[1]);
        if ($rights->black_kingside) $hash = gmp_xor($hash, $this->castling[2]);
        if ($rights->black_queenside) $hash = gmp_xor($hash, $this->castling[3]);

        $ep = $board->en_passant_target;
        if ($ep !== null) {
            $hash = gmp_xor($hash, $this->en_passant[$ep[1]]);
        }

        return $hash;
    }
}
