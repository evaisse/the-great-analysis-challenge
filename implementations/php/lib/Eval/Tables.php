<?php

namespace Chess\Eval;

final class Tables {
    private const MG_PAWN = [
        [0, 0, 0, 0, 0, 0, 0, 0],
        [5, 10, 10, -20, -20, 10, 10, 5],
        [5, -5, -10, 0, 0, -10, -5, 5],
        [0, 0, 0, 20, 20, 0, 0, 0],
        [5, 5, 10, 25, 25, 10, 5, 5],
        [10, 10, 20, 30, 30, 20, 10, 10],
        [50, 50, 50, 50, 50, 50, 50, 50],
        [0, 0, 0, 0, 0, 0, 0, 0],
    ];

    private const MG_KNIGHT = [
        [-50, -40, -30, -30, -30, -30, -40, -50],
        [-40, -20, 0, 0, 0, 0, -20, -40],
        [-30, 0, 10, 15, 15, 10, 0, -30],
        [-30, 5, 15, 20, 20, 15, 5, -30],
        [-30, 0, 15, 20, 20, 15, 0, -30],
        [-30, 5, 10, 15, 15, 10, 5, -30],
        [-40, -20, 0, 5, 5, 0, -20, -40],
        [-50, -40, -30, -30, -30, -30, -40, -50],
    ];

    private const MG_BISHOP = [
        [-20, -10, -10, -10, -10, -10, -10, -20],
        [-10, 0, 0, 0, 0, 0, 0, -10],
        [-10, 0, 5, 10, 10, 5, 0, -10],
        [-10, 5, 5, 10, 10, 5, 5, -10],
        [-10, 0, 10, 10, 10, 10, 0, -10],
        [-10, 10, 10, 10, 10, 10, 10, -10],
        [-10, 5, 0, 0, 0, 0, 5, -10],
        [-20, -10, -10, -10, -10, -10, -10, -20],
    ];

    private const MG_ROOK = [
        [0, 0, 0, 5, 5, 0, 0, 0],
        [-5, 0, 0, 0, 0, 0, 0, -5],
        [-5, 0, 0, 0, 0, 0, 0, -5],
        [-5, 0, 0, 0, 0, 0, 0, -5],
        [-5, 0, 0, 0, 0, 0, 0, -5],
        [-5, 0, 0, 0, 0, 0, 0, -5],
        [5, 10, 10, 10, 10, 10, 10, 5],
        [0, 0, 0, 0, 0, 0, 0, 0],
    ];

    private const MG_QUEEN = [
        [-20, -10, -10, -5, -5, -10, -10, -20],
        [-10, 0, 0, 0, 0, 0, 0, -10],
        [-10, 0, 5, 5, 5, 5, 0, -10],
        [-5, 0, 5, 5, 5, 5, 0, -5],
        [0, 0, 5, 5, 5, 5, 0, -5],
        [-10, 5, 5, 5, 5, 5, 0, -10],
        [-10, 0, 5, 0, 0, 0, 0, -10],
        [-20, -10, -10, -5, -5, -10, -10, -20],
    ];

    private const MG_KING = [
        [20, 30, 10, 0, 0, 10, 30, 20],
        [20, 20, 0, 0, 0, 0, 20, 20],
        [-10, -20, -20, -20, -20, -20, -20, -10],
        [-20, -30, -30, -40, -40, -30, -30, -20],
        [-30, -40, -40, -50, -50, -40, -40, -30],
        [-30, -40, -40, -50, -50, -40, -40, -30],
        [-30, -40, -40, -50, -50, -40, -40, -30],
        [-30, -40, -40, -50, -50, -40, -40, -30],
    ];

    private const EG_PAWN = [
        [0, 0, 0, 0, 0, 0, 0, 0],
        [10, 10, 10, 10, 10, 10, 10, 10],
        [8, 8, 12, 18, 18, 12, 8, 8],
        [6, 6, 10, 16, 16, 10, 6, 6],
        [4, 4, 8, 12, 12, 8, 4, 4],
        [2, 2, 4, 8, 8, 4, 2, 2],
        [0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0],
    ];

    private const EG_KNIGHT = [
        [-40, -25, -20, -20, -20, -20, -25, -40],
        [-25, -10, -2, 0, 0, -2, -10, -25],
        [-20, -2, 8, 12, 12, 8, -2, -20],
        [-20, 0, 12, 16, 16, 12, 0, -20],
        [-20, 0, 12, 16, 16, 12, 0, -20],
        [-20, -2, 8, 12, 12, 8, -2, -20],
        [-25, -10, -2, 0, 0, -2, -10, -25],
        [-40, -25, -20, -20, -20, -20, -25, -40],
    ];

    private const EG_BISHOP = [
        [-15, -8, -8, -8, -8, -8, -8, -15],
        [-8, 0, 0, 0, 0, 0, 0, -8],
        [-8, 0, 6, 8, 8, 6, 0, -8],
        [-8, 6, 8, 10, 10, 8, 6, -8],
        [-8, 6, 8, 10, 10, 8, 6, -8],
        [-8, 0, 6, 8, 8, 6, 0, -8],
        [-8, 0, 0, 0, 0, 0, 0, -8],
        [-15, -8, -8, -8, -8, -8, -8, -15],
    ];

    private const EG_ROOK = [
        [0, 4, 6, 8, 8, 6, 4, 0],
        [2, 4, 6, 8, 8, 6, 4, 2],
        [2, 4, 6, 8, 8, 6, 4, 2],
        [2, 4, 6, 8, 8, 6, 4, 2],
        [2, 4, 6, 8, 8, 6, 4, 2],
        [2, 4, 6, 8, 8, 6, 4, 2],
        [0, 2, 4, 6, 6, 4, 2, 0],
        [0, 0, 2, 4, 4, 2, 0, 0],
    ];

    private const EG_QUEEN = [
        [-10, -4, -2, 0, 0, -2, -4, -10],
        [-4, 0, 2, 4, 4, 2, 0, -4],
        [-2, 2, 4, 6, 6, 4, 2, -2],
        [0, 4, 6, 8, 8, 6, 4, 0],
        [0, 4, 6, 8, 8, 6, 4, 0],
        [-2, 2, 4, 6, 6, 4, 2, -2],
        [-4, 0, 2, 4, 4, 2, 0, -4],
        [-10, -4, -2, 0, 0, -2, -4, -10],
    ];

    private const EG_KING = [
        [-50, -30, -20, -20, -20, -20, -30, -50],
        [-30, -10, 0, 0, 0, 0, -10, -30],
        [-20, 0, 10, 15, 15, 10, 0, -20],
        [-20, 0, 15, 25, 25, 15, 0, -20],
        [-20, 0, 15, 25, 25, 15, 0, -20],
        [-20, 0, 10, 15, 15, 10, 0, -20],
        [-30, -10, 0, 0, 0, 0, -10, -30],
        [-50, -30, -20, -20, -20, -20, -30, -50],
    ];

    private const PHASE_VALUES = [
        CHESS_PAWN => 0,
        CHESS_KNIGHT => 1,
        CHESS_BISHOP => 1,
        CHESS_ROOK => 2,
        CHESS_QUEEN => 4,
        CHESS_KING => 0,
    ];

    private const KNIGHT_MOBILITY = [-15, -5, 0, 5, 10, 15, 20, 22, 24];
    private const BISHOP_MOBILITY = [-20, -10, 0, 5, 10, 15, 18, 21, 24, 26, 28, 30, 32, 34];
    private const ROOK_MOBILITY = [-15, -8, 0, 3, 6, 9, 12, 14, 16, 18, 20, 22, 24, 26, 28];
    private const QUEEN_MOBILITY = [-10, -5, 0, 2, 4, 6, 8, 10, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 24, 25, 25, 26, 26, 27, 28];
    private const PASSED_PAWN_BONUS = [0, 10, 20, 40, 60, 90, 120, 0];

    public static function middlegamePst(int $piece, int $row, int $col, int $color): int {
        return self::pstValue($piece, $row, $col, $color, true);
    }

    public static function endgamePst(int $piece, int $row, int $col, int $color): int {
        return self::pstValue($piece, $row, $col, $color, false);
    }

    public static function phaseValue(int $piece): int {
        return self::PHASE_VALUES[$piece] ?? 0;
    }

    public static function totalPhase(): int {
        return 24;
    }

    public static function mobilityBonus(int $piece, int $mobility): int {
        $table = match ($piece) {
            CHESS_KNIGHT => self::KNIGHT_MOBILITY,
            CHESS_BISHOP => self::BISHOP_MOBILITY,
            CHESS_ROOK => self::ROOK_MOBILITY,
            CHESS_QUEEN => self::QUEEN_MOBILITY,
            default => [0],
        };

        $index = max(0, min($mobility, count($table) - 1));
        return $table[$index];
    }

    public static function passedPawnBonusByRank(int $rankFromWhite): int {
        $index = max(0, min($rankFromWhite, count(self::PASSED_PAWN_BONUS) - 1));
        return self::PASSED_PAWN_BONUS[$index];
    }

    public static function bishopPairBonus(): int {
        return 30;
    }

    public static function rookOpenFileBonus(): int {
        return 25;
    }

    public static function rookSemiOpenFileBonus(): int {
        return 15;
    }

    public static function rookSeventhBonus(): int {
        return 20;
    }

    public static function knightOutpostBonus(): int {
        return 20;
    }

    private static function pstValue(int $piece, int $row, int $col, int $color, bool $middlegame): int {
        $table = match ($piece) {
            CHESS_PAWN => $middlegame ? self::MG_PAWN : self::EG_PAWN,
            CHESS_KNIGHT => $middlegame ? self::MG_KNIGHT : self::EG_KNIGHT,
            CHESS_BISHOP => $middlegame ? self::MG_BISHOP : self::EG_BISHOP,
            CHESS_ROOK => $middlegame ? self::MG_ROOK : self::EG_ROOK,
            CHESS_QUEEN => $middlegame ? self::MG_QUEEN : self::EG_QUEEN,
            CHESS_KING => $middlegame ? self::MG_KING : self::EG_KING,
            default => null,
        };

        if ($table === null) {
            return 0;
        }

        $tableRow = $color === CHESS_WHITE ? 7 - $row : $row;
        return $table[$tableRow][$col];
    }
}
