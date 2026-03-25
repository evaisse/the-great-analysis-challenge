<?php

namespace Chess\Eval;

use Chess\Board;
use Chess\MoveGenerator;

require_once __DIR__ . '/Tables.php';
require_once __DIR__ . '/Tapered.php';
require_once __DIR__ . '/Mobility.php';
require_once __DIR__ . '/PawnStructure.php';
require_once __DIR__ . '/KingSafety.php';
require_once __DIR__ . '/Positional.php';

final class RichEvaluator {
    private Board $board;
    private MoveGenerator $moveGenerator;

    public function __construct(Board $board, MoveGenerator $moveGenerator) {
        $this->board = $board;
        $this->moveGenerator = $moveGenerator;
    }

    public function evaluate(): int {
        if ($this->moveGenerator->is_checkmate()) {
            return $this->board->current_player === CHESS_WHITE ? -100000 : 100000;
        }
        if ($this->moveGenerator->is_stalemate()) {
            return 0;
        }

        $phase = Tapered::scalePhaseTo256(Tapered::computePhase($this->board));
        [$middlegamePst, $endgamePst] = Tapered::evaluateMaterialAndPst($this->board);
        $mobility = Mobility::evaluate($this->board);
        $pawnStructure = PawnStructure::evaluate($this->board);
        $kingSafety = KingSafety::evaluate($this->board, $this->moveGenerator);
        $positional = Positional::evaluate($this->board);

        $middlegame = $middlegamePst + $mobility + $pawnStructure + $kingSafety + $positional;
        $endgame = $endgamePst + intdiv($mobility * 3, 4) + $pawnStructure + intdiv($kingSafety, 2) + $positional;

        return Tapered::interpolateScore($phase, $middlegame, $endgame);
    }
}
