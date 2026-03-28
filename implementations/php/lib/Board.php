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
    public CastlingConfig $castling_config;
    public bool $chess960_mode;
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
        $this->castling_config = new CastlingConfig();
        $this->chess960_mode = false;
        $this->en_passant_target = null;
        $this->halfmove_clock = 0;
        $this->fullmove_number = 1;
        $this->game_history = [];
        $this->position_history = [];
        $this->irreversible_history = [];
        
        require_once __DIR__ . '/Zobrist.php';
        $this->zobrist_hash = Zobrist::getInstance()->compute_hash($this);
    }

    public function line_path(array $start, array $target): array {
        if ($start[0] === $target[0] && $start[1] === $target[1]) {
            return [];
        }

        $row_step = $target[0] === $start[0] ? 0 : ($target[0] > $start[0] ? 1 : -1);
        $col_step = $target[1] === $start[1] ? 0 : ($target[1] > $start[1] ? 1 : -1);
        $row = $start[0] + $row_step;
        $col = $start[1] + $col_step;
        $squares = [];

        while ($row !== $target[0] || $col !== $target[1]) {
            $squares[] = [$row, $col];
            $row += $row_step;
            $col += $col_step;
        }

        $squares[] = $target;
        return $squares;
    }

    public function get_castle_details(int $color, string $side): array {
        if ($color === CHESS_WHITE) {
            return [
                [7, $this->castling_config->white_king_col],
                [7, $side === 'K' ? $this->castling_config->white_kingside_rook_col : $this->castling_config->white_queenside_rook_col],
                [7, $side === 'K' ? 6 : 2],
                [7, $side === 'K' ? 5 : 3],
            ];
        }

        return [
            [0, $this->castling_config->black_king_col],
            [0, $side === 'K' ? $this->castling_config->black_kingside_rook_col : $this->castling_config->black_queenside_rook_col],
            [0, $side === 'K' ? 6 : 2],
            [0, $side === 'K' ? 5 : 3],
        ];
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

    public function find_home_rank_piece(int $color, int $piece_type): ?int {
        $row = $color === CHESS_WHITE ? 7 : 0;
        for ($col = 0; $col < 8; $col++) {
            [$piece, $piece_color] = $this->get_piece($row, $col);
            if ($piece === $piece_type && $piece_color === $color) {
                return $col;
            }
        }
        return null;
    }

    public function configure_chess960(): void {
        $white_king_col = $this->find_home_rank_piece(CHESS_WHITE, CHESS_KING);
        $black_king_col = $this->find_home_rank_piece(CHESS_BLACK, CHESS_KING);

        if ($white_king_col === null || $black_king_col === null) {
            $this->castling_config = new CastlingConfig();
            $this->chess960_mode = false;
            return;
        }

        $white_rooks = [];
        $black_rooks = [];
        for ($col = 0; $col < 8; $col++) {
            [$white_piece, $white_color] = $this->get_piece(7, $col);
            if ($white_piece === CHESS_ROOK && $white_color === CHESS_WHITE) {
                $white_rooks[] = $col;
            }
            [$black_piece, $black_color] = $this->get_piece(0, $col);
            if ($black_piece === CHESS_ROOK && $black_color === CHESS_BLACK) {
                $black_rooks[] = $col;
            }
        }

        if (count($white_rooks) === 0 || count($black_rooks) === 0) {
            $this->castling_config = new CastlingConfig();
            $this->chess960_mode = false;
            return;
        }

        $config = new CastlingConfig();
        $config->white_king_col = $white_king_col;
        $config->black_king_col = $black_king_col;

        $white_kingside = array_values(array_filter($white_rooks, fn(int $col): bool => $col > $white_king_col));
        $white_queenside = array_values(array_filter($white_rooks, fn(int $col): bool => $col < $white_king_col));
        $black_kingside = array_values(array_filter($black_rooks, fn(int $col): bool => $col > $black_king_col));
        $black_queenside = array_values(array_filter($black_rooks, fn(int $col): bool => $col < $black_king_col));

        $config->white_kingside_rook_col = count($white_kingside) > 0 ? max($white_kingside) : 7;
        $config->white_queenside_rook_col = count($white_queenside) > 0 ? min($white_queenside) : 0;
        $config->black_kingside_rook_col = count($black_kingside) > 0 ? max($black_kingside) : 7;
        $config->black_queenside_rook_col = count($black_queenside) > 0 ? min($black_queenside) : 0;

        $this->castling_config = $config;
        $this->chess960_mode = !$config->is_classical();
    }
    
    public function make_move(Move $move): void {
        $zobrist = Zobrist::getInstance();
        
        // Save current state
        $this->irreversible_history[] = new IrreversibleState(
            $this->castling_rights->copy(),
            $this->castling_config->copy(),
            $this->chess960_mode,
            $this->en_passant_target,
            $this->halfmove_clock,
            $this->zobrist_hash
        );
        $this->position_history[] = $this->zobrist_hash;

        $hash = $this->zobrist_hash;
        
        [$piece, $color] = $this->squares[$move->from_row][$move->from_col];
        $target = $this->squares[$move->to_row][$move->to_col];
        $captured_piece_for_clock = $target;
        if ($move->is_castling) {
            $captured_piece_for_clock = [CHESS_EMPTY, CHESS_WHITE];
        }

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
        } elseif (!$move->is_castling && $target[0] !== CHESS_EMPTY) {
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
            [$rook_from_col, $rook_to_col] = $this->castling_rook_columns($color, $move->to_col);
            $rook = $this->squares[$move->from_row][$rook_from_col];
            $hash ^= $zobrist->pieces[$zobrist->get_piece_index($rook[0], $rook[1])][(7 - $move->from_row) * 8 + $rook_from_col];
            $hash ^= $zobrist->pieces[$zobrist->get_piece_index($rook[0], $rook[1])][(7 - $move->from_row) * 8 + $rook_to_col];
            $this->squares[$move->from_row][$move->to_col] = [CHESS_EMPTY, CHESS_WHITE];
            if ($rook_from_col !== $move->from_col) {
                $this->squares[$move->from_row][$rook_from_col] = [CHESS_EMPTY, CHESS_WHITE];
            }
            $this->squares[$move->from_row][$move->from_col] = [CHESS_EMPTY, CHESS_WHITE];
            $this->squares[$move->to_row][$move->to_col] = [$final_piece, $color];
            $this->squares[$move->from_row][$rook_to_col] = $rook;
        }

        // 5. Update castling rights in hash
        if ($this->castling_rights->white_kingside) $hash ^= $zobrist->castling[0];
        if ($this->castling_rights->white_queenside) $hash ^= $zobrist->castling[1];
        if ($this->castling_rights->black_kingside) $hash ^= $zobrist->castling[2];
        if ($this->castling_rights->black_queenside) $hash ^= $zobrist->castling[3];

        $this->update_castling_rights($move, $piece, $color);

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
        if ($piece === CHESS_PAWN || ($captured_piece_for_clock[0] ?? CHESS_EMPTY) !== CHESS_EMPTY || $move->is_en_passant) {
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
            [$rook_from_col, $rook_to_col] = $this->castling_rook_columns($color, $move->to_col);
            $this->squares[$move->from_row][$rook_from_col] = $this->squares[$move->from_row][$rook_to_col];
            if ($rook_to_col !== $move->from_col) {
                $this->squares[$move->from_row][$rook_to_col] = [CHESS_EMPTY, CHESS_WHITE];
            }
            if ($move->to_col !== $rook_from_col) {
                $this->squares[$move->to_row][$move->to_col] = [CHESS_EMPTY, CHESS_WHITE];
            }
        }

        // Restore state
        $this->castling_rights = $old_state->castling_rights;
        $this->castling_config = $old_state->castling_config;
        $this->chess960_mode = $old_state->chess960_mode;
        $this->en_passant_target = $old_state->en_passant_target;
        $this->halfmove_clock = $old_state->halfmove_clock;
        $this->zobrist_hash = $old_state->zobrist_hash;
        
        return true;
    }

    private function castling_rook_columns(int $color, int $king_target_col): array {
        if ($color === CHESS_WHITE) {
            return $king_target_col === 6
                ? [$this->castling_config->white_kingside_rook_col, 5]
                : [$this->castling_config->white_queenside_rook_col, 3];
        }

        return $king_target_col === 6
            ? [$this->castling_config->black_kingside_rook_col, 5]
            : [$this->castling_config->black_queenside_rook_col, 3];
    }

    private function update_castling_rights(Move $move, int $piece, int $color): void {
        if ($piece === CHESS_KING) {
            if ($color === CHESS_WHITE) {
                $this->castling_rights->white_kingside = false;
                $this->castling_rights->white_queenside = false;
            } else {
                $this->castling_rights->black_kingside = false;
                $this->castling_rights->black_queenside = false;
            }
        } elseif ($piece === CHESS_ROOK) {
            if ($color === CHESS_WHITE) {
                if ($move->from_row === 7 && $move->from_col === $this->castling_config->white_queenside_rook_col) {
                    $this->castling_rights->white_queenside = false;
                } elseif ($move->from_row === 7 && $move->from_col === $this->castling_config->white_kingside_rook_col) {
                    $this->castling_rights->white_kingside = false;
                }
            } else {
                if ($move->from_row === 0 && $move->from_col === $this->castling_config->black_queenside_rook_col) {
                    $this->castling_rights->black_queenside = false;
                } elseif ($move->from_row === 0 && $move->from_col === $this->castling_config->black_kingside_rook_col) {
                    $this->castling_rights->black_kingside = false;
                }
            }
        }

        if ($move->to_row === 7 && $move->to_col === $this->castling_config->white_queenside_rook_col) {
            $this->castling_rights->white_queenside = false;
        } elseif ($move->to_row === 7 && $move->to_col === $this->castling_config->white_kingside_rook_col) {
            $this->castling_rights->white_kingside = false;
        } elseif ($move->to_row === 0 && $move->to_col === $this->castling_config->black_queenside_rook_col) {
            $this->castling_rights->black_queenside = false;
        } elseif ($move->to_row === 0 && $move->to_col === $this->castling_config->black_kingside_rook_col) {
            $this->castling_rights->black_kingside = false;
        }
    }
}
