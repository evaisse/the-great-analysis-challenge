<?php

namespace Chess\Eval;
require_once __DIR__ . '/../constants.php';

/**
 * King safety evaluation
 */
class KingSafety {
    private const PAWN_SHIELD_BONUS = 20;
    private const OPEN_FILE_PENALTY = -30;
    private const SEMI_OPEN_FILE_PENALTY = -15;
    private const ATTACKER_WEIGHT = 10;

    public static function evaluate(\Chess\Board $board): int {
        $score = 0;
        
        $score += self::evaluateKingSafety($board, \CHESS_WHITE);
        $score -= self::evaluateKingSafety($board, \CHESS_BLACK);
        
        return $score;
    }

    private static function evaluateKingSafety(\Chess\Board $board, int $color): int {
        $kingSquare = self::findKing($board, $color);
        if ($kingSquare === null) {
            return 0;
        }
        
        $score = 0;
        
        $score += self::evaluatePawnShield($board, $kingSquare, $color);
        $score += self::evaluateOpenFiles($board, $kingSquare, $color);
        $score -= self::evaluateAttackers($board, $kingSquare, $color);
        
        return $score;
    }

    private static function findKing(\Chess\Board $board, int $color): ?int {
        for ($square = 0; $square < 64; $square++) {
            $row = intval($square / 8);
            $col = $square % 8;
            [$piece, $pieceColor] = $board->get_piece($row, $col);
            
            if ($pieceColor === $color && $piece === \CHESS_KING) {
                return $square;
            }
        }
        return null;
    }

    private static function evaluatePawnShield(\Chess\Board $board, int $kingSquare, int $color): int {
        $kingFile = $kingSquare % 8;
        $kingRank = intval($kingSquare / 8);
        $shieldCount = 0;
        
        $shieldRanks = $color === \CHESS_WHITE
            ? [$kingRank + 1, $kingRank + 2]
            : [max(0, $kingRank - 1), max(0, $kingRank - 2)];
        
        for ($file = max(0, $kingFile - 1); $file <= min(7, $kingFile + 1); $file++) {
            foreach ($shieldRanks as $rank) {
                if ($rank < 8 && $rank >= 0) {
                    [$piece, $pieceColor] = $board->get_piece($rank, $file);
                    
                    if ($pieceColor === $color && $piece === \CHESS_PAWN) {
                        $shieldCount++;
                    }
                }
            }
        }
        
        return $shieldCount * self::PAWN_SHIELD_BONUS;
    }

    private static function evaluateOpenFiles(\Chess\Board $board, int $kingSquare, int $color): int {
        $kingFile = $kingSquare % 8;
        $penalty = 0;
        
        for ($file = max(0, $kingFile - 1); $file <= min(7, $kingFile + 1); $file++) {
            [$ownPawns, $enemyPawns] = self::countPawnsOnFile($board, $file, $color);
            
            if ($ownPawns === 0 && $enemyPawns === 0) {
                $penalty += self::OPEN_FILE_PENALTY;
            } elseif ($ownPawns === 0) {
                $penalty += self::SEMI_OPEN_FILE_PENALTY;
            }
        }
        
        return $penalty;
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

    private static function evaluateAttackers(\Chess\Board $board, int $kingSquare, int $color): int {
        $kingFile = $kingSquare % 8;
        $kingRank = intval($kingSquare / 8);
        $attackerCount = 0;
        
        $adjacentSquares = [
            [-1, -1], [-1, 0], [-1, 1],
            [0, -1],           [0, 1],
            [1, -1],  [1, 0],  [1, 1],
        ];
        
        foreach ($adjacentSquares as [$dr, $df]) {
            $newRank = $kingRank + $dr;
            $newFile = $kingFile + $df;
            
            if ($newRank >= 0 && $newRank < 8 && $newFile >= 0 && $newFile < 8) {
                $targetSquare = $newRank * 8 + $newFile;
                if (self::isAttackedByEnemy($board, $targetSquare, $color)) {
                    $attackerCount++;
                }
            }
        }
        
        return $attackerCount * self::ATTACKER_WEIGHT;
    }

    private static function isAttackedByEnemy(\Chess\Board $board, int $square, int $color): bool {
        $targetRow = intval($square / 8);
        $targetCol = $square % 8;
        
        for ($attackerSquare = 0; $attackerSquare < 64; $attackerSquare++) {
            $row = intval($attackerSquare / 8);
            $col = $attackerSquare % 8;
            [$piece, $pieceColor] = $board->get_piece($row, $col);
            
            if ($pieceColor !== $color && $piece !== \CHESS_EMPTY) {
                if (self::canAttack($attackerSquare, $square, $piece, $pieceColor)) {
                    return true;
                }
            }
        }
        
        return false;
    }

    private static function canAttack(int $from, int $to, int $pieceType, int $color): bool {
        $fromRank = intval($from / 8);
        $fromFile = $from % 8;
        $toRank = intval($to / 8);
        $toFile = $to % 8;
        $rankDiff = abs($toRank - $fromRank);
        $fileDiff = abs($toFile - $fromFile);
        
        if ($pieceType === \CHESS_PAWN) {
            $forward = $color === \CHESS_WHITE ? 1 : -1;
            return ($toRank - $fromRank === $forward) && $fileDiff === 1;
        }
        
        return match($pieceType) {
            \CHESS_KNIGHT => ($rankDiff === 2 && $fileDiff === 1) || ($rankDiff === 1 && $fileDiff === 2),
            \CHESS_KING => $rankDiff <= 1 && $fileDiff <= 1,
            default => false,
        };
    }
}
