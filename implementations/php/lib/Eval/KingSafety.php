<?php

namespace Chess\Eval;

use Chess\Board;
use Chess\MoveGenerator;

final class KingSafety {
    public static function evaluate(Board $board, MoveGenerator $moveGenerator): int {
        $whiteKing = self::findKing($board, CHESS_WHITE);
        $blackKing = self::findKing($board, CHESS_BLACK);

        if ($whiteKing === null || $blackKing === null) {
            return 0;
        }

        $whiteScore = self::evaluateKing($board, $moveGenerator, CHESS_WHITE, $whiteKing);
        $blackScore = self::evaluateKing($board, $moveGenerator, CHESS_BLACK, $blackKing);

        return $whiteScore - $blackScore;
    }

    private static function evaluateKing(Board $board, MoveGenerator $moveGenerator, int $color, array $king): int {
        [$row, $col] = $king;
        $score = 0;

        $shieldRow = $color === CHESS_WHITE ? $row - 1 : $row + 1;
        if ($shieldRow >= 0 && $shieldRow < 8) {
            foreach ([-1, 0, 1] as $deltaCol) {
                $shieldCol = $col + $deltaCol;
                if ($shieldCol < 0 || $shieldCol >= 8) {
                    continue;
                }
                [$piece, $pieceColor] = $board->get_piece($shieldRow, $shieldCol);
                if ($piece === CHESS_PAWN && $pieceColor === $color) {
                    $score += 15;
                }
            }
        }

        foreach ([-1, 0, 1] as $deltaCol) {
            $file = $col + $deltaCol;
            if ($file < 0 || $file >= 8) {
                continue;
            }

            $friendlyPawns = self::countPawnsOnFile($board, $file, $color);
            $enemyPawns = self::countPawnsOnFile($board, $file, 1 - $color);
            if ($friendlyPawns === 0 && $enemyPawns === 0) {
                $score -= 30;
            } elseif ($friendlyPawns === 0) {
                $score -= 18;
            }
        }

        foreach (self::kingZoneSquares($row, $col) as [$zoneRow, $zoneCol]) {
            if ($moveGenerator->is_square_attacked($zoneRow, $zoneCol, 1 - $color)) {
                $score -= 8;
            }
        }

        return $score;
    }

    private static function findKing(Board $board, int $color): ?array {
        for ($row = 0; $row < 8; $row++) {
            for ($col = 0; $col < 8; $col++) {
                [$piece, $pieceColor] = $board->get_piece($row, $col);
                if ($piece === CHESS_KING && $pieceColor === $color) {
                    return [$row, $col];
                }
            }
        }
        return null;
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

    private static function kingZoneSquares(int $row, int $col): array {
        $squares = [[$row, $col]];
        for ($deltaRow = -1; $deltaRow <= 1; $deltaRow++) {
            for ($deltaCol = -1; $deltaCol <= 1; $deltaCol++) {
                $targetRow = $row + $deltaRow;
                $targetCol = $col + $deltaCol;
                if ($targetRow < 0 || $targetRow >= 8 || $targetCol < 0 || $targetCol >= 8) {
                    continue;
                }
                $squares[] = [$targetRow, $targetCol];
            }
        }
        return $squares;
    }
}
