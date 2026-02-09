<?php

namespace Chess\Eval;
require_once __DIR__ . '/../constants.php';

/**
 * Pawn structure evaluation
 */
class PawnStructure {
    private const PASSED_PAWN_BONUS = [0, 10, 20, 40, 60, 90, 120, 0];
    private const DOUBLED_PAWN_PENALTY = -20;
    private const ISOLATED_PAWN_PENALTY = -15;
    private const BACKWARD_PAWN_PENALTY = -10;
    private const CONNECTED_PAWN_BONUS = 5;
    private const PAWN_CHAIN_BONUS = 10;

    public static function evaluate(\Chess\Board $board): int {
        $score = 0;
        
        $score += self::evaluateColor($board, \CHESS_WHITE);
        $score -= self::evaluateColor($board, \CHESS_BLACK);
        
        return $score;
    }

    private static function evaluateColor(\Chess\Board $board, int $color): int {
        $score = 0;
        $pawnFiles = array_fill(0, 8, 0);
        $pawnPositions = [];
        
        for ($square = 0; $square < 64; $square++) {
            $row = intval($square / 8);
            $col = $square % 8;
            [$piece, $pieceColor] = $board->get_piece($row, $col);
            
            if ($pieceColor === $color && $piece === \CHESS_PAWN) {
                $file = $col;
                $rank = $row;
                $pawnFiles[$file]++;
                $pawnPositions[] = [$square, $rank, $file];
            }
        }
        
        foreach ($pawnPositions as [$square, $rank, $file]) {
            if ($pawnFiles[$file] > 1) {
                $score += self::DOUBLED_PAWN_PENALTY;
            }
            
            if (self::isIsolated($file, $pawnFiles)) {
                $score += self::ISOLATED_PAWN_PENALTY;
            }
            
            if (self::isPassed($board, $square, $rank, $file, $color)) {
                $bonusRank = $color === \CHESS_WHITE ? $rank : 7 - $rank;
                $score += self::PASSED_PAWN_BONUS[$bonusRank];
            }
            
            if (self::isConnected($board, $square, $file, $color)) {
                $score += self::CONNECTED_PAWN_BONUS;
            }
            
            if (self::isInChain($board, $square, $rank, $file, $color)) {
                $score += self::PAWN_CHAIN_BONUS;
            }
            
            if (self::isBackward($board, $square, $rank, $file, $color, $pawnFiles)) {
                $score += self::BACKWARD_PAWN_PENALTY;
            }
        }
        
        return $score;
    }

    private static function isIsolated(int $file, array $pawnFiles): bool {
        $leftFile = $file > 0 ? $pawnFiles[$file - 1] : 0;
        $rightFile = $file < 7 ? $pawnFiles[$file + 1] : 0;
        return $leftFile === 0 && $rightFile === 0;
    }

    private static function isPassed(\Chess\Board $board, int $square, int $rank, int $file, int $color): bool {
        if ($color === \CHESS_WHITE) {
            $startRank = $rank + 1;
            $endRank = 8;
        } else {
            $startRank = 0;
            $endRank = $rank;
        }
        
        for ($checkFile = max(0, $file - 1); $checkFile <= min(7, $file + 1); $checkFile++) {
            for ($currentRank = $startRank; 
                 $color === \CHESS_WHITE ? $currentRank < $endRank : $currentRank < $endRank;
                 $currentRank++) {
                
                $checkRow = $currentRank;
                $checkCol = $checkFile;
                
                [$piece, $pieceColor] = $board->get_piece($checkRow, $checkCol);
                
                if ($piece === \CHESS_PAWN && $pieceColor !== $color) {
                    return false;
                }
            }
        }
        
        return true;
    }

    private static function isConnected(\Chess\Board $board, int $square, int $file, int $color): bool {
        $rank = intval($square / 8);
        
        foreach ([max(0, $file - 1), min(7, $file + 1)] as $adjacentFile) {
            if ($adjacentFile !== $file) {
                [$piece, $pieceColor] = $board->get_piece($rank, $adjacentFile);
                
                if ($pieceColor === $color && $piece === \CHESS_PAWN) {
                    return true;
                }
            }
        }
        
        return false;
    }

    private static function isInChain(\Chess\Board $board, int $square, int $rank, int $file, int $color): bool {
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

    private static function isBackward(\Chess\Board $board, int $square, int $rank, int $file, int $color, array $pawnFiles): bool {
        $leftFile = max(0, $file - 1);
        $rightFile = min(7, $file + 1);
        
        foreach ([$leftFile, $rightFile] as $adjacentFile) {
            if ($adjacentFile !== $file && $pawnFiles[$adjacentFile] > 0) {
                for ($checkSquare = 0; $checkSquare < 64; $checkSquare++) {
                    $checkRow = intval($checkSquare / 8);
                    $checkCol = $checkSquare % 8;
                    
                    [$piece, $pieceColor] = $board->get_piece($checkRow, $checkCol);
                    
                    if ($pieceColor === $color && $piece === \CHESS_PAWN) {
                        $checkFile = $checkCol;
                        $checkRank = $checkRow;
                        
                        if ($checkFile === $adjacentFile) {
                            $isAhead = $color === \CHESS_WHITE
                                ? $checkRank > $rank
                                : $checkRank < $rank;
                            
                            if ($isAhead) {
                                return false;
                            }
                        }
                    }
                }
            }
        }
        
        return false;
    }
}
