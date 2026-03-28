<?php

namespace Chess\Eval;

use Chess\Board;

final class Positional {
    public static function evaluate(Board $board): int {
        $score = 0;
        $bishopCounts = [CHESS_WHITE => 0, CHESS_BLACK => 0];

        for ($row = 0; $row < 8; $row++) {
            for ($col = 0; $col < 8; $col++) {
                [$piece, $color] = $board->get_piece($row, $col);
                if ($piece === CHESS_EMPTY) {
                    continue;
                }

                if ($piece === CHESS_BISHOP) {
                    $bishopCounts[$color]++;
                }

                if ($piece === CHESS_ROOK) {
                    $score += self::evaluateRook($board, $color, $row, $col);
                }

                if ($piece === CHESS_KNIGHT) {
                    $score += self::evaluateKnightOutpost($board, $color, $row, $col);
                }
            }
        }

        if ($bishopCounts[CHESS_WHITE] >= 2) {
            $score += Tables::bishopPairBonus();
        }
        if ($bishopCounts[CHESS_BLACK] >= 2) {
            $score -= Tables::bishopPairBonus();
        }

        return $score;
    }

    private static function evaluateRook(Board $board, int $color, int $row, int $col): int {
        $sign = $color === CHESS_WHITE ? 1 : -1;
        $score = 0;

        $friendlyPawns = self::countPawnsOnFile($board, $col, $color);
        $enemyPawns = self::countPawnsOnFile($board, $col, 1 - $color);
        if ($friendlyPawns === 0 && $enemyPawns === 0) {
            $score += Tables::rookOpenFileBonus();
        } elseif ($friendlyPawns === 0) {
            $score += Tables::rookSemiOpenFileBonus();
        }

        $targetRow = $color === CHESS_WHITE ? 1 : 6;
        if ($row === $targetRow) {
            $score += Tables::rookSeventhBonus();
        }

        return $sign * $score;
    }

    private static function evaluateKnightOutpost(Board $board, int $color, int $row, int $col): int {
        $sign = $color === CHESS_WHITE ? 1 : -1;
        $supportRow = $color === CHESS_WHITE ? $row + 1 : $row - 1;
        $enemyAdvanceDirection = $color === CHESS_WHITE ? 1 : -1;

        if ($row < 2 || $row > 5) {
            return 0;
        }

        $supported = false;
        if ($supportRow >= 0 && $supportRow < 8) {
            foreach ([-1, 1] as $deltaCol) {
                $supportCol = $col + $deltaCol;
                if ($supportCol < 0 || $supportCol >= 8) {
                    continue;
                }
                [$piece, $pieceColor] = $board->get_piece($supportRow, $supportCol);
                if ($piece === CHESS_PAWN && $pieceColor === $color) {
                    $supported = true;
                    break;
                }
            }
        }

        if (!$supported) {
            return 0;
        }

        foreach ([-1, 1] as $deltaCol) {
            $enemyFile = $col + $deltaCol;
            if ($enemyFile < 0 || $enemyFile >= 8) {
                continue;
            }
            $enemyRow = $row + $enemyAdvanceDirection;
            while ($enemyRow >= 0 && $enemyRow < 8) {
                [$piece, $pieceColor] = $board->get_piece($enemyRow, $enemyFile);
                if ($piece === CHESS_PAWN && $pieceColor === 1 - $color) {
                    return 0;
                }
                $enemyRow += $enemyAdvanceDirection;
            }
        }

        return $sign * Tables::knightOutpostBonus();
    }

    private static function countPawnsOnFile(Board $board, int $file, int $color): int {
        $count = 0;
        for ($row = 0; $row < 8; $row++) {
            [$piece, $pieceColor] = $board->get_piece($row, $file);
            if ($piece === CHESS_PAWN && $pieceColor === $color) {
                $count++;
            }
        }
        return $count;
    }
}
