<?php

require_once __DIR__ . '/lib/Board.php';
require_once __DIR__ . '/lib/FenParser.php';
require_once __DIR__ . '/lib/MoveGenerator.php';
require_once __DIR__ . '/lib/Zobrist.php';

use Chess\Board;
use Chess\FenParser;
use Chess\Move;
use Chess\MoveGenerator;
use Chess\Zobrist;

$scenarios = [
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    'rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3',
    'r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1',
    '4k3/6P1/8/8/8/8/8/4K3 w - - 0 1',
];

function state_from_fen(string $fen): array {
    $board = new Board();
    $fen_parser = new FenParser($board);
    if (!$fen_parser->load_fen($fen)) {
        throw new RuntimeException("Invalid FEN: $fen");
    }
    $board->game_history = [];
    $board->position_history = [];
    $board->irreversible_history = [];
    $board->zobrist_hash = Zobrist::getInstance()->compute_hash($board);
    return [$board, new MoveGenerator($board), $fen_parser];
}

function choose_move(array $legal_moves, int $seed, int $run, int $worker, int $sequence, int $ply): Move {
    $special_moves = array_values(array_filter(
        $legal_moves,
        fn(Move $move): bool => $move->is_castling || $move->is_en_passant || $move->promotion !== null
    ));
    if (count($special_moves) > 0 && (($run + $worker + $sequence + $ply) % 3) === 0) {
        return $special_moves[0];
    }

    $selector = $seed + ($run * 17) + ($worker * 31) + ($sequence * 43) + ($ply * 59);
    return $legal_moves[$selector % count($legal_moves)];
}

function hash_hex(int $hash): string {
    return sprintf('%016x', $hash);
}

$seed = 12345;
$workers = 4;
$runs = 50;
$sequences_per_worker = 6;
$plies_per_sequence = 6;

for ($run = 0; $run < $runs; $run++) {
    for ($worker = 0; $worker < $workers; $worker++) {
        for ($sequence = 0; $sequence < $sequences_per_worker; $sequence++) {
            $scenario_index = ($run + $worker + $sequence) % count($scenarios);
            [$board, $move_gen, $fen_parser] = state_from_fen($scenarios[$scenario_index]);
            $baseline_fen = $fen_parser->export_fen();
            $baseline_hash = hash_hex($board->zobrist_hash);
            $applied_moves = 0;

            for ($ply = 0; $ply < $plies_per_sequence; $ply++) {
                $legal_moves = $move_gen->generate_moves();
                usort($legal_moves, fn(Move $left, Move $right): int => strcmp($left->to_string(), $right->to_string()));
                if (count($legal_moves) === 0) {
                    echo "empty run=$run worker=$worker sequence=$sequence ply=$ply scenario=$scenario_index fen=$baseline_fen\n";
                    exit(0);
                }

                $selected = choose_move($legal_moves, $seed, $run, $worker, $sequence, $ply);
                $before_fen = $fen_parser->export_fen();
                $before_hash = hash_hex($board->zobrist_hash);
                $move_str = $selected->to_string();

                $board->make_move($selected);
                $applied_moves++;
                $after_fen = $fen_parser->export_fen();
                $after_hash = hash_hex($board->zobrist_hash);

                [$reloaded_board, $_reload_moves, $reloaded_parser] = state_from_fen($after_fen);
                $reloaded_hash = hash_hex($reloaded_board->zobrist_hash);
                if ($reloaded_parser->export_fen() !== $after_fen || $reloaded_hash !== $after_hash) {
                    echo "reload-error run=$run worker=$worker sequence=$sequence ply=$ply scenario=$scenario_index move=$move_str before_fen=$before_fen after_fen=$after_fen before_hash=$before_hash after_hash=$after_hash reloaded_hash=$reloaded_hash\n";
                    exit(0);
                }
            }

            for ($ply = 0; $ply < $applied_moves; $ply++) {
                if (!$board->undo_move()) {
                    echo "undo-missing run=$run worker=$worker sequence=$sequence ply=$ply scenario=$scenario_index\n";
                    exit(0);
                }
            }

            $restored_fen = $fen_parser->export_fen();
            $restored_hash = hash_hex($board->zobrist_hash);
            if ($restored_fen !== $baseline_fen || $restored_hash !== $baseline_hash) {
                echo "undo-error run=$run worker=$worker sequence=$sequence scenario=$scenario_index baseline_fen=$baseline_fen restored_fen=$restored_fen baseline_hash=$baseline_hash restored_hash=$restored_hash\n";
                exit(0);
            }
        }
    }
}

echo "ok\n";
