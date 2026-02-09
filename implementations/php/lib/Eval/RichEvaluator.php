<?php

namespace Chess\Eval;

require_once __DIR__ . '/Tables.php';
require_once __DIR__ . '/Tapered.php';
require_once __DIR__ . '/Mobility.php';
require_once __DIR__ . '/PawnStructure.php';
require_once __DIR__ . '/KingSafety.php';
require_once __DIR__ . '/Positional.php';
require_once __DIR__ . '/../constants.php';

/**
 * Rich evaluation function with tapered eval, mobility, pawn structure, king safety, and positional bonuses
 */
class RichEvaluator {
    public function evaluate(\Chess\Board $board): int {
        $phase = $this->computePhase($board);
        
        $mgScore = $this->evaluatePhase($board, true);
        $egScore = $this->evaluatePhase($board, false);
        
        $taperedScore = Tapered::interpolate($mgScore, $egScore, $phase);
        
        $mobilityScore = Mobility::evaluate($board);
        $pawnScore = PawnStructure::evaluate($board);
        $kingScore = KingSafety::evaluate($board);
        $positionalScore = Positional::evaluate($board);
        
        return $taperedScore + $mobilityScore + $pawnScore + $kingScore + $positionalScore;
    }

    private function computePhase(\Chess\Board $board): int {
        $phase = 0;
        
        for ($square = 0; $square < 64; $square++) {
            $row = intval($square / 8);
            $col = $square % 8;
            [$piece, $color] = $board->get_piece($row, $col);
            
            if ($piece !== \CHESS_EMPTY) {
                $phase += match($piece) {
                    \CHESS_KNIGHT => 1,
                    \CHESS_BISHOP => 1,
                    \CHESS_ROOK => 2,
                    \CHESS_QUEEN => 4,
                    default => 0,
                };
            }
        }
        
        return min($phase, 24);
    }

    private function evaluatePhase(\Chess\Board $board, bool $middlegame): int {
        $score = 0;
        
        for ($square = 0; $square < 64; $square++) {
            $row = intval($square / 8);
            $col = $square % 8;
            [$piece, $color] = $board->get_piece($row, $col);
            
            if ($piece === \CHESS_EMPTY) {
                continue;
            }
            
            $value = \CHESS_PIECE_VALUES[$piece];
            $positionBonus = $middlegame
                ? Tables::getMiddlegameBonus($square, $piece, $color)
                : Tables::getEndgameBonus($square, $piece, $color);
            
            $totalValue = $value + $positionBonus;
            $score += $color === \CHESS_WHITE ? $totalValue : -$totalValue;
        }
        
        return $score;
    }
}
