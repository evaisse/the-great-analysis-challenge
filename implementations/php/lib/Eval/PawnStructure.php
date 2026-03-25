<?php

namespace Chess\Eval;

use Chess\Board;

final class PawnStructure {
    public static function evaluate(Board $board): int {
        $whitePawns = self::collectPawns($board, CHESS_WHITE);
        $blackPawns = self::collectPawns($board, CHESS_BLACK);

        return self::evaluateColor($board, CHESS_WHITE, $whitePawns, $blackPawns)
            - self::evaluateColor($board, CHESS_BLACK, $blackPawns, $whitePawns);
    }

    private static function evaluateColor(Board $board, int $color, array $pawns, array $enemyPawns): int {
        $score = 0;
        $fileCounts = array_fill(0, 8, 0);
        foreach ($pawns as [$row, $col]) {
            $fileCounts[$col]++;
        }

        foreach ($pawns as [$row, $col]) {
            if ($fileCounts[$col] > 1) {
                $score -= 20;
            }

            $hasAdjacentPawn = ($col > 0 && $fileCounts[$col - 1] > 0) || ($col < 7 && $fileCounts[$col + 1] > 0);
            if (!$hasAdjacentPawn) {
                $score -= 15;
            }

            if (self::isPassedPawn($color, $row, $col, $enemyPawns)) {
                $score += Tables::passedPawnBonusByRank(self::rankFromWhitePerspective($color, $row));
            }

            if (self::isPawnChain($board, $color, $row, $col)) {
                $score += 10;
            }

            if (self::isConnectedPawn($board, $color, $row, $col)) {
                $score += 5;
            }
        }

        return $score;
    }

    private static function collectPawns(Board $board, int $color): array {
        $pawns = [];
        for ($row = 0; $row < 8; $row++) {
            for ($col = 0; $col < 8; $col++) {
                [$piece, $pieceColor] = $board->get_piece($row, $col);
                if ($piece === CHESS_PAWN && $pieceColor === $color) {
                    $pawns[] = [$row, $col];
                }
            }
        }
        return $pawns;
    }

    private static function isPassedPawn(int $color, int $row, int $col, array $enemyPawns): bool {
        foreach ($enemyPawns as [$enemyRow, $enemyCol]) {
            if (abs($enemyCol - $col) > 1) {
                continue;
            }
            if ($color === CHESS_WHITE && $enemyRow < $row) {
                return false;
            }
            if ($color === CHESS_BLACK && $enemyRow > $row) {
                return false;
            }
        }

        return true;
    }

    private static function isPawnChain(Board $board, int $color, int $row, int $col): bool {
        $supportRow = $color === CHESS_WHITE ? $row + 1 : $row - 1;
        if ($supportRow < 0 || $supportRow >= 8) {
            return false;
        }

        foreach ([-1, 1] as $deltaCol) {
            $supportCol = $col + $deltaCol;
            if ($supportCol < 0 || $supportCol >= 8) {
                continue;
            }
            [$piece, $pieceColor] = $board->get_piece($supportRow, $supportCol);
            if ($piece === CHESS_PAWN && $pieceColor === $color) {
                return true;
            }
        }

        return false;
    }

    private static function isConnectedPawn(Board $board, int $color, int $row, int $col): bool {
        foreach ([-1, 1] as $deltaCol) {
            $adjacentCol = $col + $deltaCol;
            if ($adjacentCol < 0 || $adjacentCol >= 8) {
                continue;
            }
            [$piece, $pieceColor] = $board->get_piece($row, $adjacentCol);
            if ($piece === CHESS_PAWN && $pieceColor === $color) {
                return true;
            }
        }

        return false;
    }

    private static function rankFromWhitePerspective(int $color, int $row): int {
        return $color === CHESS_WHITE ? 7 - $row : $row;
    }
}
