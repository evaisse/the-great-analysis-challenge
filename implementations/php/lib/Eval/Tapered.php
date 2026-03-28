<?php

namespace Chess\Eval;

use Chess\Board;

final class Tapered {
    public static function computePhase(Board $board): int {
        $phase = 0;
        for ($row = 0; $row < 8; $row++) {
            for ($col = 0; $col < 8; $col++) {
                [$piece, ] = $board->get_piece($row, $col);
                if ($piece === CHESS_EMPTY) {
                    continue;
                }
                $phase += Tables::phaseValue($piece);
            }
        }

        return min(Tables::totalPhase(), $phase);
    }

    public static function evaluateMaterialAndPst(Board $board): array {
        $middlegame = 0;
        $endgame = 0;

        for ($row = 0; $row < 8; $row++) {
            for ($col = 0; $col < 8; $col++) {
                [$piece, $color] = $board->get_piece($row, $col);
                if ($piece === CHESS_EMPTY) {
                    continue;
                }

                $sign = $color === CHESS_WHITE ? 1 : -1;
                $value = CHESS_PIECE_VALUES[$piece];
                $middlegame += $sign * ($value + Tables::middlegamePst($piece, $row, $col, $color));
                $endgame += $sign * ($value + Tables::endgamePst($piece, $row, $col, $color));
            }
        }

        return [$middlegame, $endgame];
    }

    public static function interpolateScore(int $phase, int $middlegame, int $endgame): int {
        return intdiv(($middlegame * $phase) + ($endgame * (256 - $phase)), 256);
    }

    public static function scalePhaseTo256(int $phase): int {
        return intdiv($phase * 256, Tables::totalPhase());
    }
}
