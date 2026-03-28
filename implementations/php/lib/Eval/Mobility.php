<?php

namespace Chess\Eval;

use Chess\Board;

final class Mobility {
    public static function evaluate(Board $board): int {
        $score = 0;

        for ($row = 0; $row < 8; $row++) {
            for ($col = 0; $col < 8; $col++) {
                [$piece, $color] = $board->get_piece($row, $col);
                if (!in_array($piece, [CHESS_KNIGHT, CHESS_BISHOP, CHESS_ROOK, CHESS_QUEEN], true)) {
                    continue;
                }

                $mobility = match ($piece) {
                    CHESS_KNIGHT => self::knightMobility($board, $row, $col, $color),
                    CHESS_BISHOP => self::slidingMobility($board, $row, $col, $color, [[-1, -1], [-1, 1], [1, -1], [1, 1]]),
                    CHESS_ROOK => self::slidingMobility($board, $row, $col, $color, [[-1, 0], [1, 0], [0, -1], [0, 1]]),
                    CHESS_QUEEN => self::slidingMobility($board, $row, $col, $color, [[-1, -1], [-1, 1], [1, -1], [1, 1], [-1, 0], [1, 0], [0, -1], [0, 1]]),
                    default => 0,
                };

                $bonus = Tables::mobilityBonus($piece, $mobility);
                $score += $color === CHESS_WHITE ? $bonus : -$bonus;
            }
        }

        return $score;
    }

    private static function knightMobility(Board $board, int $row, int $col, int $color): int {
        $mobility = 0;
        foreach ([[-2, -1], [-2, 1], [-1, -2], [-1, 2], [1, -2], [1, 2], [2, -1], [2, 1]] as [$dRow, $dCol]) {
            $targetRow = $row + $dRow;
            $targetCol = $col + $dCol;
            if ($targetRow < 0 || $targetRow >= 8 || $targetCol < 0 || $targetCol >= 8) {
                continue;
            }
            [$targetPiece, $targetColor] = $board->get_piece($targetRow, $targetCol);
            if ($targetPiece === CHESS_EMPTY || $targetColor !== $color) {
                $mobility++;
            }
        }
        return $mobility;
    }

    private static function slidingMobility(Board $board, int $row, int $col, int $color, array $directions): int {
        $mobility = 0;
        foreach ($directions as [$dRow, $dCol]) {
            $targetRow = $row + $dRow;
            $targetCol = $col + $dCol;
            while ($targetRow >= 0 && $targetRow < 8 && $targetCol >= 0 && $targetCol < 8) {
                [$targetPiece, $targetColor] = $board->get_piece($targetRow, $targetCol);
                if ($targetPiece === CHESS_EMPTY) {
                    $mobility++;
                } else {
                    if ($targetColor !== $color) {
                        $mobility++;
                    }
                    break;
                }
                $targetRow += $dRow;
                $targetCol += $dCol;
            }
        }
        return $mobility;
    }
}
