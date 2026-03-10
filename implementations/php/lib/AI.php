<?php

namespace Chess;

require_once __DIR__ . '/Types.php';
require_once __DIR__ . '/Board.php';
require_once __DIR__ . '/MoveGenerator.php';

/**
 * AI with minimax and alpha-beta pruning
 */
class AI {
    private const TT_FLAG_EXACT = 0;
    private const TT_FLAG_LOWER = 1;
    private const TT_FLAG_UPPER = 2;
    private const SCORE_INF = 1000000000;
    private const SCORE_MATE = 1000000;

    private Board $board;
    private MoveGenerator $move_gen;
    private array $tt = [];
    private int $tt_max_entries = 200000;
    private ?float $search_deadline = null;
    private bool $stop_requested = false;
    private int $node_count = 0;
    
    public function __construct(Board $board, MoveGenerator $move_gen) {
        $this->board = $board;
        $this->move_gen = $move_gen;
    }
    
    public function find_best_move(int $depth): ?array {
        $result = $this->search_with_iterative_deepening($depth, null);
        if ($result === null) {
            return null;
        }

        return [$result['move'], $result['score'], $result['time_ms']];
    }

    public function find_best_move_timed(int $time_limit_ms, int $max_depth = 64): ?array {
        $max_depth = max(1, $max_depth);
        $time_limit_ms = max(1, $time_limit_ms);
        return $this->search_with_iterative_deepening($max_depth, $time_limit_ms);
    }

    public function request_stop(): void {
        $this->stop_requested = true;
    }

    public function clear_stop_request(): void {
        $this->stop_requested = false;
    }

    private function search_with_iterative_deepening(int $max_depth, ?int $time_limit_ms): ?array {
        $start_time = microtime(true);
        $this->clear_stop_request();
        $this->search_deadline = $time_limit_ms !== null ? ($start_time + ($time_limit_ms / 1000.0)) : null;
        $this->node_count = 0;

        $root_moves = $this->move_gen->generate_moves();
        if (empty($root_moves)) {
            $this->search_deadline = null;
            return null;
        }

        $best_move = null;
        $best_score = -self::SCORE_INF;
        $best_depth = 0;

        $tt_entry = $this->tt_lookup($this->board->zobrist_hash);
        $root_hint = $tt_entry['best'] ?? null;
        $ordered_root = $this->order_moves($root_moves, $root_hint);

        for ($depth = 1; $depth <= $max_depth; $depth++) {
            if ($this->should_stop_search()) {
                break;
            }

            $iteration = $this->search_root($depth, $ordered_root);
            if ($iteration === null) {
                break;
            }

            $best_move = $iteration['move'];
            $best_score = $iteration['score'];
            $best_depth = $depth;
            $ordered_root = $this->order_moves($root_moves, $iteration['best_sig']);
        }

        if ($best_move === null) {
            $best_move = $ordered_root[0] ?? null;
            if ($best_move === null) {
                $this->search_deadline = null;
                return null;
            }
            $best_score = 0;
        }

        $elapsed_ms = (int) round((microtime(true) - $start_time) * 1000);
        $timed_out = $time_limit_ms !== null && $this->search_deadline !== null && microtime(true) >= $this->search_deadline;
        $this->search_deadline = null;

        return [
            'move' => $best_move,
            'score' => $best_score,
            'time_ms' => $elapsed_ms,
            'depth' => $best_depth,
            'timed_out' => $timed_out,
            'nodes' => $this->node_count,
        ];
    }

    private function search_root(int $depth, array $moves): ?array {
        $alpha = -self::SCORE_INF;
        $beta = self::SCORE_INF;
        $best_score = -self::SCORE_INF;
        $best_move = null;
        $best_sig = null;

        foreach ($moves as $move) {
            if ($this->should_stop_search()) {
                return null;
            }

            $this->board->make_move($move);
            $child_score = $this->negamax($depth - 1, -$beta, -$alpha, 1);
            $this->board->undo_move();

            if ($child_score === null) {
                return null;
            }

            $score = -$child_score;
            if ($score > $best_score) {
                $best_score = $score;
                $best_move = $move;
                $best_sig = $this->move_signature($move);
            }

            if ($score > $alpha) {
                $alpha = $score;
            }
            if ($alpha >= $beta) {
                break;
            }
        }

        if ($best_move === null) {
            return null;
        }

        $this->tt_store(
            $this->board->zobrist_hash,
            $depth,
            $best_score,
            self::TT_FLAG_EXACT,
            $best_sig
        );

        return ['move' => $best_move, 'score' => $best_score, 'best_sig' => $best_sig];
    }

    private function negamax(int $depth, int $alpha, int $beta, int $ply): ?int {
        $this->node_count++;
        if (($this->node_count & 2047) === 0 && $this->should_stop_search()) {
            return null;
        }

        if ($this->should_stop_search()) {
            return null;
        }

        if ($depth === 0) {
            return $this->evaluate();
        }

        if ($this->move_gen->is_checkmate()) {
            return -self::SCORE_MATE + $ply;
        }

        if ($this->move_gen->is_stalemate()) {
            return 0;
        }

        $alpha_original = $alpha;
        $beta_original = $beta;
        $hash = $this->board->zobrist_hash;
        $tt_entry = $this->tt_lookup($hash);
        $best_hint = null;

        if ($tt_entry !== null) {
            $best_hint = $tt_entry['best'] ?? null;
            if ($tt_entry['depth'] >= $depth) {
                if ($tt_entry['flag'] === self::TT_FLAG_EXACT) {
                    return $tt_entry['score'];
                }

                if ($tt_entry['flag'] === self::TT_FLAG_LOWER) {
                    $alpha = max($alpha, $tt_entry['score']);
                } elseif ($tt_entry['flag'] === self::TT_FLAG_UPPER) {
                    $beta = min($beta, $tt_entry['score']);
                }

                if ($alpha >= $beta) {
                    return $tt_entry['score'];
                }
            }
        }

        $moves = $this->move_gen->generate_moves();
        if (empty($moves)) {
            if ($this->move_gen->is_in_check()) {
                return -self::SCORE_MATE + $ply;
            }
            return 0;
        }

        $moves = $this->order_moves($moves, $best_hint);
        $best_score = -self::SCORE_INF;
        $best_sig = null;

        foreach ($moves as $move) {
            $this->board->make_move($move);
            $child_score = $this->negamax($depth - 1, -$beta, -$alpha, $ply + 1);
            $this->board->undo_move();

            if ($child_score === null) {
                return null;
            }

            $score = -$child_score;
            if ($score > $best_score) {
                $best_score = $score;
                $best_sig = $this->move_signature($move);
            }

            if ($score > $alpha) {
                $alpha = $score;
            }

            if ($alpha >= $beta) {
                break;
            }
        }

        $flag = self::TT_FLAG_EXACT;
        if ($best_score <= $alpha_original) {
            $flag = self::TT_FLAG_UPPER;
        } elseif ($best_score >= $beta_original) {
            $flag = self::TT_FLAG_LOWER;
        }

        $this->tt_store($hash, $depth, $best_score, $flag, $best_sig);
        return $best_score;
    }

    private function should_stop_search(): bool {
        if ($this->stop_requested) {
            return true;
        }
        if ($this->search_deadline === null) {
            return false;
        }
        return microtime(true) >= $this->search_deadline;
    }

    private function tt_lookup(int $hash): ?array {
        $key = $this->tt_key($hash);
        return $this->tt[$key] ?? null;
    }

    private function tt_store(int $hash, int $depth, int $score, int $flag, ?array $best_sig): void {
        $key = $this->tt_key($hash);
        $existing = $this->tt[$key] ?? null;
        if ($existing !== null && $existing['depth'] > $depth) {
            return;
        }

        if (count($this->tt) >= $this->tt_max_entries) {
            // Simple bounded table policy to keep memory use deterministic.
            $this->tt = [];
        }

        $this->tt[$key] = [
            'depth' => $depth,
            'score' => $score,
            'flag' => $flag,
            'best' => $best_sig,
        ];
    }

    private function tt_key(int $hash): string {
        return (string) sprintf('%u', $hash);
    }

    private function order_moves(array $moves, ?array $tt_best_sig): array {
        $scored = [];
        foreach ($moves as $idx => $move) {
            $score = $this->move_order_score($move);
            if ($tt_best_sig !== null && $this->move_matches_signature($move, $tt_best_sig)) {
                $score += 1000000;
            }
            $scored[] = ['idx' => $idx, 'score' => $score, 'move' => $move];
        }

        usort($scored, function(array $a, array $b): int {
            if ($a['score'] === $b['score']) {
                return $a['idx'] <=> $b['idx'];
            }
            return $b['score'] <=> $a['score'];
        });

        $ordered = [];
        foreach ($scored as $entry) {
            $ordered[] = $entry['move'];
        }
        return $ordered;
    }

    private function move_order_score(Move $move): int {
        $score = 0;

        [$moving_piece, $_] = $this->board->get_piece($move->from_row, $move->from_col);
        [$target_piece, $_target_color] = $this->board->get_piece($move->to_row, $move->to_col);

        if ($move->is_en_passant) {
            $score += 5000;
        } elseif ($target_piece !== CHESS_EMPTY) {
            $score += 5000 + CHESS_PIECE_VALUES[$target_piece] - intdiv(CHESS_PIECE_VALUES[$moving_piece], 10);
        }

        if ($move->promotion !== null) {
            $score += 9000 + CHESS_PIECE_VALUES[$move->promotion];
        }

        if ($move->is_castling) {
            $score += 50;
        }

        return $score;
    }

    private function move_signature(Move $move): array {
        return [
            'from_row' => $move->from_row,
            'from_col' => $move->from_col,
            'to_row' => $move->to_row,
            'to_col' => $move->to_col,
            'promotion' => $move->promotion,
            'is_castling' => $move->is_castling,
            'is_en_passant' => $move->is_en_passant,
        ];
    }

    private function move_matches_signature(Move $move, array $sig): bool {
        return $move->from_row === $sig['from_row']
            && $move->from_col === $sig['from_col']
            && $move->to_row === $sig['to_row']
            && $move->to_col === $sig['to_col']
            && $move->promotion === $sig['promotion']
            && $move->is_castling === $sig['is_castling']
            && $move->is_en_passant === $sig['is_en_passant'];
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
