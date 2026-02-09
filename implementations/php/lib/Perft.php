<?php

namespace Chess;

require_once __DIR__ . '/Board.php';
require_once __DIR__ . '/MoveGenerator.php';

/**
 * Performance test (perft) - counts leaf nodes at a given depth
 */
class Perft {
    private Board $board;
    private MoveGenerator $move_gen;
    
    public function __construct(Board $board, MoveGenerator $move_gen) {
        $this->board = $board;
        $this->move_gen = $move_gen;
    }
    
    public function perft(int $depth): int {
        if ($depth === 0) {
            return 1;
        }
        
        $moves = $this->move_gen->generate_moves();
        
        if ($depth === 1) {
            return count($moves);
        }
        
        $nodes = 0;
        foreach ($moves as $move) {
            $this->board->make_move($move);
            $nodes += $this->perft($depth - 1);
            $this->board->undo_move();
        }
        
        return $nodes;
    }
}
