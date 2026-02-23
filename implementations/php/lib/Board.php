<?php

namespace Chess;

require_once __DIR__ . '/Types.php';

/**
 * Chess board representation
 */
class Board {
    public array $squares;  // 8x8 array of [piece, color]
    public int $current_player;
    public CastlingRights $castling_rights;
    public ?array $en_passant_target;  // [row, col] or null
    public int $halfmove_clock;
    public int $fullmove_number;
    public array $game_history;
    public int $zobrist_hash;
    public array $position_history;
    public array $irreversible_history;
    
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
        $this->castling_rights = new CastlingRights();
        $this->en_passant_target = null;
        $this->halfmove_clock = 0;
        $this->fullmove_number = 1;
        $this->game_history = [];
        $this->position_history = [];
        $this->irreversible_history = [];
        
        require_once __DIR__ . '/Zobrist.php';
        $this->zobrist_hash = Zobrist::getInstance()->compute_hash($this);
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
        $zobrist = Zobrist::getInstance();
        
        // Save current state
        $this->irreversible_history[] = new IrreversibleState(
            $this->castling_rights->copy(),
            $this->en_passant_target,
            $this->halfmove_clock,
            $this->zobrist_hash
        );
        $this->position_history[] = $this->zobrist_hash;

        $hash = $this->zobrist_hash;
        
        [$piece, $color] = $this->squares[$move->from_row][$move->from_col];
        $target = $this->squares[$move->to_row][$move->to_col];

        // 1. Remove moving piece from source
        $hash ^= $zobrist->pieces[$zobrist->get_piece_index($piece, $color)][(7 - $move->from_row) * 8 + $move->from_col];

        // 2. Handle capture
        $move->captured_piece = null;
        if ($move->is_en_passant) {
            $captured_row = $move->from_row;
            $captured_col = $move->to_col;
            $captured_piece = $this->squares[$captured_row][$captured_col];
            $move->captured_piece = $captured_piece;
            $hash ^= $zobrist->pieces[$zobrist->get_piece_index($captured_piece[0], $captured_piece[1])][(7 - $captured_row) * 8 + $captured_col];
            $this->squares[$captured_row][$captured_col] = [CHESS_EMPTY, CHESS_WHITE];
        } elseif ($target[0] !== CHESS_EMPTY) {
            $move->captured_piece = $target;
            $hash ^= $zobrist->pieces[$zobrist->get_piece_index($target[0], $target[1])][(7 - $move->to_row) * 8 + $move->to_col];
        }

        // 3. Place piece at destination
        $final_piece = $piece;
        if ($move->promotion !== null) {
            $final_piece = $move->promotion;
        }
        $hash ^= $zobrist->pieces[$zobrist->get_piece_index($final_piece, $color)][(7 - $move->to_row) * 8 + $move->to_col];
        $this->squares[$move->to_row][$move->to_col] = [$final_piece, $color];
        $this->squares[$move->from_row][$move->from_col] = [CHESS_EMPTY, CHESS_WHITE];

        // 4. Handle castling rook
        if ($move->is_castling) {
            $rook_from_col = $move->to_col > $move->from_col ? 7 : 0;
            $rook_to_col = $move->to_col > $move->from_col ? 5 : 3;
            $rook = $this->squares[$move->from_row][$rook_from_col];
            $hash ^= $zobrist->pieces[$zobrist->get_piece_index($rook[0], $rook[1])][(7 - $move->from_row) * 8 + $rook_from_col];
            $hash ^= $zobrist->pieces[$zobrist->get_piece_index($rook[0], $rook[1])][(7 - $move->from_row) * 8 + $rook_to_col];
            $this->squares[$move->from_row][$rook_to_col] = $this->squares[$move->from_row][$rook_from_col];
            $this->squares[$move->from_row][$rook_from_col] = [CHESS_EMPTY, CHESS_WHITE];
        }

        // 5. Update castling rights in hash
        if ($this->castling_rights->white_kingside) $hash ^= $zobrist->castling[0];
        if ($this->castling_rights->white_queenside) $hash ^= $zobrist->castling[1];
        if ($this->castling_rights->black_kingside) $hash ^= $zobrist->castling[2];
        if ($this->castling_rights->black_queenside) $hash ^= $zobrist->castling[3];

        if ($piece === CHESS_KING) {
            if ($color === CHESS_WHITE) {
                $this->castling_rights->white_kingside = false;
                $this->castling_rights->white_queenside = false;
            } else {
                $this->castling_rights->black_kingside = false;
                $this->castling_rights->black_queenside = false;
            }
        }
        
        if (($move->from_row === 7 && $move->from_col === 7) || ($move->to_row === 7 && $move->to_col === 7)) $this->castling_rights->white_kingside = false;
        if (($move->from_row === 7 && $move->from_col === 0) || ($move->to_row === 7 && $move->to_col === 0)) $this->castling_rights->white_queenside = false;
        if (($move->from_row === 0 && $move->from_col === 7) || ($move->to_row === 0 && $move->to_col === 7)) $this->castling_rights->black_kingside = false;
        if (($move->from_row === 0 && $move->from_col === 0) || ($move->to_row === 0 && $move->to_col === 0)) $this->castling_rights->black_queenside = false;

        if ($this->castling_rights->white_kingside) $hash ^= $zobrist->castling[0];
        if ($this->castling_rights->white_queenside) $hash ^= $zobrist->castling[1];
        if ($this->castling_rights->black_kingside) $hash ^= $zobrist->castling[2];
        if ($this->castling_rights->black_queenside) $hash ^= $zobrist->castling[3];

        // 6. Update en passant target in hash
        if ($this->en_passant_target !== null) {
            $hash ^= $zobrist->en_passant[$this->en_passant_target[1]];
        }
        
        $this->en_passant_target = null;
        if ($piece === CHESS_PAWN && abs($move->to_row - $move->from_row) === 2) {
            $this->en_passant_target = [intval(($move->from_row + $move->to_row) / 2), $move->from_col];
            $hash ^= $zobrist->en_passant[$this->en_passant_target[1]];
        }

        // 7. Update side to move and clocks
        $hash ^= $zobrist->side_to_move;
        if ($piece === CHESS_PAWN || ($move->captured_piece !== null && $move->captured_piece[0] !== CHESS_EMPTY)) {
            $this->halfmove_clock = 0;
        } else {
            $this->halfmove_clock++;
        }
        
        if ($this->current_player === CHESS_BLACK) {
            $this->fullmove_number++;
        }
        
        $this->current_player = 1 - $this->current_player;
        $this->zobrist_hash = $hash;
        $this->game_history[] = $move;
    }
    
    public function undo_move(): bool {
        if (empty($this->irreversible_history)) {
            return false;
        }
        
        $move = array_pop($this->game_history);
        $old_state = array_pop($this->irreversible_history);
        array_pop($this->position_history);

        // Restore turn
        if ($this->current_player === CHESS_WHITE) {
            $this->fullmove_number--;
        }
        $this->current_player = 1 - $this->current_player;

        // Restore piece
        [$piece, $color] = $this->squares[$move->to_row][$move->to_col];
        $original_piece = ($move->promotion !== null) ? CHESS_PAWN : $piece;
        $this->squares[$move->from_row][$move->from_col] = [$original_piece, $color];
        
        // Restore capture
        if ($move->is_en_passant) {
            $this->squares[$move->to_row][$move->to_col] = [CHESS_EMPTY, CHESS_WHITE];
            $this->squares[$move->from_row][$move->to_col] = $move->captured_piece;
        } else {
            $this->squares[$move->to_row][$move->to_col] = $move->captured_piece ?? [CHESS_EMPTY, CHESS_WHITE];
        }

        // Restore castling rook
        if ($move->is_castling) {
            $rook_from_col = $move->to_col > $move->from_col ? 7 : 0;
            $rook_to_col = $move->to_col > $move->from_col ? 5 : 3;
            $this->squares[$move->from_row][$rook_from_col] = $this->squares[$move->from_row][$rook_to_col];
            $this->squares[$move->from_row][$rook_to_col] = [CHESS_EMPTY, CHESS_WHITE];
        }

        // Restore state
        $this->castling_rights = $old_state->castling_rights;
        $this->en_passant_target = $old_state->en_passant_target;
        $this->halfmove_clock = $old_state->halfmove_clock;
        $this->zobrist_hash = $old_state->zobrist_hash;
        
        return true;
    }
}
