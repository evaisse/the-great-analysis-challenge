<?php

namespace Chess;

require_once __DIR__ . '/Types.php';
require_once __DIR__ . '/Board.php';
require_once __DIR__ . '/MoveGenerator.php';

/**
 * AI with minimax and alpha-beta pruning
 */
class AI {
    private Board $board;
    private MoveGenerator $move_gen;
    
    public function __construct(Board $board, MoveGenerator $move_gen) {
        $this->board = $board;
        $this->move_gen = $move_gen;
    }
    
    public function find_best_move(int $depth): ?array {
        $start_time = microtime(true);
        $moves = $this->move_gen->generate_moves();
        
        if (empty($moves)) {
            return null;
        }
        
        $best_move = null;
        $best_eval = PHP_INT_MIN;
        $alpha = PHP_INT_MIN;
        $beta = PHP_INT_MAX;
        
        foreach ($moves as $move) {
            $this->board->make_move($move);
            $eval = -$this->minimax($depth - 1, -$beta, -$alpha, false);
            $this->board->undo_move();
            
            if ($eval > $best_eval) {
                $best_eval = $eval;
                $best_move = $move;
            }
            
            $alpha = max($alpha, $eval);
            if ($beta <= $alpha) {
                break;
            }
        }
        
        $end_time = microtime(true);
        $time_ms = round(($end_time - $start_time) * 1000);
        
        return [$best_move, $best_eval, $time_ms];
    }
    
    private function minimax(int $depth, float|int $alpha, float|int $beta, bool $maximizing): float|int {
        if ($depth === 0) {
            return $this->evaluate();
        }
        
        if ($this->move_gen->is_checkmate()) {
            return -100000;
        }
        
        if ($this->move_gen->is_stalemate()) {
            return 0;
        }
        
        $moves = $this->move_gen->generate_moves();
        
        if ($maximizing) {
            $max_eval = PHP_INT_MIN;
            foreach ($moves as $move) {
                $this->board->make_move($move);
                $eval = $this->minimax($depth - 1, $alpha, $beta, false);
                $this->board->undo_move();
                
                $max_eval = max($max_eval, $eval);
                $alpha = max($alpha, $eval);
                if ($beta <= $alpha) {
                    break;
                }
            }
            return $max_eval;
        } else {
            $min_eval = PHP_INT_MAX;
            foreach ($moves as $move) {
                $this->board->make_move($move);
                $eval = $this->minimax($depth - 1, $alpha, $beta, true);
                $this->board->undo_move();
                
                $min_eval = min($min_eval, $eval);
                $beta = min($beta, $eval);
                if ($beta <= $alpha) {
                    break;
                }
            }
            return $min_eval;
        }
    }
    
    public function evaluate(): int {
        $score = 0;
        
        // Material evaluation
        for ($row = 0; $row < 8; $row++) {
            for ($col = 0; $col < 8; $col++) {
                [$piece, $color] = $this->board->get_piece($row, $col);
                
                if ($piece === CHESS_EMPTY) {
                    continue;
                }
                
                $value = CHESS_PIECE_VALUES[$piece];
                
                // Position bonuses
                if ($piece === CHESS_PAWN) {
                    // Pawn advancement bonus
                    $rank_from_start = $color === CHESS_WHITE ? (6 - $row) : ($row - 1);
                    $value += $rank_from_start * 5;
                }
                
                // Center control bonus
                if (($row === 3 || $row === 4) && ($col === 3 || $col === 4)) {
                    if ($piece === CHESS_PAWN) {
                        $value += 10;
                    } else {
                        $value += 10;
                    }
                }
                
                // Apply color
                if ($color === $this->board->current_player) {
                    $score += $value;
                } else {
                    $score -= $value;
                }
            }
        }
        
        return $score;
    }
}
