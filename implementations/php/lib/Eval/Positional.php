<?php

namespace Chess\Eval;
require_once __DIR__ . '/../constants.php';

/**
 * Positional evaluation (bishop pair, rook placement, knight outposts)
 */
class Positional {
    private const BISHOP_PAIR_BONUS = 30;
    private const ROOK_OPEN_FILE_BONUS = 25;
    private const ROOK_SEMI_OPEN_FILE_BONUS = 15;
    private const ROOK_SEVENTH_RANK_BONUS = 20;
    private const KNIGHT_OUTPOST_BONUS = 20;

    public static function evaluate(\Chess\Board $board): int {
        $score = 0;
        
        $score += self::evaluateColor($board, \CHESS_WHITE);
        $score -= self::evaluateColor($board, \CHESS_BLACK);
        
        return $score;
    }

    private static function evaluateColor(\Chess\Board $board, int $color): int {
        $score = 0;
        
        if (self::hasBishopPair($board, $color)) {
            $score += self::BISHOP_PAIR_BONUS;
        }
        
        for ($square = 0; $square < 64; $square++) {
            $row = intval($square / 8);
            $col = $square % 8;
            [$piece, $pieceColor] = $board->get_piece($row, $col);
            
            if ($pieceColor === $color) {
                $score += match($piece) {
                    \CHESS_ROOK => self::evaluateRook($board, $square, $color),
                    \CHESS_KNIGHT => self::evaluateKnight($board, $square, $color),
                    default => 0,
                };
            }
        }
        
        return $score;
    }

    private static function hasBishopPair(\Chess\Board $board, int $color): bool {
        $bishopCount = 0;
        
        for ($square = 0; $square < 64; $square++) {
            $row = intval($square / 8);
            $col = $square % 8;
            [$piece, $pieceColor] = $board->get_piece($row, $col);
            
            if ($pieceColor === $color && $piece === \CHESS_BISHOP) {
                $bishopCount++;
            }
        }
        
        return $bishopCount >= 2;
    }

    private static function evaluateRook(\Chess\Board $board, int $square, int $color): int {
        $file = $square % 8;
        $rank = intval($square / 8);
        $bonus = 0;
        
        [$ownPawns, $enemyPawns] = self::countPawnsOnFile($board, $file, $color);
        
        if ($ownPawns === 0 && $enemyPawns === 0) {
            $bonus += self::ROOK_OPEN_FILE_BONUS;
        } elseif ($ownPawns === 0) {
            $bonus += self::ROOK_SEMI_OPEN_FILE_BONUS;
        }
        
        $seventhRank = $color === \CHESS_WHITE ? 6 : 1;
        if ($rank === $seventhRank) {
            $bonus += self::ROOK_SEVENTH_RANK_BONUS;
        }
        
        return $bonus;
    }

    private static function evaluateKnight(\Chess\Board $board, int $square, int $color): int {
        return self::isOutpost($board, $square, $color) ? self::KNIGHT_OUTPOST_BONUS : 0;
    }

    private static function isOutpost(\Chess\Board $board, int $square, int $color): bool {
        $file = $square % 8;
        $rank = intval($square / 8);
        
        $protectedByPawn = self::isProtectedByPawn($board, $square, $color);
        if (!$protectedByPawn) {
            return false;
        }
        
        $cannotBeAttacked = !self::canBeAttackedByEnemyPawn($board, $square, $file, $rank, $color);
        
        return $protectedByPawn && $cannotBeAttacked;
    }

    private static function isProtectedByPawn(\Chess\Board $board, int $square, int $color): bool {
        $file = $square % 8;
        $rank = intval($square / 8);
        
        $behindRank = $color === \CHESS_WHITE
            ? max(0, $rank - 1)
            : min(7, $rank + 1);
        
        foreach ([max(0, $file - 1), min(7, $file + 1)] as $adjacentFile) {
            if ($adjacentFile !== $file) {
                [$piece, $pieceColor] = $board->get_piece($behindRank, $adjacentFile);
                
                if ($pieceColor === $color && $piece === \CHESS_PAWN) {
                    return true;
                }
            }
        }
        
        return false;
    }

    private static function canBeAttackedByEnemyPawn(\Chess\Board $board, int $square, int $file, int $rank, int $color): bool {
        $aheadRanks = $color === \CHESS_WHITE
            ? range($rank + 1, 7)
            : range(0, $rank - 1);
        
        foreach ($aheadRanks as $checkRank) {
            foreach ([max(0, $file - 1), min(7, $file + 1)] as $adjacentFile) {
                if ($adjacentFile !== $file) {
                    [$piece, $pieceColor] = $board->get_piece($checkRank, $adjacentFile);
                    
                    if ($pieceColor !== $color && $piece === \CHESS_PAWN) {
                        return true;
                    }
                }
            }
        }
        
        return false;
    }

    private static function countPawnsOnFile(\Chess\Board $board, int $file, int $color): array {
        $ownPawns = 0;
        $enemyPawns = 0;
        
        for ($rank = 0; $rank < 8; $rank++) {
            [$piece, $pieceColor] = $board->get_piece($rank, $file);
            
            if ($piece === \CHESS_PAWN) {
                if ($pieceColor === $color) {
                    $ownPawns++;
                } else {
                    $enemyPawns++;
                }
            }
        }
        
        return [$ownPawns, $enemyPawns];
    }
}
