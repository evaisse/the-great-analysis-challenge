<?php

namespace Chess\Eval;

require_once __DIR__ . '/../constants.php';

/**
 * Piece mobility evaluation
 */
class Mobility {
    private const KNIGHT_MOBILITY = [-15, -5, 0, 5, 10, 15, 20, 22, 24];
    private const BISHOP_MOBILITY = [-20, -10, 0, 5, 10, 15, 18, 21, 24, 26, 28, 30, 32, 34];
    private const ROOK_MOBILITY = [-15, -8, 0, 3, 6, 9, 12, 14, 16, 18, 20, 22, 24, 26, 28];
    private const QUEEN_MOBILITY = [
        -10, -5, 0, 2, 4, 6, 8, 10, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 22, 23, 23, 24, 24, 25, 25, 26, 26
    ];

    public static function evaluate(\Chess\Board $board): int {
        $score = 0;
        
        for ($square = 0; $square < 64; $square++) {
            $row = intval($square / 8);
            $col = $square % 8;
            [$piece, $color] = $board->get_piece($row, $col);
            
            if ($piece === \CHESS_EMPTY) {
                continue;
            }
            
            $mobility = match($piece) {
                \CHESS_KNIGHT => self::countKnightMobility($board, $square),
                \CHESS_BISHOP => self::countBishopMobility($board, $square, $color),
                \CHESS_ROOK => self::countRookMobility($board, $square, $color),
                \CHESS_QUEEN => self::countQueenMobility($board, $square, $color),
                default => null,
            };
            
            if ($mobility !== null) {
                $bonus = self::getMobilityBonus($piece, $mobility);
                $score += $color === \CHESS_WHITE ? $bonus : -$bonus;
            }
        }
        
        return $score;
    }

    private static function countKnightMobility(\Chess\Board $board, int $square): int {
        $offsets = [
            [-2, -1], [-2, 1], [-1, -2], [-1, 2],
            [1, -2], [1, 2], [2, -1], [2, 1],
        ];
        
        $rank = intval($square / 8);
        $file = $square % 8;
        $count = 0;
        
        foreach ($offsets as [$dr, $df]) {
            $newRank = $rank + $dr;
            $newFile = $file + $df;
            
            if ($newRank >= 0 && $newRank < 8 && $newFile >= 0 && $newFile < 8) {
                [$targetPiece, $targetColor] = $board->get_piece($newRank, $newFile);
                [$srcPiece, $srcColor] = $board->get_piece($rank, $file);
                
                if ($targetPiece === \CHESS_EMPTY || $targetColor !== $srcColor) {
                    $count++;
                }
            }
        }
        
        return $count;
    }

    private static function countBishopMobility(\Chess\Board $board, int $square, int $color): int {
        return self::countSlidingMobility($board, $square, $color, [
            [1, 1], [1, -1], [-1, 1], [-1, -1]
        ]);
    }

    private static function countRookMobility(\Chess\Board $board, int $square, int $color): int {
        return self::countSlidingMobility($board, $square, $color, [
            [0, 1], [0, -1], [1, 0], [-1, 0]
        ]);
    }

    private static function countQueenMobility(\Chess\Board $board, int $square, int $color): int {
        return self::countSlidingMobility($board, $square, $color, [
            [0, 1], [0, -1], [1, 0], [-1, 0],
            [1, 1], [1, -1], [-1, 1], [-1, -1],
        ]);
    }

    private static function countSlidingMobility(\Chess\Board $board, int $square, int $color, array $directions): int {
        $rank = intval($square / 8);
        $file = $square % 8;
        $count = 0;
        
        foreach ($directions as [$dr, $df]) {
            $currentRank = $rank + $dr;
            $currentFile = $file + $df;
            
            while ($currentRank >= 0 && $currentRank < 8 && $currentFile >= 0 && $currentFile < 8) {
                [$targetPiece, $targetColor] = $board->get_piece($currentRank, $currentFile);
                
                if ($targetPiece !== \CHESS_EMPTY) {
                    if ($targetColor !== $color) {
                        $count++;
                    }
                    break;
                }
                
                $count++;
                $currentRank += $dr;
                $currentFile += $df;
            }
        }
        
        return $count;
    }

    private static function getMobilityBonus(int $pieceType, int $mobility): int {
        return match($pieceType) {
            \CHESS_KNIGHT => self::KNIGHT_MOBILITY[min($mobility, 8)],
            \CHESS_BISHOP => self::BISHOP_MOBILITY[min($mobility, 13)],
            \CHESS_ROOK => self::ROOK_MOBILITY[min($mobility, 14)],
            \CHESS_QUEEN => self::QUEEN_MOBILITY[min($mobility, 27)],
            default => 0,
        };
    }
}
