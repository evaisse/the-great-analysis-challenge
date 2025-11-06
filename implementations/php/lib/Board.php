<?php

namespace Chess;

require_once __DIR__ . '/Types.php';

/**
 * Chess board representation
 */
class Board {
    public array $squares;  // 8x8 array of [piece, color]
    public int $current_player;
    public array $castling_rights;  // [white_kingside, white_queenside, black_kingside, black_queenside]
    public ?array $en_passant_target;  // [row, col] or null
    public int $halfmove_clock;
    public int $fullmove_number;
    public array $move_history;
    
    public function __construct() {
        $this->reset();
    }
    
    public function reset(): void {
        // Initialize board to starting position
        $this->squares = array_fill(0, 8, array_fill(0, 8, [CHESS_EMPTY, CHESS_WHITE]));
        
        // Set up pieces
        // Black pieces (row 0 and 1)
        $back_rank = [CHESS_ROOK, CHESS_KNIGHT, CHESS_BISHOP, CHESS_QUEEN, CHESS_KING, CHESS_BISHOP, CHESS_KNIGHT, CHESS_ROOK];
        for ($col = 0; $col < 8; $col++) {
            $this->squares[0][$col] = [$back_rank[$col], CHESS_BLACK];
            $this->squares[1][$col] = [CHESS_PAWN, CHESS_BLACK];
            $this->squares[6][$col] = [CHESS_PAWN, CHESS_WHITE];
            $this->squares[7][$col] = [$back_rank[$col], CHESS_WHITE];
        }
        
        $this->current_player = CHESS_WHITE;
        $this->castling_rights = [true, true, true, true];  // KQkq
        $this->en_passant_target = null;
        $this->halfmove_clock = 0;
        $this->fullmove_number = 1;
        $this->move_history = [];
    }
    
    public function display(): string {
        $output = "\n  a b c d e f g h\n";
        
        for ($row = 0; $row < 8; $row++) {
            $output .= (8 - $row) . " ";
            for ($col = 0; $col < 8; $col++) {
                [$piece, $color] = $this->squares[$row][$col];
                $output .= $this->piece_to_char($piece, $color) . " ";
            }
            $output .= (8 - $row) . "\n";
        }
        
        $output .= "  a b c d e f g h\n\n";
        $output .= ($this->current_player === CHESS_WHITE ? "White" : "Black") . " to move\n";
        
        return $output;
    }
    
    private function piece_to_char(int $piece, int $color): string {
        if ($piece === CHESS_EMPTY) {
            return '.';
        }
        
        $chars = [
            CHESS_PAWN => 'P',
            CHESS_KNIGHT => 'N',
            CHESS_BISHOP => 'B',
            CHESS_ROOK => 'R',
            CHESS_QUEEN => 'Q',
            CHESS_KING => 'K'
        ];
        
        $char = $chars[$piece] ?? '.';
        return $color === CHESS_BLACK ? strtolower($char) : $char;
    }
    
    public function get_piece(int $row, int $col): array {
        if ($row < 0 || $row >= 8 || $col < 0 || $col >= 8) {
            return [CHESS_EMPTY, CHESS_WHITE];
        }
        return $this->squares[$row][$col];
    }
    
    public function set_piece(int $row, int $col, int $piece, int $color): void {
        if ($row >= 0 && $row < 8 && $col >= 0 && $col < 8) {
            $this->squares[$row][$col] = [$piece, $color];
        }
    }
    
    public function make_move(Move $move): void {
        // Store state for undo
        $state = [
            'move' => $move,
            'captured_piece' => $this->squares[$move->to_row][$move->to_col],
            'castling_rights' => $this->castling_rights,
            'en_passant_target' => $this->en_passant_target,
            'halfmove_clock' => $this->halfmove_clock,
            'fullmove_number' => $this->fullmove_number
        ];
        
        [$piece, $color] = $this->squares[$move->from_row][$move->from_col];
        
        // Handle en passant capture
        if ($move->is_en_passant) {
            $captured_row = $move->from_row;
            $captured_col = $move->to_col;
            $state['en_passant_captured'] = $this->squares[$captured_row][$captured_col];
            $this->squares[$captured_row][$captured_col] = [CHESS_EMPTY, CHESS_WHITE];
        }
        
        // Handle castling
        if ($move->is_castling) {
            $rook_from_col = $move->to_col > $move->from_col ? 7 : 0;
            $rook_to_col = $move->to_col > $move->from_col ? 5 : 3;
            $this->squares[$move->from_row][$rook_to_col] = $this->squares[$move->from_row][$rook_from_col];
            $this->squares[$move->from_row][$rook_from_col] = [CHESS_EMPTY, CHESS_WHITE];
        }
        
        // Move the piece
        $this->squares[$move->to_row][$move->to_col] = [$piece, $color];
        $this->squares[$move->from_row][$move->from_col] = [CHESS_EMPTY, CHESS_WHITE];
        
        // Handle promotion
        if ($move->promotion !== null) {
            $this->squares[$move->to_row][$move->to_col] = [$move->promotion, $color];
        }
        
        // Update castling rights
        if ($piece === CHESS_KING) {
            if ($color === CHESS_WHITE) {
                $this->castling_rights[0] = false;
                $this->castling_rights[1] = false;
            } else {
                $this->castling_rights[2] = false;
                $this->castling_rights[3] = false;
            }
        } elseif ($piece === CHESS_ROOK) {
            if ($move->from_row === 7 && $move->from_col === 7) {
                $this->castling_rights[0] = false;  // White kingside
            } elseif ($move->from_row === 7 && $move->from_col === 0) {
                $this->castling_rights[1] = false;  // White queenside
            } elseif ($move->from_row === 0 && $move->from_col === 7) {
                $this->castling_rights[2] = false;  // Black kingside
            } elseif ($move->from_row === 0 && $move->from_col === 0) {
                $this->castling_rights[3] = false;  // Black queenside
            }
        }
        
        // Set en passant target
        $this->en_passant_target = null;
        if ($piece === CHESS_PAWN && abs($move->to_row - $move->from_row) === 2) {
            $this->en_passant_target = [
                ($move->from_row + $move->to_row) / 2,
                $move->from_col
            ];
        }
        
        // Update clocks
        if ($piece === CHESS_PAWN || $state['captured_piece'][0] !== CHESS_EMPTY) {
            $this->halfmove_clock = 0;
        } else {
            $this->halfmove_clock++;
        }
        
        if ($this->current_player === CHESS_BLACK) {
            $this->fullmove_number++;
        }
        
        $this->current_player = 1 - $this->current_player;
        $this->move_history[] = $state;
    }
    
    public function undo_move(): bool {
        if (empty($this->move_history)) {
            return false;
        }
        
        $state = array_pop($this->move_history);
        $move = $state['move'];
        
        // Restore board state
        [$piece, $color] = $this->squares[$move->to_row][$move->to_col];
        
        // Handle promotion - restore pawn
        if ($move->promotion !== null) {
            $piece = CHESS_PAWN;
        }
        
        // Move piece back
        $this->squares[$move->from_row][$move->from_col] = [$piece, $color];
        $this->squares[$move->to_row][$move->to_col] = $state['captured_piece'];
        
        // Restore en passant captured piece
        if (isset($state['en_passant_captured'])) {
            $captured_row = $move->from_row;
            $captured_col = $move->to_col;
            $this->squares[$captured_row][$captured_col] = $state['en_passant_captured'];
        }
        
        // Restore castling rook
        if ($move->is_castling) {
            $rook_from_col = $move->to_col > $move->from_col ? 7 : 0;
            $rook_to_col = $move->to_col > $move->from_col ? 5 : 3;
            $this->squares[$move->from_row][$rook_from_col] = $this->squares[$move->from_row][$rook_to_col];
            $this->squares[$move->from_row][$rook_to_col] = [CHESS_EMPTY, CHESS_WHITE];
        }
        
        // Restore state
        $this->castling_rights = $state['castling_rights'];
        $this->en_passant_target = $state['en_passant_target'];
        $this->halfmove_clock = $state['halfmove_clock'];
        $this->fullmove_number = $state['fullmove_number'];
        $this->current_player = 1 - $this->current_player;
        
        return true;
    }
}
