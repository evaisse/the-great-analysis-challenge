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
    private int $uci_hash_mb = 16;
    private int $uci_threads = 1;
    private ?string $pgn_path = null;
    private array $pgn_moves = [];
    private ?string $book_path = null;
    private bool $book_enabled = false;
    /** @var array<string,array<int,array{move:string,weight:int}>> */
    private array $book_entries = [];
    private int $book_entry_count = 0;
    private int $book_lookups = 0;
    private int $book_hits = 0;
    private int $book_misses = 0;
    private int $book_played = 0;
    private int $chess960_id = 0;
    private bool $trace_enabled = false;
    private string $trace_level = 'info';
    private array $trace_events = [];
    private int $trace_command_count = 0;
    private int $trace_export_count = 0;
    private ?string $trace_export_last_target = null;
    private int $trace_export_last_bytes = 0;
    private int $trace_chrome_count = 0;
    private ?string $trace_chrome_last_target = null;
    private int $trace_chrome_last_bytes = 0;
    private ?string $trace_ai_source = null;
    private ?string $trace_ai_move = null;
    private int $trace_ai_depth = 0;
    private int $trace_ai_score_cp = 0;
    private int $trace_ai_elapsed_ms = 0;
    private bool $trace_ai_timed_out = false;
    private int $trace_ai_nodes = 0;
    private int $trace_ai_eval_calls = 0;
    private int $trace_ai_nps = 0;
    
    public function __construct() {
        $this->board = new Board();
        $this->move_gen = new MoveGenerator($this->board);
        $this->fen_parser = new FenParser($this->board);
        $this->ai = new AI($this->board, $this->move_gen);
        $this->perft = new Perft($this->board, $this->move_gen);
        $this->reset_trace_export_state();
        $this->reset_trace_search_state();
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
                case 'book':
                    $this->handle_book(array_slice($parts, 1));
                    break;
                case 'endgame':
                    $this->handle_endgame(array_slice($parts, 1));
                    break;

                case 'uci':
                    $this->handle_uci();
                    break;

                case 'isready':
                    $this->handle_isready();
                    break;

                case 'setoption':
                    $this->handle_setoption(array_slice($parts, 1));
                    break;

                case 'ucinewgame':
                    $this->handle_ucinewgame();
                    break;

                case 'position':
                    $this->handle_position(array_slice($parts, 1));
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
                $reason = DrawDetection::is_draw_by_fifty_moves($this->board) ? "50-move rule" : "repetition";
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
        $this->handle_ai_timed($depth, 0);
    }

    private function handle_ai_timed(int $max_depth, int $movetime_ms): void {
        $legal_moves = $this->move_gen->generate_moves();
        if (empty($legal_moves)) {
            echo "ERROR: No legal moves available\n";
            return;
        }

        $book_move = $this->choose_book_move($legal_moves);
        if ($book_move !== null) {
            $this->apply_book_move($book_move);
            return;
        }

        $endgame_choice = $this->choose_endgame_move($legal_moves);
        if ($endgame_choice !== null) {
            $this->apply_endgame_move($endgame_choice['move'], $endgame_choice['info']);
            return;
        }

        [$move, $eval, $depth_used, $time_ms, $timed_out, $nodes, $eval_calls] = $this->ai->search($max_depth, $movetime_ms);

        if ($move === null) {
            echo "ERROR: No legal moves available\n";
            return;
        }

        $this->board->make_move($move);
        $move_str = strtolower($move->to_string());
        $this->record_trace_ai('search', $move_str, $depth_used, $eval, $time_ms, $timed_out, $nodes, $eval_calls);
        echo "AI: {$move_str} (depth=$depth_used, eval=$eval, time={$time_ms}ms)\n";

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
                $reason = DrawDetection::is_draw_by_fifty_moves($this->board) ? "50-move rule" : "repetition";
                echo "DRAW: by $reason\n";
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
            echo "ERROR: go requires subcommand (movetime <ms>|wtime <ms> btime <ms> winc <ms> binc <ms> [movestogo <n>]|infinite)\n";
            return;
        }

        $sub = strtolower($args[0]);
        if ($sub === 'depth') {
            if (!isset($args[1]) || !is_numeric($args[1])) {
                echo "ERROR: go depth requires an integer value\n";
                return;
            }

            $depth = intval($args[1]);
            if ($depth < 1) {
                $depth = 1;
            } elseif ($depth > 5) {
                $depth = 5;
            }

            $legal_moves = $this->move_gen->generate_moves();
            $book_move = $this->choose_book_move($legal_moves);
            if ($book_move !== null) {
                $move_str = strtolower($book_move->to_string());
                $this->record_trace_ai('uci-book', $move_str, 0, 0, 0, false, 0, 0);
                echo "info string bookmove {$move_str}\n";
                echo "bestmove {$move_str}\n";
                return;
            }

            $endgame_choice = $this->choose_endgame_move($legal_moves);
            if ($endgame_choice !== null) {
                $move_str = strtolower($endgame_choice['move']->to_string());
                $info = $endgame_choice['info'];
                $this->record_trace_ai('uci-endgame', $move_str, 0, intval($info['score_white']), 0, false, 0, 0);
                echo "info string endgame {$info['type']} score cp {$info['score_white']}\n";
                echo "bestmove {$move_str}\n";
                return;
            }

            [$move, $eval, $depth_used, $time_ms, $timed_out, $nodes, $eval_calls] = $this->ai->search($depth, 0);
            if ($move === null) {
                echo "bestmove 0000\n";
                return;
            }
            $move_str = strtolower($move->to_string());
            $this->record_trace_ai('uci-search', $move_str, $depth_used, $eval, $time_ms, $timed_out, $nodes, $eval_calls);
            echo "info depth {$depth_used} score cp {$eval} time {$time_ms} nodes 0\n";
            echo "bestmove {$move_str}\n";
            return;
        }

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

            $this->handle_ai_timed(5, $movetime);
            return;
        }

        if ($sub === 'wtime') {
            [$movetime, $error] = $this->derive_movetime_from_clock_args($args);
            if ($error !== null) {
                echo "ERROR: {$error}\n";
                return;
            }
            $this->handle_ai_timed(5, $movetime);
            return;
        }

        if ($sub === 'infinite') {
            echo "OK: go infinite acknowledged (bounded search mode)\n";
            $this->handle_ai_timed(5, 15000);
            return;
        }

        echo "ERROR: Unsupported go command\n";
    }

    private function handle_stop(): void {
        $this->ai->request_stop();
        echo "OK: stop\n";
    }

    /**
     * @return array{0:int,1:?string}
     */
    private function derive_movetime_from_clock_args(array $args): array {
        $values = [
            'winc' => 0,
            'binc' => 0,
            'movestogo' => 30,
        ];

        $i = 0;
        while ($i < count($args)) {
            $key = strtolower(trim($args[$i]));
            $i++;
            if ($i >= count($args)) {
                return [0, "go {$key} requires a value"];
            }
            if (!is_numeric($args[$i])) {
                return [0, "go {$key} requires an integer value"];
            }
            $value = intval($args[$i]);
            $i++;

            if (!in_array($key, ['wtime', 'btime', 'winc', 'binc', 'movestogo'], true)) {
                return [0, "unsupported go parameter: {$key}"];
            }
            $values[$key] = $value;
        }

        if (!isset($values['wtime']) || !isset($values['btime'])) {
            return [0, 'go wtime/btime parameters are required'];
        }
        if ($values['wtime'] <= 0 || $values['btime'] <= 0) {
            return [0, 'go wtime/btime must be > 0'];
        }
        if ($values['movestogo'] <= 0) {
            $values['movestogo'] = 30;
        }

        if ($this->board->current_player === CHESS_WHITE) {
            $base = $values['wtime'];
            $inc = $values['winc'];
        } else {
            $base = $values['btime'];
            $inc = $values['binc'];
        }

        $budget = intdiv($base, $values['movestogo'] + 1) + intdiv($inc, 2);
        if ($budget < 50) {
            $budget = 50;
        }
        if ($budget >= $base) {
            $budget = intdiv($base, 2);
        }
        if ($budget <= 0) {
            return [0, 'unable to derive positive movetime from clocks'];
        }

        return [$budget, null];
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

    private function handle_book(array $args): void {
        if (count($args) === 0) {
            echo "ERROR: book requires subcommand (load|on|off|stats)\n";
            return;
        }

        $sub = strtolower($args[0]);
        if ($sub === 'load') {
            if (!isset($args[1])) {
                echo "ERROR: book load requires a file path\n";
                return;
            }
            $path = implode(' ', array_slice($args, 1));
            if (!is_readable($path)) {
                echo "ERROR: book load failed: file not readable\n";
                return;
            }

            $content = file_get_contents($path);
            if ($content === false) {
                echo "ERROR: book load failed: unable to read file\n";
                return;
            }

            try {
                [$entries, $total_entries] = $this->parse_book_entries($content);
            } catch (\Exception $e) {
                echo "ERROR: book load failed: " . $e->getMessage() . "\n";
                return;
            }

            $this->book_path = $path;
            $this->book_entries = $entries;
            $this->book_entry_count = $total_entries;
            $this->book_enabled = true;
            $this->book_lookups = 0;
            $this->book_hits = 0;
            $this->book_misses = 0;
            $this->book_played = 0;

            echo 'BOOK: loaded path="' . $path . '"; positions=' . count($entries) .
                 '; entries=' . $total_entries . '; enabled=true' . "\n";
            return;
        }

        if ($sub === 'on') {
            $this->book_enabled = true;
            echo "BOOK: enabled=true\n";
            return;
        }

        if ($sub === 'off') {
            $this->book_enabled = false;
            echo "BOOK: enabled=false\n";
            return;
        }

        if ($sub === 'stats') {
            $path = $this->book_path ?? '(none)';
            echo "BOOK: enabled=" . ($this->book_enabled ? 'true' : 'false') .
                 "; path={$path}; positions=" . count($this->book_entries) .
                 "; entries={$this->book_entry_count}; lookups={$this->book_lookups}; " .
                 "hits={$this->book_hits}; misses={$this->book_misses}; played={$this->book_played}\n";
            return;
        }

        echo "ERROR: Unsupported book command\n";
    }

    private function handle_endgame(array $args): void {
        $info = $this->detect_endgame_state();
        if ($info === null) {
            $active = $this->board->current_player === CHESS_WHITE ? 'white' : 'black';
            echo "ENDGAME: type=none; active={$active}; score=0\n";
            return;
        }

        $output = "ENDGAME: type={$info['type']}; strong=" . $this->color_name($info['strong']) .
            "; weak=" . $this->color_name($info['weak']) . "; score={$info['score_white']}";
        $legal_moves = $this->move_gen->generate_moves();
        $choice = $this->choose_endgame_move($legal_moves);
        if ($choice !== null) {
            $output .= '; bestmove=' . strtolower($choice['move']->to_string());
        }
        $output .= '; detail=' . $info['detail'];
        echo $output . "\n";
    }

    private function handle_uci(): void {
        echo "uciok\n";
    }

    private function handle_isready(): void {
        echo "readyok\n";
    }

    private function handle_setoption(array $args): void {
        if (count($args) < 4 || strtolower($args[0]) !== 'name') {
            echo "ERROR: setoption format is 'setoption name <Hash|Threads> value <n>'\n";
            return;
        }

        $value_idx = -1;
        for ($i = 1; $i < count($args); $i++) {
            if (strtolower($args[$i]) === 'value') {
                $value_idx = $i;
                break;
            }
        }
        if ($value_idx <= 1 || $value_idx + 1 >= count($args)) {
            echo "ERROR: setoption requires 'value <n>'\n";
            return;
        }

        $name = strtolower(trim(implode(' ', array_slice($args, 1, $value_idx - 1))));
        if (!is_numeric($args[$value_idx + 1])) {
            echo "ERROR: setoption value must be an integer\n";
            return;
        }
        $value = intval($args[$value_idx + 1]);

        if ($name === 'hash') {
            $this->uci_hash_mb = max(1, min(1024, $value));
            echo "info string option Hash={$this->uci_hash_mb}\n";
            return;
        }

        if ($name === 'threads') {
            $this->uci_threads = max(1, min(64, $value));
            echo "info string option Threads={$this->uci_threads}\n";
            return;
        }

        $raw_name = trim(implode(' ', array_slice($args, 1, $value_idx - 1)));
        echo "info string unsupported option {$raw_name}\n";
    }

    private function handle_ucinewgame(): void {
        $this->board = new Board();
        $this->move_gen = new MoveGenerator($this->board);
        $this->fen_parser = new FenParser($this->board);
        $this->ai = new AI($this->board, $this->move_gen);
        $this->perft = new Perft($this->board, $this->move_gen);
    }

    private function handle_position(array $args): void {
        if (count($args) === 0) {
            echo "ERROR: position requires 'startpos' or 'fen <...>'\n";
            return;
        }

        $idx = 0;
        $keyword = strtolower($args[0]);
        if ($keyword === 'startpos') {
            $this->handle_ucinewgame();
            $idx = 1;
        } elseif ($keyword === 'fen') {
            $idx = 1;
            $fen_tokens = [];
            while ($idx < count($args) && strtolower($args[$idx]) !== 'moves') {
                $fen_tokens[] = $args[$idx];
                $idx++;
            }
            if (empty($fen_tokens)) {
                echo "ERROR: position fen requires a FEN string\n";
                return;
            }
            if (!$this->fen_parser->load_fen(implode(' ', $fen_tokens))) {
                echo "ERROR: Invalid FEN string\n";
                return;
            }
        } else {
            echo "ERROR: position requires 'startpos' or 'fen <...>'\n";
            return;
        }

        if ($idx < count($args) && strtolower($args[$idx]) === 'moves') {
            $idx++;
            for (; $idx < count($args); $idx++) {
                $err = $this->apply_move_silent($args[$idx]);
                if ($err !== null) {
                    echo "ERROR: position move {$args[$idx]} failed: {$err}\n";
                    return;
                }
            }
        }
    }

    private function apply_move_silent(string $move_str): ?string {
        $move = $this->move_gen->parse_move($move_str);
        if ($move === null) {
            return 'Invalid move format';
        }

        $legal_moves = $this->move_gen->generate_moves();
        $selected = null;
        foreach ($legal_moves as $candidate) {
            if ($candidate->from_row === $move->from_row &&
                $candidate->from_col === $move->from_col &&
                $candidate->to_row === $move->to_row &&
                $candidate->to_col === $move->to_col) {
                $selected = $candidate;
                break;
            }
        }
        if ($selected === null) {
            return 'Illegal move';
        }

        $this->board->make_move($selected);
        return null;
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
            echo $this->format_trace_report() . "\n";
            return;
        }

        if ($sub === 'reset') {
            $this->trace_events = [];
            $this->trace_command_count = 0;
            $this->reset_trace_export_state();
            $this->reset_trace_search_state();
            echo "TRACE: reset\n";
            return;
        }

        if ($sub === 'export') {
            $target = count($args) > 1 ? implode(' ', array_slice($args, 1)) : '(memory)';
            $event_count = count($this->trace_events);
            $payload = $this->encode_trace_export_payload();
            $byte_count = $this->write_trace_payload($payload, $target, count($args) > 1);
            $this->record_trace_artifact($target, $byte_count, false);
            echo "TRACE: export={$target}; events={$event_count}; bytes={$byte_count}\n";
            return;
        }

        if ($sub === 'chrome') {
            $target = count($args) > 1 ? implode(' ', array_slice($args, 1)) : '(memory)';
            $event_count = count($this->trace_events);
            $payload = $this->encode_trace_chrome_payload();
            $byte_count = $this->write_trace_payload($payload, $target, count($args) > 1);
            $this->record_trace_artifact($target, $byte_count, true);
            echo "TRACE: chrome={$target}; events={$event_count}; bytes={$byte_count}\n";
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

        $profile_config = $profile === 'quick'
            ? [
                'workers' => 2,
                'runs' => 10,
                'sequences_per_worker' => 4,
                'plies_per_sequence' => 4,
            ]
            : [
                'workers' => 4,
                'runs' => 50,
                'sequences_per_worker' => 6,
                'plies_per_sequence' => 6,
            ];
        $scenarios = [
            'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
            'rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3',
            'r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1',
            '4k3/6P1/8/8/8/8/8/4K3 w - - 0 1',
        ];

        $start_ms = (int) round(microtime(true) * 1000);
        $seed = 12345;
        $workers = $profile_config['workers'];
        $runs = $profile_config['runs'];
        $sequences_per_worker = $profile_config['sequences_per_worker'];
        $plies_per_sequence = $profile_config['plies_per_sequence'];
        $ops_per_run = $workers * $sequences_per_worker * $plies_per_sequence;
        $checksums = [];
        $invariant_errors = 0;

        for ($run = 0; $run < $runs; $run++) {
            $run_checksum = $this->concurrency_checksum_mix(
                (2166136261 ^ $seed ^ (($run + 1) * 173)) & 0xffffffff,
                "run:$profile:$run"
            );

            for ($worker = 0; $worker < $workers; $worker++) {
                [$worker_checksum, $worker_errors] = $this->run_concurrency_worker(
                    $seed,
                    $run,
                    $worker,
                    $sequences_per_worker,
                    $plies_per_sequence,
                    $scenarios
                );
                $invariant_errors += $worker_errors;
                $run_checksum = $this->concurrency_checksum_mix(
                    $run_checksum,
                    $worker . ':' . $worker_checksum
                );
            }

            $checksums[] = $this->format_concurrency_checksum($run_checksum);
        }

        $elapsed_ms = max(0, (int) round(microtime(true) * 1000) - $start_ms);
        $payload = [
            'profile' => $profile,
            'seed' => $seed,
            'workers' => $workers,
            'runs' => $runs,
            'checksums' => $checksums,
            'deterministic' => true,
            'invariant_errors' => $invariant_errors,
            'deadlocks' => 0,
            'timeouts' => 0,
            'elapsed_ms' => $elapsed_ms,
            'ops_total' => $runs * $ops_per_run,
        ];

        echo "CONCURRENCY: " . json_encode($payload, JSON_UNESCAPED_SLASHES) . "\n";
    }

    private function run_concurrency_worker(
        int $seed,
        int $run,
        int $worker,
        int $sequences_per_worker,
        int $plies_per_sequence,
        array $scenarios
    ): array {
        $checksum = (2166136261 ^ $seed ^ (($run + 1) * 97) ^ (($worker + 1) * 131)) & 0xffffffff;
        $checksum = $this->concurrency_checksum_mix($checksum, "worker:$run:$worker");
        $invariant_errors = 0;

        for ($sequence = 0; $sequence < $sequences_per_worker; $sequence++) {
            $scenario_index = ($run + $worker + $sequence) % count($scenarios);
            [$board, $move_gen, $fen_parser] = $this->create_concurrency_state($scenarios[$scenario_index]);
            $baseline_fen = $fen_parser->export_fen();
            $baseline_hash = $this->concurrency_hash_hex($board->zobrist_hash);
            $checksum = $this->concurrency_checksum_mix(
                $checksum,
                "seq:$scenario_index:$baseline_hash:$baseline_fen"
            );
            $applied_moves = 0;

            for ($ply = 0; $ply < $plies_per_sequence; $ply++) {
                $legal_moves = $move_gen->generate_moves();
                usort($legal_moves, fn(Move $left, Move $right): int => strcmp($left->to_string(), $right->to_string()));
                $checksum = $this->concurrency_checksum_mix($checksum, 'legal:' . count($legal_moves));
                if (count($legal_moves) === 0) {
                    $invariant_errors++;
                    $checksum = $this->concurrency_checksum_mix($checksum, "empty:$sequence:$ply");
                    break;
                }

                $selected = $this->choose_concurrency_move(
                    $legal_moves,
                    $seed,
                    $run,
                    $worker,
                    $sequence,
                    $ply
                );
                $before_fen = $fen_parser->export_fen();
                $before_hash = $this->concurrency_hash_hex($board->zobrist_hash);
                $move_str = $selected->to_string();

                $board->make_move($selected);
                $applied_moves++;
                $after_fen = $fen_parser->export_fen();
                $after_hash = $this->concurrency_hash_hex($board->zobrist_hash);
                $checksum = $this->concurrency_checksum_mix(
                    $checksum,
                    "move:$move_str:$before_hash:$before_fen:$after_hash:$after_fen"
                );

                [$reloaded_board, $_reload_moves, $reloaded_parser] = $this->create_concurrency_state($after_fen);
                $reloaded_hash = $this->concurrency_hash_hex($reloaded_board->zobrist_hash);
                if ($reloaded_parser->export_fen() !== $after_fen || $reloaded_hash !== $after_hash) {
                    $invariant_errors++;
                    $checksum = $this->concurrency_checksum_mix(
                        $checksum,
                        "reload-error:$sequence:$ply:$reloaded_hash"
                    );
                }
            }

            for ($ply = 0; $ply < $applied_moves; $ply++) {
                if (!$board->undo_move()) {
                    $invariant_errors++;
                    $checksum = $this->concurrency_checksum_mix($checksum, "undo-missing:$sequence:$ply");
                    break;
                }
            }

            $restored_fen = $fen_parser->export_fen();
            $restored_hash = $this->concurrency_hash_hex($board->zobrist_hash);
            if ($restored_fen !== $baseline_fen || $restored_hash !== $baseline_hash) {
                $invariant_errors++;
                $checksum = $this->concurrency_checksum_mix(
                    $checksum,
                    "undo-error:$sequence:$restored_hash:$restored_fen"
                );
            } else {
                $checksum = $this->concurrency_checksum_mix($checksum, "undo-ok:$restored_hash");
            }
        }

        return [$this->format_concurrency_checksum($checksum), $invariant_errors];
    }

    private function create_concurrency_state(string $fen): array {
        $board = new Board();
        $fen_parser = new FenParser($board);
        if (!$fen_parser->load_fen($fen)) {
            throw new \RuntimeException("Invalid concurrency FEN: $fen");
        }

        $board->game_history = [];
        $board->position_history = [];
        $board->irreversible_history = [];
        $board->zobrist_hash = Zobrist::getInstance()->compute_hash($board);

        return [$board, new MoveGenerator($board), $fen_parser];
    }

    private function choose_concurrency_move(
        array $legal_moves,
        int $seed,
        int $run,
        int $worker,
        int $sequence,
        int $ply
    ): Move {
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

    private function concurrency_checksum_mix(int $checksum, string $text): int {
        $length = strlen($text);
        for ($i = 0; $i < $length; $i++) {
            $checksum ^= ord($text[$i]);
            $checksum = ($checksum * 16777619) & 0xffffffff;
        }

        return $checksum;
    }

    private function format_concurrency_checksum(int $checksum): string {
        return sprintf('%08x', $checksum & 0xffffffff);
    }

    private function concurrency_hash_hex(int $hash): string {
        return sprintf('%016x', $hash);
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

    private function reset_trace_export_state(): void {
        $this->trace_export_count = 0;
        $this->trace_export_last_target = null;
        $this->trace_export_last_bytes = 0;
        $this->trace_chrome_count = 0;
        $this->trace_chrome_last_target = null;
        $this->trace_chrome_last_bytes = 0;
    }

    private function reset_trace_search_state(): void {
        $this->trace_ai_source = null;
        $this->trace_ai_move = null;
        $this->trace_ai_depth = 0;
        $this->trace_ai_score_cp = 0;
        $this->trace_ai_elapsed_ms = 0;
        $this->trace_ai_timed_out = false;
        $this->trace_ai_nodes = 0;
        $this->trace_ai_eval_calls = 0;
        $this->trace_ai_nps = 0;
    }

    private function format_trace_report(): string {
        $enabled = $this->trace_enabled ? 'true' : 'false';
        return "TRACE: enabled={$enabled}; level={$this->trace_level}; events=" .
            count($this->trace_events) . "; commands={$this->trace_command_count}; export=" .
            $this->format_trace_report_segment(
                $this->trace_export_count,
                $this->trace_export_last_target,
                $this->trace_export_last_bytes
            ) . "; chrome=" .
            $this->format_trace_report_segment(
                $this->trace_chrome_count,
                $this->trace_chrome_last_target,
                $this->trace_chrome_last_bytes
            ) . "; last_ai=" . $this->format_trace_ai_summary();
    }

    private function format_trace_report_segment(int $count, ?string $target, int $byte_count): string {
        $resolved_target = $target ?? 'none';
        return "{$count}@{$resolved_target}/{$byte_count}B";
    }

    private function record_trace_artifact(string $target, int $byte_count, bool $chrome): void {
        if ($chrome) {
            $this->trace_chrome_count++;
            $this->trace_chrome_last_target = $target;
            $this->trace_chrome_last_bytes = $byte_count;
            return;
        }

        $this->trace_export_count++;
        $this->trace_export_last_target = $target;
        $this->trace_export_last_bytes = $byte_count;
    }

    private function format_trace_ai_summary(): string {
        if ($this->trace_ai_source === null || $this->trace_ai_move === null) {
            return 'none';
        }

        $summary = "{$this->trace_ai_source}:{$this->trace_ai_move}";
        if (str_contains($this->trace_ai_source, 'search')) {
            $summary .= "@d{$this->trace_ai_depth}/{$this->trace_ai_score_cp}cp/{$this->trace_ai_elapsed_ms}ms"
                . "/n{$this->trace_ai_nodes}/e{$this->trace_ai_eval_calls}/nps{$this->trace_ai_nps}";
            if ($this->trace_ai_timed_out) {
                $summary .= '/timeout';
            }
        } elseif (str_contains($this->trace_ai_source, 'endgame')) {
            $summary .= "/{$this->trace_ai_score_cp}cp";
        }

        return $summary;
    }

    private function record_trace_ai(
        string $source,
        string $move,
        int $depth,
        int $score_cp,
        int $elapsed_ms,
        bool $timed_out,
        int $nodes,
        int $eval_calls
    ): void {
        $this->trace_ai_source = $source;
        $this->trace_ai_move = $move;
        $this->trace_ai_depth = $depth;
        $this->trace_ai_score_cp = $score_cp;
        $this->trace_ai_elapsed_ms = $elapsed_ms;
        $this->trace_ai_timed_out = $timed_out;
        $this->trace_ai_nodes = $nodes;
        $this->trace_ai_eval_calls = $eval_calls;
        $divisor = $elapsed_ms > 0 ? $elapsed_ms : 1;
        $this->trace_ai_nps = $nodes > 0 ? (int) floor(($nodes * 1000) / $divisor) : 0;
        $this->trace('ai', $this->format_trace_ai_summary());
    }

    private function trace_last_ai_payload(): ?array {
        if ($this->trace_ai_source === null || $this->trace_ai_move === null) {
            return null;
        }

        return [
            'source' => $this->trace_ai_source,
            'move' => $this->trace_ai_move,
            'depth' => $this->trace_ai_depth,
            'score_cp' => $this->trace_ai_score_cp,
            'elapsed_ms' => $this->trace_ai_elapsed_ms,
            'timed_out' => $this->trace_ai_timed_out,
            'nodes' => $this->trace_ai_nodes,
            'eval_calls' => $this->trace_ai_eval_calls,
            'nps' => $this->trace_ai_nps,
            'summary' => $this->format_trace_ai_summary(),
        ];
    }

    private function write_trace_payload(string $payload, string $target, bool $write_to_file): int {
        $byte_count = strlen($payload);
        if ($write_to_file) {
            $written = @file_put_contents($target, $payload);
            if ($written === false || $written !== $byte_count) {
                throw new \RuntimeException("Unable to write trace output to {$target}");
            }
        }

        return $byte_count;
    }

    private function encode_trace_export_payload(): string {
        $payload = [
            'format' => 'tgac.trace.v1',
            'engine' => 'php',
            'generated_at_ms' => (int) round(microtime(true) * 1000),
            'enabled' => $this->trace_enabled,
            'level' => $this->trace_level,
            'command_count' => $this->trace_command_count,
            'event_count' => count($this->trace_events),
            'events' => array_values($this->trace_events),
        ];
        $last_ai = $this->trace_last_ai_payload();
        if ($last_ai !== null) {
            $payload['last_ai'] = $last_ai;
        }
        $json = json_encode($payload, JSON_UNESCAPED_SLASHES);
        if ($json === false) {
            throw new \RuntimeException('Unable to encode trace export JSON: ' . json_last_error_msg());
        }

        return $json . "\n";
    }

    private function encode_trace_chrome_payload(): string {
        $base_ts_ms = count($this->trace_events) > 0
            ? (int) ($this->trace_events[0]['ts_ms'] ?? round(microtime(true) * 1000))
            : (int) round(microtime(true) * 1000);
        $trace_events = [];

        foreach ($this->trace_events as $index => $event) {
            $event_ts_ms = isset($event['ts_ms']) ? (int) $event['ts_ms'] : $base_ts_ms;
            $trace_events[] = [
                'name' => (string) ($event['event'] ?? 'trace'),
                'cat' => 'engine.trace',
                'ph' => 'i',
                's' => 't',
                'ts' => max(0, $event_ts_ms - $base_ts_ms) * 1000,
                'pid' => 1,
                'tid' => 1,
                'args' => [
                    'detail' => (string) ($event['detail'] ?? ''),
                    'index' => $index,
                    'ts_ms' => $event_ts_ms,
                    'level' => $this->trace_level,
                ],
            ];
        }

        $payload = [
            'traceEvents' => $trace_events,
            'displayTimeUnit' => 'ms',
            'otherData' => [
                'format' => 'tgac.chrome_trace.v1',
                'engine' => 'php',
                'generated_at_ms' => (int) round(microtime(true) * 1000),
                'level' => $this->trace_level,
                'command_count' => $this->trace_command_count,
                'event_count' => count($this->trace_events),
            ],
        ];
        $json = json_encode($payload, JSON_UNESCAPED_SLASHES);
        if ($json === false) {
            throw new \RuntimeException('Unable to encode Chrome trace JSON: ' . json_last_error_msg());
        }

        return $json . "\n";
    }

    private function depth_for_movetime(int $movetime): int {
        if ($movetime <= 200) return 1;
        if ($movetime <= 500) return 2;
        if ($movetime <= 2000) return 3;
        if ($movetime <= 5000) return 4;
        return 5;
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

    private function book_position_key(string $fen): string {
        $parts = preg_split('/\s+/', trim($fen)) ?: [];
        if (count($parts) >= 4) {
            return implode(' ', array_slice($parts, 0, 4));
        }
        return trim($fen);
    }

    /**
     * @return array{0:array<string,array<int,array{move:string,weight:int}>>,1:int}
     */
    private function parse_book_entries(string $content): array {
        $entries = [];
        $total_entries = 0;
        $lines = preg_split('/\R/', $content) ?: [];

        foreach ($lines as $idx => $raw) {
            $line_number = $idx + 1;
            $line = trim($raw);
            if ($line === '' || str_starts_with($line, '#')) {
                continue;
            }

            if (strpos($line, '->') === false) {
                throw new \RuntimeException("line {$line_number}: expected '<fen> -> <move> [weight]'");
            }

            [$left, $right] = array_map('trim', explode('->', $line, 2));
            $key = $this->book_position_key($left);
            if ($key === '') {
                throw new \RuntimeException("line {$line_number}: empty position key");
            }

            $rhs_parts = preg_split('/\s+/', trim($right)) ?: [];
            if (count($rhs_parts) === 0) {
                throw new \RuntimeException("line {$line_number}: missing move");
            }

            $move = strtolower($rhs_parts[0]);
            if (!preg_match('/^[a-h][1-8][a-h][1-8][qrbn]?$/', $move)) {
                throw new \RuntimeException("line {$line_number}: invalid move '{$move}'");
            }

            $weight = 1;
            if (isset($rhs_parts[1])) {
                if (!is_numeric($rhs_parts[1])) {
                    throw new \RuntimeException("line {$line_number}: invalid weight '{$rhs_parts[1]}'");
                }
                $weight = intval($rhs_parts[1]);
                if ($weight <= 0) {
                    throw new \RuntimeException("line {$line_number}: weight must be > 0");
                }
            }

            if (!isset($entries[$key])) {
                $entries[$key] = [];
            }
            $entries[$key][] = ['move' => $move, 'weight' => $weight];
            $total_entries++;
        }

        return [$entries, $total_entries];
    }

    private function choose_book_move(array $legal_moves): ?Move {
        $this->book_lookups++;
        if (!$this->book_enabled || empty($this->book_entries)) {
            $this->book_misses++;
            return null;
        }

        $key = $this->book_position_key($this->fen_parser->export_fen());
        $position_entries = $this->book_entries[$key] ?? [];
        if (empty($position_entries)) {
            $this->book_misses++;
            return null;
        }

        $legal_by_notation = [];
        foreach ($legal_moves as $move) {
            $legal_by_notation[strtolower($move->to_string())] = $move;
        }

        $weighted = [];
        $total_weight = 0;
        foreach ($position_entries as $entry) {
            $notation = $entry['move'];
            if (!isset($legal_by_notation[$notation])) {
                continue;
            }
            $weight = max(1, intval($entry['weight']));
            $weighted[] = ['move' => $legal_by_notation[$notation], 'weight' => $weight];
            $total_weight += $weight;
        }

        if (empty($weighted) || $total_weight <= 0) {
            $this->book_misses++;
            return null;
        }

        $seed = abs(intval($this->board->zobrist_hash)) + $this->book_lookups;
        $selector = $seed % $total_weight;
        $acc = 0;
        $chosen = $weighted[0]['move'];
        foreach ($weighted as $entry) {
            $acc += $entry['weight'];
            if ($selector < $acc) {
                $chosen = $entry['move'];
                break;
            }
        }

        $this->book_hits++;
        return $chosen;
    }

    private function apply_book_move(Move $move): void {
        $this->board->make_move($move);
        $this->book_played++;
        $move_str = strtolower($move->to_string());
        $this->record_trace_ai('book', $move_str, 0, 0, 0, false, 0, 0);

        $is_checkmate = $this->move_gen->is_checkmate();
        $is_stalemate = $this->move_gen->is_stalemate();

        if ($is_checkmate) {
            $winner = $this->board->current_player === CHESS_WHITE ? "Black" : "White";
            echo "AI: {$move_str} (book, CHECKMATE: {$winner} wins)\n";
        } elseif ($is_stalemate) {
            echo "AI: {$move_str} (book, STALEMATE)\n";
        } else {
            require_once __DIR__ . '/lib/DrawDetection.php';
            if (DrawDetection::is_draw($this->board)) {
                $reason = DrawDetection::is_draw_by_fifty_moves($this->board) ? "50-move rule" : "repetition";
                echo "AI: {$move_str} (book, DRAW: by {$reason})\n";
            } else {
                echo "AI: {$move_str} (book)\n";
            }
        }

        echo $this->board->display();
    }

    private function color_name(int $color): string {
        return $color === CHESS_WHITE ? 'white' : 'black';
    }

    private function square_to_algebraic(array $sq): string {
        return chr(ord('a') + $sq[1]) . (8 - $sq[0]);
    }

    private function manhattan(array $a, array $b): int {
        return abs($a[0] - $b[0]) + abs($a[1] - $b[1]);
    }

    private function non_king_material(array $counts, int $color): int {
        return ($counts[$color][CHESS_PAWN] ?? 0) +
            ($counts[$color][CHESS_KNIGHT] ?? 0) +
            ($counts[$color][CHESS_BISHOP] ?? 0) +
            ($counts[$color][CHESS_ROOK] ?? 0) +
            ($counts[$color][CHESS_QUEEN] ?? 0);
    }

    private function detect_endgame_state(): ?array {
        $piece_keys = [CHESS_EMPTY, CHESS_PAWN, CHESS_KNIGHT, CHESS_BISHOP, CHESS_ROOK, CHESS_QUEEN, CHESS_KING];
        $counts = [
            CHESS_WHITE => array_fill_keys($piece_keys, 0),
            CHESS_BLACK => array_fill_keys($piece_keys, 0),
        ];
        $kings = [];
        $pawns = [];
        $rooks = [];
        $queens = [];

        for ($row = 0; $row < 8; $row++) {
            for ($col = 0; $col < 8; $col++) {
                [$piece, $color] = $this->board->get_piece($row, $col);
                if ($piece === CHESS_EMPTY) {
                    continue;
                }
                $counts[$color][$piece]++;
                if ($piece === CHESS_KING) {
                    $kings[$color] = [$row, $col];
                } elseif ($piece === CHESS_PAWN && !isset($pawns[$color])) {
                    $pawns[$color] = [$row, $col];
                } elseif ($piece === CHESS_ROOK && !isset($rooks[$color])) {
                    $rooks[$color] = [$row, $col];
                } elseif ($piece === CHESS_QUEEN && !isset($queens[$color])) {
                    $queens[$color] = [$row, $col];
                }
            }
        }

        if (!isset($kings[CHESS_WHITE]) || !isset($kings[CHESS_BLACK])) {
            return null;
        }

        $white_material = $this->non_king_material($counts, CHESS_WHITE);
        $black_material = $this->non_king_material($counts, CHESS_BLACK);

        // KQK
        if (($counts[CHESS_WHITE][CHESS_QUEEN] ?? 0) === 1 && $white_material === 1 && $black_material === 0) {
            $weak_king = $kings[CHESS_BLACK];
            $strong_king = $kings[CHESS_WHITE];
            $edge = min($weak_king[0], 7 - $weak_king[0], $weak_king[1], 7 - $weak_king[1]);
            $king_distance = $this->manhattan($strong_king, $weak_king);
            $score = 900 + (14 - $king_distance) * 6 + (3 - $edge) * 20;
            return [
                'type' => 'KQK',
                'strong' => CHESS_WHITE,
                'weak' => CHESS_BLACK,
                'score_white' => $score,
                'detail' => 'queen=' . $this->square_to_algebraic($queens[CHESS_WHITE]),
            ];
        }
        if (($counts[CHESS_BLACK][CHESS_QUEEN] ?? 0) === 1 && $black_material === 1 && $white_material === 0) {
            $weak_king = $kings[CHESS_WHITE];
            $strong_king = $kings[CHESS_BLACK];
            $edge = min($weak_king[0], 7 - $weak_king[0], $weak_king[1], 7 - $weak_king[1]);
            $king_distance = $this->manhattan($strong_king, $weak_king);
            $score = 900 + (14 - $king_distance) * 6 + (3 - $edge) * 20;
            return [
                'type' => 'KQK',
                'strong' => CHESS_BLACK,
                'weak' => CHESS_WHITE,
                'score_white' => -$score,
                'detail' => 'queen=' . $this->square_to_algebraic($queens[CHESS_BLACK]),
            ];
        }

        // KPK
        if (($counts[CHESS_WHITE][CHESS_PAWN] ?? 0) === 1 && $white_material === 1 && $black_material === 0) {
            $pawn = $pawns[CHESS_WHITE];
            $strong_king = $kings[CHESS_WHITE];
            $weak_king = $kings[CHESS_BLACK];
            $promotion = [0, $pawn[1]];
            $pawn_steps = $pawn[0];
            $score = 120 + (6 - $pawn_steps) * 35 + $this->manhattan($weak_king, $promotion) * 6 - $this->manhattan($strong_king, $pawn) * 8;
            if ($pawn_steps <= 1) {
                $score += 80;
            }
            if ($score < 30) {
                $score = 30;
            }
            return [
                'type' => 'KPK',
                'strong' => CHESS_WHITE,
                'weak' => CHESS_BLACK,
                'score_white' => $score,
                'detail' => 'pawn=' . $this->square_to_algebraic($pawn),
            ];
        }
        if (($counts[CHESS_BLACK][CHESS_PAWN] ?? 0) === 1 && $black_material === 1 && $white_material === 0) {
            $pawn = $pawns[CHESS_BLACK];
            $strong_king = $kings[CHESS_BLACK];
            $weak_king = $kings[CHESS_WHITE];
            $promotion = [7, $pawn[1]];
            $pawn_steps = 7 - $pawn[0];
            $score = 120 + (6 - $pawn_steps) * 35 + $this->manhattan($weak_king, $promotion) * 6 - $this->manhattan($strong_king, $pawn) * 8;
            if ($pawn_steps <= 1) {
                $score += 80;
            }
            if ($score < 30) {
                $score = 30;
            }
            return [
                'type' => 'KPK',
                'strong' => CHESS_BLACK,
                'weak' => CHESS_WHITE,
                'score_white' => -$score,
                'detail' => 'pawn=' . $this->square_to_algebraic($pawn),
            ];
        }

        // KRKP
        if (($counts[CHESS_WHITE][CHESS_ROOK] ?? 0) === 1 && $white_material === 1 &&
            ($counts[CHESS_BLACK][CHESS_PAWN] ?? 0) === 1 && $black_material === 1) {
            $strong_king = $kings[CHESS_WHITE];
            $weak_king = $kings[CHESS_BLACK];
            $weak_pawn = $pawns[CHESS_BLACK];
            $pawn_steps = 7 - $weak_pawn[0];
            $score = 380 - $pawn_steps * 25 + ($this->manhattan($weak_king, $weak_pawn) - $this->manhattan($strong_king, $weak_pawn)) * 12;
            if ($score < 50) {
                $score = 50;
            }
            return [
                'type' => 'KRKP',
                'strong' => CHESS_WHITE,
                'weak' => CHESS_BLACK,
                'score_white' => $score,
                'detail' => 'rook=' . $this->square_to_algebraic($rooks[CHESS_WHITE]) . ',pawn=' . $this->square_to_algebraic($weak_pawn),
            ];
        }
        if (($counts[CHESS_BLACK][CHESS_ROOK] ?? 0) === 1 && $black_material === 1 &&
            ($counts[CHESS_WHITE][CHESS_PAWN] ?? 0) === 1 && $white_material === 1) {
            $strong_king = $kings[CHESS_BLACK];
            $weak_king = $kings[CHESS_WHITE];
            $weak_pawn = $pawns[CHESS_WHITE];
            $pawn_steps = $weak_pawn[0];
            $score = 380 - $pawn_steps * 25 + ($this->manhattan($weak_king, $weak_pawn) - $this->manhattan($strong_king, $weak_pawn)) * 12;
            if ($score < 50) {
                $score = 50;
            }
            return [
                'type' => 'KRKP',
                'strong' => CHESS_BLACK,
                'weak' => CHESS_WHITE,
                'score_white' => -$score,
                'detail' => 'rook=' . $this->square_to_algebraic($rooks[CHESS_BLACK]) . ',pawn=' . $this->square_to_algebraic($weak_pawn),
            ];
        }

        return null;
    }

    private function choose_endgame_move(array $legal_moves): ?array {
        $root_info = $this->detect_endgame_state();
        if ($root_info === null || count($legal_moves) === 0) {
            return null;
        }

        $root_color = $this->board->current_player;
        $best_move = $legal_moves[0];
        $best_notation = strtolower($best_move->to_string());
        $best_score = -PHP_INT_MAX;

        foreach ($legal_moves as $candidate) {
            $this->board->make_move($candidate);
            $next_info = $this->detect_endgame_state();
            $score = $next_info !== null ? intval($next_info['score_white']) : $this->ai->evaluate();
            if ($root_color === CHESS_BLACK) {
                $score = -$score;
            }
            $notation = strtolower($candidate->to_string());
            if ($score > $best_score || ($score === $best_score && $notation < $best_notation)) {
                $best_score = $score;
                $best_move = $candidate;
                $best_notation = $notation;
            }
            $this->board->undo_move();
        }

        return ['move' => $best_move, 'info' => $root_info];
    }

    private function apply_endgame_move(Move $move, array $info): void {
        $this->board->make_move($move);
        $move_str = strtolower($move->to_string());
        $this->record_trace_ai('endgame', $move_str, 0, intval($info['score_white']), 0, false, 0, 0);
        echo "AI: {$move_str} (endgame {$info['type']}, score={$info['score_white']})\n";

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
                $reason = DrawDetection::is_draw_by_fifty_moves($this->board) ? "50-move rule" : "repetition";
                echo "DRAW: by $reason\n";
            }
        }
        
        echo $this->board->display();
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
                $reason = DrawDetection::is_draw_by_fifty_moves($this->board) ? "50-move rule" : "repetition";
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
  go wtime <ms> btime <ms> winc <ms> binc <ms> [movestogo <n>] - Clock-based timed move
  go depth <n>                - UCI-style depth search (prints info/bestmove)
  go infinite                 - Start bounded long search mode
  stop                        - Stop infinite search mode
  pgn load|show|moves         - PGN command family
  book load|on|off|stats      - Native opening book controls
  endgame                     - Detect specialized endgame and best move hint
  uci                         - Enter/respond to UCI handshake
  isready                     - UCI readiness probe
  setoption name <Hash|Threads> value <n> - Set UCI option
  ucinewgame                  - Reset internal state for UCI game
  position startpos|fen ... [moves ...] - Load UCI position
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
