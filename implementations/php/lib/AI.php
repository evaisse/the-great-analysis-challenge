<?php

namespace Chess;

require_once __DIR__ . '/Types.php';
require_once __DIR__ . '/Board.php';
require_once __DIR__ . '/MoveGenerator.php';

/**
 * AI with iterative deepening + negamax alpha-beta + transposition table.
 */
class AI {
    private const MATE_VALUE = 100000;
    private const INFINITY_SCORE = 1000000000;

    private Board $board;
    private MoveGenerator $move_gen;
    private array $tt = [];
    private ?float $deadline = null;
    private bool $timed_out = false;
    private bool $stop_requested = false;
    private int $nodes_visited = 0;
    private int $eval_calls = 0;

    public function __construct(Board $board, MoveGenerator $move_gen) {
        $this->board = $board;
        $this->move_gen = $move_gen;
    }

    public function request_stop(): void {
        $this->stop_requested = true;
    }

    /**
     * Backward-compatible API used by `ai <depth>`.
     *
     * @return array{0:Move,1:int,2:int}|null
     */
    public function find_best_move(int $depth): ?array {
        [$move, $score, , $time_ms] = $this->search($depth, 0);
        if ($move === null) {
            return null;
        }
        return [$move, $score, $time_ms];
    }

    /**
     * @return array{0:?Move,1:int,2:int,3:int,4:bool,5:int,6:int}
     */
    public function search(int $max_depth, int $movetime_ms = 0): array {
        if ($max_depth < 1) {
            $max_depth = 1;
        } elseif ($max_depth > 5) {
            $max_depth = 5;
        }

        $moves = $this->move_gen->generate_moves();
        if (empty($moves)) {
            return [null, 0, 0, 0, false, 0, 0];
        }

        $this->timed_out = false;
        $this->stop_requested = false;
        $this->nodes_visited = 0;
        $this->eval_calls = 0;
        $start = microtime(true);
        $this->deadline = $movetime_ms > 0 ? ($start + ($movetime_ms / 1000.0)) : null;

        $best_move = $moves[0];
        $best_score = $this->evaluate();
        $completed_depth = 0;

        for ($depth = 1; $depth <= $max_depth; $depth++) {
            [$score, $move, $complete] = $this->search_root($depth);
            if (!$complete) {
                break;
            }
            if ($move !== null) {
                $best_move = $move;
                $best_score = $score;
                $completed_depth = $depth;
            }
        }

        if ($completed_depth === 0) {
            $completed_depth = 1;
        }

        $elapsed_ms = (int) round((microtime(true) - $start) * 1000);
        return [$best_move, $best_score, $completed_depth, $elapsed_ms, $this->timed_out, $this->nodes_visited, $this->eval_calls];
    }

    /**
     * @return array{0:int,1:?Move,2:bool}
     */
    private function search_root(int $depth): array {
        if ($this->time_exceeded()) {
            return [0, null, false];
        }
        $this->nodes_visited++;

        $moves = $this->move_gen->generate_moves();
        if (empty($moves)) {
            return [0, null, true];
        }

        $entry = $this->tt[(string) $this->board->zobrist_hash] ?? null;
        $tt_move = $entry['best_move'] ?? null;
        $ordered = $this->order_moves($moves, $tt_move);

        $alpha = -self::INFINITY_SCORE;
        $beta = self::INFINITY_SCORE;
        $best_score = -self::INFINITY_SCORE;
        $best_move = $ordered[0] ?? null;

        foreach ($ordered as $move) {
            if ($this->time_exceeded()) {
                return [0, null, false];
            }
            $this->board->make_move($move);
            [$score, , $ok] = $this->negamax($depth - 1, -$beta, -$alpha);
            $this->board->undo_move();

            if (!$ok) {
                return [0, null, false];
            }

            $score = -$score;
            if ($score > $best_score) {
                $best_score = $score;
                $best_move = $move;
            }
            if ($score > $alpha) {
                $alpha = $score;
            }
        }

        return [$best_score, $best_move, true];
    }

    /**
     * @return array{0:int,1:?Move,2:bool}
     */
    private function negamax(int $depth, int $alpha, int $beta): array {
        if ($this->time_exceeded()) {
            return [0, null, false];
        }
        $this->nodes_visited++;

        $original_alpha = $alpha;
        $key = (string) $this->board->zobrist_hash;
        $best_from_tt = null;
        $entry = $this->tt[$key] ?? null;
        if ($entry !== null && $entry['depth'] >= $depth) {
            if ($entry['flag'] === 'exact') {
                return [$entry['score'], $entry['best_move'], true];
            }
            if ($entry['flag'] === 'lower') {
                $alpha = max($alpha, $entry['score']);
            } elseif ($entry['flag'] === 'upper') {
                $beta = min($beta, $entry['score']);
            }
            if ($alpha >= $beta) {
                return [$entry['score'], $entry['best_move'], true];
            }
            $best_from_tt = $entry['best_move'];
        }

        if ($depth === 0) {
            return [$this->evaluate(), null, true];
        }

        if ($this->move_gen->is_checkmate()) {
            return [-self::MATE_VALUE + $depth, null, true];
        }
        if ($this->move_gen->is_stalemate()) {
            return [0, null, true];
        }

        $moves = $this->move_gen->generate_moves();
        if (empty($moves)) {
            return [0, null, true];
        }

        $ordered = $this->order_moves($moves, $best_from_tt);
        $best_score = -self::INFINITY_SCORE;
        $best_move = $ordered[0] ?? null;

        foreach ($ordered as $move) {
            if ($this->time_exceeded()) {
                return [0, null, false];
            }
            $this->board->make_move($move);
            [$score, , $ok] = $this->negamax($depth - 1, -$beta, -$alpha);
            $this->board->undo_move();

            if (!$ok) {
                return [0, null, false];
            }
            $score = -$score;

            if ($score > $best_score) {
                $best_score = $score;
                $best_move = $move;
            }
            if ($score > $alpha) {
                $alpha = $score;
            }
            if ($alpha >= $beta) {
                break;
            }
        }

        $flag = 'exact';
        if ($best_score <= $original_alpha) {
            $flag = 'upper';
        } elseif ($best_score >= $beta) {
            $flag = 'lower';
        }

        $this->tt[$key] = [
            'depth' => $depth,
            'score' => $best_score,
            'flag' => $flag,
            'best_move' => $best_move,
        ];

        return [$best_score, $best_move, true];
    }

    /**
     * @param Move[] $moves
     * @return Move[]
     */
    private function order_moves(array $moves, ?Move $tt_move = null): array {
        usort($moves, function (Move $a, Move $b) use ($tt_move): int {
            return $this->move_ordering_score($b, $tt_move) <=> $this->move_ordering_score($a, $tt_move);
        });
        return $moves;
    }

    private function move_ordering_score(Move $move, ?Move $tt_move): int {
        $score = 0;
        if ($tt_move !== null && $this->same_move($move, $tt_move)) {
            $score += 100000;
        }

        [$target_piece, ] = $this->board->get_piece($move->to_row, $move->to_col);
        if ($target_piece !== CHESS_EMPTY) {
            $score += 10000 + CHESS_PIECE_VALUES[$target_piece];
        }
        if ($move->promotion !== null) {
            $score += 9000 + CHESS_PIECE_VALUES[$move->promotion];
        }
        if ($move->is_castling) {
            $score += 100;
        }
        return $score;
    }

    private function same_move(?Move $a, ?Move $b): bool {
        if ($a === null || $b === null) {
            return false;
        }
        return $a->from_row === $b->from_row &&
            $a->from_col === $b->from_col &&
            $a->to_row === $b->to_row &&
            $a->to_col === $b->to_col &&
            $a->promotion === $b->promotion;
    }

    private function time_exceeded(): bool {
        if ($this->stop_requested) {
            $this->timed_out = true;
            return true;
        }
        if ($this->deadline === null) {
            return false;
        }
        if (microtime(true) >= $this->deadline) {
            $this->timed_out = true;
            return true;
        }
        return false;
    }
    
    public function evaluate(): int {
        $this->eval_calls++;
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
                    $value += 10;
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
