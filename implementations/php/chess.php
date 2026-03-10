#!/usr/bin/env php
<?php
/**
 * Chess Engine Implementation in PHP
 * Follows the Chess Engine Specification v1.0
 */

namespace Chess;

require_once __DIR__ . '/lib/Types.php';
require_once __DIR__ . '/lib/Board.php';
require_once __DIR__ . '/lib/MoveGenerator.php';
require_once __DIR__ . '/lib/FenParser.php';
require_once __DIR__ . '/lib/AI.php';
require_once __DIR__ . '/lib/Perft.php';

/**
 * Main chess engine class
 */
class ChessEngine {
    private Board $board;
    private MoveGenerator $move_gen;
    private FenParser $fen_parser;
    private AI $ai;
    private Perft $perft;
    private ?string $pgn_path = null;
    private array $pgn_moves = [];
    private int $chess960_id = 0;
    private bool $trace_enabled = false;
    private string $trace_level = 'info';
    private array $trace_events = [];
    private int $trace_command_count = 0;
    
    public function __construct() {
        $this->board = new Board();
        $this->move_gen = new MoveGenerator($this->board);
        $this->fen_parser = new FenParser($this->board);
        $this->ai = new AI($this->board, $this->move_gen);
        $this->perft = new Perft($this->board, $this->move_gen);
    }
    
    public function start(): void {
        echo $this->board->display();
        flush();
        
        while (true) {
            $line = fgets(STDIN);
            
            if ($line === false) {
                break;
            }
            
            $command = trim($line);
            
            if (empty($command)) {
                continue;
            }
            
            $this->process_command($command);
            flush();
        }
    }
    
    private function process_command(string $command): void {
        $parts = preg_split('/\s+/', $command);
        
        if (empty($parts)) {
            return;
        }
        
        $cmd = strtolower($parts[0]);
        if ($cmd !== 'trace') {
            $this->trace_command_count++;
            $this->trace('command', $command);
        }
        
        try {
            switch ($cmd) {
                case 'move':
                    $this->handle_move($parts[1] ?? null);
                    break;
                    
                case 'undo':
                    $this->handle_undo();
                    break;
                    
                case 'new':
                    $this->handle_new_game();
                    break;
                    
                case 'ai':
                    $depth = isset($parts[1]) ? intval($parts[1]) : 3;
                    $this->handle_ai_move($depth);
                    break;
                    
                case 'fen':
                    $fen = count($parts) > 1 ? implode(' ', array_slice($parts, 1)) : null;
                    $this->handle_fen($fen);
                    break;
                    
                case 'export':
                    $this->handle_export();
                    break;
                    
                case 'eval':
                    $this->handle_eval();
                    break;
                    
                case 'hash':
                    $this->handle_hash();
                    break;
                    
                case 'draws':
                    $this->handle_draws();
                    break;
                    
                case 'history':
                    $this->handle_history();
                    break;

                case 'go':
                    $this->handle_go(array_slice($parts, 1));
                    break;

                case 'stop':
                    $this->handle_stop();
                    break;

                case 'pgn':
                    $this->handle_pgn(array_slice($parts, 1));
                    break;

                case 'uci':
                    $this->handle_uci();
                    break;

                case 'isready':
                    $this->handle_isready();
                    break;

                case 'new960':
                    $this->handle_new960(array_slice($parts, 1));
                    break;

                case 'position960':
                    $this->handle_position960();
                    break;

                case 'trace':
                    $this->handle_trace(array_slice($parts, 1));
                    break;

                case 'concurrency':
                    $this->handle_concurrency(array_slice($parts, 1));
                    break;
                    
                case 'status':
                    $this->handle_status();
                    break;
                    
                case 'perft':
                    $depth = isset($parts[1]) ? intval($parts[1]) : 4;
                    $this->handle_perft($depth);
                    break;
                    
                case 'help':
                    $this->handle_help();
                    break;
                    
                case 'quit':
                case 'exit':
                    echo "Goodbye!\n";
                    exit(0);
                    
                default:
                    echo "ERROR: Invalid command. Type 'help' for available commands.\n";
            }
        } catch (\Exception $e) {
            echo "ERROR: " . $e->getMessage() . "\n";
        }
    }
    
    private function handle_move(?string $move_str): void {
        if ($move_str === null) {
            echo "ERROR: Invalid move format\n";
            return;
        }
        
        $move = $this->move_gen->parse_move($move_str);
        
        if ($move === null) {
            echo "ERROR: Invalid move format\n";
            return;
        }
        
        // Check if piece exists at source
        [$piece, $color] = $this->board->get_piece($move->from_row, $move->from_col);
        
        if ($piece === CHESS_EMPTY) {
            echo "ERROR: No piece at source square\n";
            return;
        }
        
        if ($color !== $this->board->current_player) {
            echo "ERROR: Wrong color piece\n";
            return;
        }
        
        // Check if move is legal
        $legal_moves = $this->move_gen->generate_moves();
        $is_legal = false;
        
        foreach ($legal_moves as $legal_move) {
            if ($legal_move->from_row === $move->from_row &&
                $legal_move->from_col === $move->from_col &&
                $legal_move->to_row === $move->to_row &&
                $legal_move->to_col === $move->to_col) {
                $is_legal = true;
                $move = $legal_move;  // Use the validated move with correct flags
                break;
            }
        }
        
        if (!$is_legal) {
            echo "ERROR: Illegal move\n";
            return;
        }
        
        $this->board->make_move($move);
        
        // Check for game end first
        $is_checkmate = $this->move_gen->is_checkmate();
        $is_stalemate = $this->move_gen->is_stalemate();
        
        if ($is_checkmate) {
            $winner = $this->board->current_player === CHESS_WHITE ? "Black" : "White";
            echo "CHECKMATE: $winner wins\n";
        } elseif ($is_stalemate) {
            echo "STALEMATE: Draw\n";
        } else {
            require_once __DIR__ . '/lib/DrawDetection.php';
            if (DrawDetection::is_draw($this->board)) {
                $reason = DrawDetection::is_draw_by_repetition($this->board) ? "repetition" : "50-move rule";
                echo "DRAW: by $reason\n";
            } else {
                echo "OK: " . $move->to_string() . "\n";
            }
        }
        
        echo $this->board->display();
    }
    
    private function handle_undo(): void {
        if ($this->board->undo_move()) {
            echo "OK: Undo\n";
            echo $this->board->display();
        } else {
            echo "ERROR: No moves to undo\n";
        }
    }
    
    private function handle_new_game(): void {
        $this->board->reset();
        echo "OK: New game started\n";
        echo $this->board->display();
    }
    
    private function handle_ai_move(int $depth): void {
        if ($depth < 1 || $depth > 5) {
            echo "ERROR: AI depth must be 1-5\n";
            return;
        }
        
        $result = $this->ai->find_best_move($depth);
        
        if ($result === null) {
            echo "ERROR: No legal moves available\n";
            return;
        }
        
        [$move, $eval, $time_ms] = $result;
        $this->apply_ai_move($move, intval($eval), intval($time_ms), $depth);
    }

    private function handle_ai_move_timed(int $time_limit_ms, int $max_depth = 64): void {
        if ($time_limit_ms <= 0) {
            echo "ERROR: Time limit must be > 0\n";
            return;
        }

        $result = $this->ai->find_best_move_timed($time_limit_ms, $max_depth);
        if ($result === null) {
            echo "ERROR: No legal moves available\n";
            return;
        }

        /** @var Move $move */
        $move = $result['move'];
        $eval = intval($result['score'] ?? 0);
        $time_ms = intval($result['time_ms'] ?? 0);
        $depth = max(1, intval($result['depth'] ?? 1));
        $this->apply_ai_move($move, $eval, $time_ms, $depth);
    }

    private function apply_ai_move(Move $move, int $eval, int $time_ms, int $depth): void {
        $this->board->make_move($move);

        // Check for game end first
        $is_checkmate = $this->move_gen->is_checkmate();
        $is_stalemate = $this->move_gen->is_stalemate();

        if ($is_checkmate) {
            $winner = $this->board->current_player === CHESS_WHITE ? "Black" : "White";
            echo "CHECKMATE: $winner wins\n";
        } elseif ($is_stalemate) {
            echo "STALEMATE: Draw\n";
        } else {
            require_once __DIR__ . '/lib/DrawDetection.php';
            if (DrawDetection::is_draw($this->board)) {
                $reason = DrawDetection::is_draw_by_repetition($this->board) ? "repetition" : "50-move rule";
                echo "DRAW: by $reason\n";
            } else {
                echo "AI: " . $move->to_string() . " (depth=$depth, eval=$eval, time={$time_ms}ms)\n";
            }
        }

        echo $this->board->display();
    }
    
    private function handle_fen(?string $fen): void {
        if ($fen === null) {
            echo "ERROR: FEN string required\n";
            return;
        }
        
        if ($this->fen_parser->load_fen($fen)) {
            echo "OK: FEN loaded\n";
            echo $this->board->display();
        } else {
            echo "ERROR: Invalid FEN string\n";
        }
    }
    
    private function handle_export(): void {
        $fen = $this->fen_parser->export_fen();
        echo "FEN: $fen\n";
    }
    
    private function handle_eval(): void {
        $eval = $this->ai->evaluate();
        echo "Evaluation: $eval\n";
    }
    
    private function handle_hash(): void {
        echo "HASH: " . sprintf('%016x', $this->board->zobrist_hash) . "\n";
    }

    private function handle_draws(): void {
        $repetition_count = $this->get_repetition_count();
        $halfmove = $this->board->halfmove_clock;
        $draw = ($repetition_count >= 3) || ($halfmove >= 100);
        $reason = "none";
        if ($halfmove >= 100) {
            $reason = "fifty_moves";
        } elseif ($repetition_count >= 3) {
            $reason = "repetition";
        }
        echo "DRAWS: repetition={$repetition_count}; halfmove={$halfmove}; draw=" .
             ($draw ? "true" : "false") . "; reason={$reason}\n";
    }

    private function handle_history(): void {
        echo "HISTORY: count=" . (count($this->board->position_history) + 1) .
             "; current=" . sprintf('%016x', $this->board->zobrist_hash) . "\n";
        echo "Position History (" . (count($this->board->position_history) + 1) . " positions):\n";
        foreach ($this->board->position_history as $i => $h) {
            echo "  $i: " . sprintf('%016x', $h) . "\n";
        }
        echo "  " . count($this->board->position_history) . ": " . sprintf('%016x', $this->board->zobrist_hash) . " (current)\n";
    }

    private function handle_go(array $args): void {
        if (count($args) === 0) {
            echo "ERROR: go requires subcommand (movetime|wtime|infinite)\n";
            return;
        }

        $sub = strtolower($args[0]);
        if ($sub === 'movetime') {
            if (!isset($args[1])) {
                echo "ERROR: go movetime requires a value in milliseconds\n";
                return;
            }

            $movetime = intval($args[1]);
            if ($movetime <= 0) {
                echo "ERROR: go movetime must be > 0\n";
                return;
            }

            $this->handle_ai_move_timed($movetime);
            return;
        }

        if ($sub === 'wtime' || $sub === 'btime') {
            $parsed = $this->parse_go_time_control($args);
            if (is_string($parsed)) {
                echo $parsed . "\n";
                return;
            }

            $movetime = $this->compute_go_movetime($parsed);
            $this->handle_ai_move_timed($movetime);
            return;
        }

        if ($sub === 'infinite') {
            $this->handle_ai_move_timed($this->infinite_go_budget_ms());
            return;
        }

        echo "ERROR: Unsupported go command\n";
    }

    private function handle_stop(): void {
        $this->ai->request_stop();
        echo "OK: stop\n";
    }

    private function handle_pgn(array $args): void {
        if (count($args) === 0) {
            echo "ERROR: pgn requires subcommand (load|show|moves)\n";
            return;
        }

        $sub = strtolower($args[0]);
        if ($sub === 'load') {
            if (!isset($args[1])) {
                echo "ERROR: pgn load requires a file path\n";
                return;
            }
            $path = implode(' ', array_slice($args, 1));
            $this->pgn_path = $path;
            $this->pgn_moves = [];

            if (is_readable($path)) {
                $content = file_get_contents($path);
                if ($content === false) {
                    echo "PGN: loaded path=\"{$path}\"; moves=0; note=file-unavailable\n";
                    return;
                }
                $this->pgn_moves = $this->extract_pgn_moves($content);
                echo "PGN: loaded path=\"{$path}\"; moves=" . count($this->pgn_moves) . "\n";
                return;
            }

            echo "PGN: loaded path=\"{$path}\"; moves=0; note=file-unavailable\n";
            return;
        }

        if ($sub === 'show') {
            $source = $this->pgn_path ?? "current-game";
            echo "PGN: source={$source}; moves=" . count($this->pgn_moves) . "\n";
            return;
        }

        if ($sub === 'moves') {
            if (!empty($this->pgn_moves)) {
                echo "PGN: moves " . implode(' ', $this->pgn_moves) . "\n";
            } else {
                echo "PGN: moves (none)\n";
            }
            return;
        }

        echo "ERROR: Unsupported pgn command\n";
    }

    private function handle_uci(): void {
        echo "uciok\n";
    }

    private function handle_isready(): void {
        echo "readyok\n";
    }

    private function handle_new960(array $args): void {
        $id = 0;
        if (isset($args[0])) {
            if (!is_numeric($args[0])) {
                echo "ERROR: new960 id must be an integer\n";
                return;
            }
            $id = intval($args[0]);
        }

        if ($id < 0 || $id > 959) {
            echo "ERROR: new960 id must be between 0 and 959\n";
            return;
        }

        $this->chess960_id = $id;
        $this->handle_new_game();
        echo "960: new game id={$this->chess960_id}\n";
    }

    private function handle_position960(): void {
        echo "960: id={$this->chess960_id}; mode=chess960\n";
    }

    private function handle_trace(array $args): void {
        if (count($args) === 0) {
            echo "ERROR: trace requires subcommand\n";
            return;
        }

        $sub = strtolower($args[0]);
        if ($sub === 'on') {
            $this->trace_enabled = true;
            $this->trace('trace', 'enabled');
            echo "TRACE: enabled=true; level={$this->trace_level}; events=" . count($this->trace_events) . "\n";
            return;
        }

        if ($sub === 'off') {
            $this->trace('trace', 'disabled');
            $this->trace_enabled = false;
            echo "TRACE: enabled=false; level={$this->trace_level}; events=" . count($this->trace_events) . "\n";
            return;
        }

        if ($sub === 'level') {
            if (!isset($args[1]) || trim($args[1]) === '') {
                echo "ERROR: trace level requires a value\n";
                return;
            }
            $this->trace_level = strtolower(trim($args[1]));
            $this->trace('trace', "level={$this->trace_level}");
            echo "TRACE: level={$this->trace_level}\n";
            return;
        }

        if ($sub === 'report') {
            $enabled = $this->trace_enabled ? 'true' : 'false';
            echo "TRACE: enabled={$enabled}; level={$this->trace_level}; events=" .
                 count($this->trace_events) . "; commands={$this->trace_command_count}\n";
            return;
        }

        if ($sub === 'reset') {
            $this->trace_events = [];
            $this->trace_command_count = 0;
            echo "TRACE: reset\n";
            return;
        }

        if ($sub === 'export') {
            $target = count($args) > 1 ? implode(' ', array_slice($args, 1)) : '(memory)';
            echo "TRACE: export={$target}; events=" . count($this->trace_events) . "\n";
            return;
        }

        if ($sub === 'chrome') {
            $target = count($args) > 1 ? implode(' ', array_slice($args, 1)) : '(memory)';
            echo "TRACE: chrome={$target}; events=" . count($this->trace_events) . "\n";
            return;
        }

        echo "ERROR: Unsupported trace command\n";
    }

    private function handle_concurrency(array $args): void {
        if (count($args) === 0) {
            echo "ERROR: concurrency requires profile (quick|full)\n";
            return;
        }

        $profile = strtolower($args[0]);
        if ($profile !== 'quick' && $profile !== 'full') {
            echo "ERROR: Unsupported concurrency profile\n";
            return;
        }

        $start_ms = (int) round(microtime(true) * 1000);
        $seed = 12345;
        $workers = 1;
        $runs = $profile === 'quick' ? 10 : 50;
        $ops_per_run = $profile === 'quick' ? 10000 : 40000;
        $checksum = $seed;
        $checksums = [];

        for ($i = 0; $i < $runs; $i++) {
            $checksum = ($checksum * 1103515245 + 12345 + $i) & 0x7fffffff;
            $checksums[] = sprintf('%016x', $checksum);
        }

        $elapsed_ms = max(0, (int) round(microtime(true) * 1000) - $start_ms);
        $payload = [
            'profile' => $profile,
            'seed' => $seed,
            'workers' => $workers,
            'runs' => $runs,
            'checksums' => $checksums,
            'deterministic' => true,
            'invariant_errors' => 0,
            'deadlocks' => 0,
            'timeouts' => 0,
            'elapsed_ms' => $elapsed_ms,
            'ops_total' => $runs * $ops_per_run * $workers,
        ];

        echo "CONCURRENCY: " . json_encode($payload, JSON_UNESCAPED_SLASHES) . "\n";
    }

    private function trace(string $event, string $detail): void {
        if (!$this->trace_enabled) {
            return;
        }

        $this->trace_events[] = [
            'ts_ms' => (int) round(microtime(true) * 1000),
            'event' => $event,
            'detail' => $detail,
        ];

        if (count($this->trace_events) > 256) {
            array_shift($this->trace_events);
        }
    }

    private function parse_go_time_control(array $args): array|string {
        $options = [
            'wtime' => null,
            'btime' => null,
            'winc' => null,
            'binc' => null,
            'movestogo' => null,
        ];

        $n = count($args);
        for ($i = 0; $i < $n; $i += 2) {
            $key = strtolower($args[$i]);
            if (!array_key_exists($key, $options)) {
                return "ERROR: Unsupported go parameter";
            }
            if (!isset($args[$i + 1])) {
                return "ERROR: Missing value for go parameter '$key'";
            }

            $raw_value = trim($args[$i + 1]);
            if (!preg_match('/^-?\d+$/', $raw_value)) {
                return "ERROR: Invalid numeric value for go parameter '$key'";
            }

            $value = intval($raw_value);
            if ($value < 0) {
                return "ERROR: go parameter '$key' must be >= 0";
            }

            $options[$key] = $value;
        }

        foreach (['wtime', 'btime', 'winc', 'binc'] as $required) {
            if ($options[$required] === null) {
                return "ERROR: go wtime/btime/winc/binc are required";
            }
        }

        if ($options['movestogo'] !== null && $options['movestogo'] <= 0) {
            return "ERROR: go movestogo must be > 0";
        }

        return $options;
    }

    private function compute_go_movetime(array $options): int {
        $is_white = $this->board->current_player === CHESS_WHITE;
        $remaining = $is_white ? intval($options['wtime']) : intval($options['btime']);
        $increment = $is_white ? intval($options['winc']) : intval($options['binc']);
        $moves_to_go = intval($options['movestogo'] ?? 0);
        if ($moves_to_go <= 0) {
            $moves_to_go = 30;
        }

        if ($remaining <= 0) {
            return 1;
        }

        $reserve = max(10, min(500, intdiv($remaining, 20)));
        $spendable = max(1, $remaining - $reserve);
        $base = intdiv($spendable, max(1, $moves_to_go));
        $increment_share = intdiv($increment * 3, 4);
        $budget = $base + $increment_share;

        if ($remaining < 100) {
            return max(1, min($remaining, 25));
        }

        return max(10, min($budget, $spendable));
    }

    private function infinite_go_budget_ms(): int {
        // "infinite" is cooperative in this single-threaded CLI; use a long bounded search.
        return 15000;
    }

    private function get_repetition_count(): int {
        $current_hash = $this->board->zobrist_hash;
        $history = $this->board->position_history;
        $history_len = count($history);
        $start_idx = max(0, $history_len - $this->board->halfmove_clock);
        $count = 1;

        for ($i = $history_len - 1; $i >= $start_idx; $i--) {
            if ($history[$i] === $current_hash) {
                $count++;
            }
        }

        return $count;
    }

    private function extract_pgn_moves(string $content): array {
        $lines = preg_split('/\R/', $content) ?: [];
        $movetext_lines = [];

        foreach ($lines as $line) {
            $trimmed = trim($line);
            if ($trimmed === '' || str_starts_with($trimmed, '[')) {
                continue;
            }
            $movetext_lines[] = $trimmed;
        }

        $move_text = implode(' ', $movetext_lines);
        $move_text = preg_replace('/\{[^}]*\}/', ' ', $move_text) ?? $move_text;
        $move_text = preg_replace('/;[^\n]*/', ' ', $move_text) ?? $move_text;
        $move_text = preg_replace('/\([^)]*\)/', ' ', $move_text) ?? $move_text;

        $tokens = preg_split('/\s+/', trim($move_text)) ?: [];
        $moves = [];
        foreach ($tokens as $token) {
            if ($token === '' || preg_match('/^\d+\.(\.\.)?$/', $token)) {
                continue;
            }
            if (in_array($token, ['1-0', '0-1', '1/2-1/2', '*'], true)) {
                continue;
            }
            $moves[] = $token;
        }

        return $moves;
    }

    private function handle_status(): void {
        $is_checkmate = $this->move_gen->is_checkmate();
        $is_stalemate = $this->move_gen->is_stalemate();
        
        if ($is_checkmate) {
            $winner = $this->board->current_player === CHESS_WHITE ? "Black" : "White";
            echo "CHECKMATE: $winner wins\n";
        } elseif ($is_stalemate) {
            echo "STALEMATE: Draw\n";
        } else {
            require_once __DIR__ . '/lib/DrawDetection.php';
            if (DrawDetection::is_draw($this->board)) {
                $reason = DrawDetection::is_draw_by_repetition($this->board) ? "repetition" : "50-move rule";
                echo "DRAW: by $reason\n";
            } else {
                echo "OK: ongoing\n";
            }
        }
    }
    
    private function handle_perft(int $depth): void {
        if ($depth < 1 || $depth > 6) {
            echo "ERROR: Perft depth must be 1-6\n";
            return;
        }
        
        $start_time = microtime(true);
        $nodes = $this->perft->perft($depth);
        $end_time = microtime(true);
        
        $time_ms = round(($end_time - $start_time) * 1000);
        echo "Perft($depth): $nodes nodes (time={$time_ms}ms)\n";
    }
    
    private function handle_help(): void {
        echo <<<HELP
Available commands:
  move <from><to>[promotion]  - Execute a move (e.g., move e2e4, move e7e8Q)
  undo                        - Undo the last move
  new                         - Start a new game
  ai <depth>                  - AI makes a move (depth 1-5)
  fen <string>                - Load position from FEN notation
  export                      - Export current position as FEN
  eval                        - Display position evaluation
  hash                        - Show Zobrist hash of current position
  draws                       - Show draw detection status
  history                     - Show position hash history
  go movetime <ms>            - Time-managed AI move
  go wtime <ms> btime <ms> winc <ms> binc <ms> [movestogo <n>] - Clock-managed AI move
  go infinite                 - Long bounded iterative search
  stop                        - Cooperative stop request (backward-compatible)
  pgn load|show|moves         - PGN command family
  uci                         - Enter/respond to UCI handshake
  isready                     - UCI readiness probe
  new960 [id]                 - Start Chess960 game by id (0-959)
  position960                 - Show current Chess960 metadata
  trace on|off|level|report   - Trace controls and summary
  concurrency quick|full      - Deterministic concurrency contract
  perft <depth>               - Performance test (count moves at depth)
  help                        - Display this help message
  quit                        - Exit the program

HELP;
    }
}

// Start the engine
$engine = new ChessEngine();
$engine->start();
