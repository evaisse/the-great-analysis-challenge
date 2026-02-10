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
                // Only output AI message if game continues
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
        echo "Hash: " . str_pad(gmp_strval($this->board->zobrist_hash, 16), 16, "0", STR_PAD_LEFT) . "\n";
    }

    private function handle_draws(): void {
        require_once __DIR__ . '/lib/DrawDetection.php';
        $repetition = DrawDetection::is_draw_by_repetition($this->board);
        $fifty_moves = DrawDetection::is_draw_by_fifty_moves($this->board);
        echo "Repetition: " . ($repetition ? "true" : "false") . 
             ", 50-move rule: " . ($fifty_moves ? "true" : "false") . 
             ", 50-move clock: " . $this->board->halfmove_clock . "\n";
    }

    private function handle_history(): void {
        echo "Position History (" . (count($this->board->position_history) + 1) . " positions):\n";
        foreach ($this->board->position_history as $i => $h) {
            echo "  $i: " . str_pad(gmp_strval($h, 16), 16, "0", STR_PAD_LEFT) . "\n";
        }
        echo "  " . count($this->board->position_history) . ": " . str_pad(gmp_strval($this->board->zobrist_hash, 16), 16, "0", STR_PAD_LEFT) . " (current)\n";
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
  perft <depth>               - Performance test (count moves at depth)
  help                        - Display this help message
  quit                        - Exit the program

HELP;
    }
}

// Start the engine
$engine = new ChessEngine();
$engine->start();
