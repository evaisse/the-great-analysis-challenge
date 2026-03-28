<?php

namespace Chess;

require_once __DIR__ . '/Types.php';
require_once __DIR__ . '/AttackTables.php';
require_once __DIR__ . '/Board.php';

/**
 * Move generation and validation
 */
class MoveGenerator {
    private Board $board;
    private AttackTables $attackTables;
    
    public function __construct(Board $board) {
        $this->board = $board;
        $this->attackTables = AttackTables::getInstance();
    }
    
    public function generate_moves(): array {
        $moves = [];
        $color = $this->board->current_player;
        
        for ($row = 0; $row < 8; $row++) {
            for ($col = 0; $col < 8; $col++) {
                [$piece, $piece_color] = $this->board->get_piece($row, $col);
                if ($piece !== CHESS_EMPTY && $piece_color === $color) {
                    $moves = array_merge($moves, $this->generate_piece_moves($row, $col, $piece));
                }
            }
        }
        
        return array_filter($moves, fn($move) => $this->is_legal($move));
    }
    
    private function generate_piece_moves(int $row, int $col, int $piece): array {
        return match($piece) {
            CHESS_PAWN => $this->generate_pawn_moves($row, $col),
            CHESS_KNIGHT => $this->generate_knight_moves($row, $col),
            CHESS_BISHOP => $this->generate_bishop_moves($row, $col),
            CHESS_ROOK => $this->generate_rook_moves($row, $col),
            CHESS_QUEEN => $this->generate_queen_moves($row, $col),
            CHESS_KING => $this->generate_king_moves($row, $col),
            default => []
        };
    }
    
    private function generate_pawn_moves(int $row, int $col): array {
        $moves = [];
        $color = $this->board->current_player;
        $direction = $color === CHESS_WHITE ? -1 : 1;
        $start_row = $color === CHESS_WHITE ? 6 : 1;
        $promotion_row = $color === CHESS_WHITE ? 0 : 7;
        
        // Forward move
        $new_row = $row + $direction;
        if ($new_row >= 0 && $new_row < 8) {
            [$target_piece, $_] = $this->board->get_piece($new_row, $col);
            if ($target_piece === CHESS_EMPTY) {
                if ($new_row === $promotion_row) {
                    // Promotion
                    foreach ([CHESS_QUEEN, CHESS_ROOK, CHESS_BISHOP, CHESS_KNIGHT] as $promo) {
                        $moves[] = new Move($row, $col, $new_row, $col, $promo);
                    }
                } else {
                    $moves[] = new Move($row, $col, $new_row, $col);
                }
                
                // Double move from start
                if ($row === $start_row) {
                    $double_row = $row + 2 * $direction;
                    [$double_piece, $_] = $this->board->get_piece($double_row, $col);
                    if ($double_piece === CHESS_EMPTY) {
                        $moves[] = new Move($row, $col, $double_row, $col);
                    }
                }
            }
        }
        
        // Captures
        foreach ([-1, 1] as $dcol) {
            $new_col = $col + $dcol;
            if ($new_row >= 0 && $new_row < 8 && $new_col >= 0 && $new_col < 8) {
                [$target_piece, $target_color] = $this->board->get_piece($new_row, $new_col);
                
                // Regular capture
                if ($target_piece !== CHESS_EMPTY && $target_color !== $color) {
                    if ($new_row === $promotion_row) {
                        foreach ([CHESS_QUEEN, CHESS_ROOK, CHESS_BISHOP, CHESS_KNIGHT] as $promo) {
                            $moves[] = new Move($row, $col, $new_row, $new_col, $promo);
                        }
                    } else {
                        $moves[] = new Move($row, $col, $new_row, $new_col);
                    }
                }
                
                // En passant
                if ($this->board->en_passant_target !== null) {
                    [$ep_row, $ep_col] = $this->board->en_passant_target;
                    if ($new_row === $ep_row && $new_col === $ep_col) {
                        $moves[] = new Move($row, $col, $new_row, $new_col, null, false, true);
                    }
                }
            }
        }
        
        return $moves;
    }
    
    private function generate_knight_moves(int $row, int $col): array {
        $moves = [];
        foreach ($this->attackTables->knightAttacks($row, $col) as [$new_row, $new_col]) {
            [$target_piece, $target_color] = $this->board->get_piece($new_row, $new_col);
            if ($target_piece === CHESS_EMPTY || $target_color !== $this->board->current_player) {
                $moves[] = new Move($row, $col, $new_row, $new_col);
            }
        }
        
        return $moves;
    }
    
    private function generate_sliding_moves(int $row, int $col, array $directions): array {
        $moves = [];
        
        foreach ($directions as [$drow, $dcol]) {
            foreach ($this->attackTables->rayAttacks($row, $col, $drow, $dcol) as [$new_row, $new_col]) {
                [$target_piece, $target_color] = $this->board->get_piece($new_row, $new_col);
                
                if ($target_piece === CHESS_EMPTY) {
                    $moves[] = new Move($row, $col, $new_row, $new_col);
                } else {
                    if ($target_color !== $this->board->current_player) {
                        $moves[] = new Move($row, $col, $new_row, $new_col);
                    }
                    break;
                }
            }
        }
        
        return $moves;
    }
    
    private function generate_bishop_moves(int $row, int $col): array {
        return $this->generate_sliding_moves($row, $col, [[-1, -1], [-1, 1], [1, -1], [1, 1]]);
    }
    
    private function generate_rook_moves(int $row, int $col): array {
        return $this->generate_sliding_moves($row, $col, [[-1, 0], [1, 0], [0, -1], [0, 1]]);
    }
    
    private function generate_queen_moves(int $row, int $col): array {
        return array_merge(
            $this->generate_rook_moves($row, $col),
            $this->generate_bishop_moves($row, $col)
        );
    }
    
    private function generate_king_moves(int $row, int $col): array {
        $moves = [];
        foreach ($this->attackTables->kingAttacks($row, $col) as [$new_row, $new_col]) {
            [$target_piece, $target_color] = $this->board->get_piece($new_row, $new_col);
            if ($target_piece === CHESS_EMPTY || $target_color !== $this->board->current_player) {
                $moves[] = new Move($row, $col, $new_row, $new_col);
            }
        }

        if (!$this->is_square_attacked($row, $col, 1 - $this->board->current_player)) {
            $moves = array_merge($moves, $this->generate_castling_moves($row, $col));
        }
        
        return $moves;
    }

    private function generate_castling_moves(int $row, int $col): array {
        $moves = [];
        $color = $this->board->current_player;
        $rights = $this->board->castling_rights;

        foreach ([
            ['K', $color === CHESS_WHITE ? $rights->white_kingside : $rights->black_kingside],
            ['Q', $color === CHESS_WHITE ? $rights->white_queenside : $rights->black_queenside],
        ] as [$side, $has_right]) {
            if (!$has_right) {
                continue;
            }

            [$king_start, $rook_start, $king_target, $rook_target] = $this->board->get_castle_details($color, $side);
            if ($row !== $king_start[0] || $col !== $king_start[1]) {
                continue;
            }

            [$rook_piece, $rook_color] = $this->board->get_piece($rook_start[0], $rook_start[1]);
            if ($rook_piece !== CHESS_ROOK || $rook_color !== $color) {
                continue;
            }

            $blocker_squares = [];
            $seen = [];
            foreach (array_merge(
                $this->board->line_path($king_start, $king_target),
                $this->board->line_path($rook_start, $rook_target)
            ) as $square) {
                $key = $square[0] . ':' . $square[1];
                if (!isset($seen[$key])) {
                    $seen[$key] = true;
                    $blocker_squares[] = $square;
                }
            }

            $blocked = false;
            foreach ($blocker_squares as [$square_row, $square_col]) {
                if (($square_row === $king_start[0] && $square_col === $king_start[1]) ||
                    ($square_row === $rook_start[0] && $square_col === $rook_start[1])) {
                    continue;
                }
                [$target_piece, $_] = $this->board->get_piece($square_row, $square_col);
                if ($target_piece !== CHESS_EMPTY) {
                    $blocked = true;
                    break;
                }
            }
            if ($blocked) {
                continue;
            }

            $attack_squares = array_merge([$king_start], $this->board->line_path($king_start, $king_target));
            $unsafe = false;
            $seen = [];
            foreach ($attack_squares as [$square_row, $square_col]) {
                $key = $square_row . ':' . $square_col;
                if (isset($seen[$key])) {
                    continue;
                }
                $seen[$key] = true;
                if ($this->is_square_attacked($square_row, $square_col, 1 - $color)) {
                    $unsafe = true;
                    break;
                }
            }
            if ($unsafe) {
                continue;
            }

            $moves[] = new Move($row, $col, $king_target[0], $king_target[1], null, true);
        }

        return $moves;
    }
    
    public function is_square_attacked(int $row, int $col, int $by_color): bool {
        $pawnDirection = $by_color === CHESS_WHITE ? 1 : -1;
        foreach ([$col - 1, $col + 1] as $pawnCol) {
            $pawnRow = $row - $pawnDirection;
            [$piece, $pieceColor] = $this->board->get_piece($pawnRow, $pawnCol);
            if ($piece === CHESS_PAWN && $pieceColor === $by_color) {
                return true;
            }
        }

        foreach ($this->attackTables->knightAttacks($row, $col) as [$attackRow, $attackCol]) {
            [$piece, $pieceColor] = $this->board->get_piece($attackRow, $attackCol);
            if ($piece === CHESS_KNIGHT && $pieceColor === $by_color) {
                return true;
            }
        }

        foreach ([[-1, -1], [-1, 1], [1, -1], [1, 1]] as [$drow, $dcol]) {
            foreach ($this->attackTables->rayAttacks($row, $col, $drow, $dcol) as [$attackRow, $attackCol]) {
                [$piece, $pieceColor] = $this->board->get_piece($attackRow, $attackCol);
                if ($piece !== CHESS_EMPTY) {
                    if ($pieceColor === $by_color && ($piece === CHESS_BISHOP || $piece === CHESS_QUEEN)) {
                        return true;
                    }
                    break;
                }
            }
        }

        foreach ([[-1, 0], [1, 0], [0, -1], [0, 1]] as [$drow, $dcol]) {
            foreach ($this->attackTables->rayAttacks($row, $col, $drow, $dcol) as [$attackRow, $attackCol]) {
                [$piece, $pieceColor] = $this->board->get_piece($attackRow, $attackCol);
                if ($piece !== CHESS_EMPTY) {
                    if ($pieceColor === $by_color && ($piece === CHESS_ROOK || $piece === CHESS_QUEEN)) {
                        return true;
                    }
                    break;
                }
            }
        }

        foreach ($this->attackTables->kingAttacks($row, $col) as [$attackRow, $attackCol]) {
            [$piece, $pieceColor] = $this->board->get_piece($attackRow, $attackCol);
            if ($piece === CHESS_KING && $pieceColor === $by_color) {
                return true;
            }
        }

        return false;
    }
    
    private function is_legal(Move $move): bool {
        $moving_piece = $this->board->get_piece($move->from_row, $move->from_col);
        if ($moving_piece[0] === CHESS_PAWN && ($move->to_row === 0 || $move->to_row === 7) && $move->promotion === null) {
            $move->promotion = CHESS_QUEEN;
        }

        // Make the move temporarily
        $this->board->make_move($move);

        // If the move removed the moving side's king from the board, it is invalid.
        // This can happen in malformed FEN inputs used by tests and must not crash.
        $king_color = 1 - $this->board->current_player;
        $king_row = -1;
        $king_col = -1;
        for ($row = 0; $row < 8; $row++) {
            for ($col = 0; $col < 8; $col++) {
                [$piece, $color] = $this->board->get_piece($row, $col);
                if ($piece === CHESS_KING && $color === $king_color) {
                    $king_row = $row;
                    $king_col = $col;
                    break 2;
                }
            }
        }
        if ($king_row === -1 || $king_col === -1) {
            if ($moving_piece[0] === CHESS_KING) {
                $this->board->undo_move();
                return false;
            }
            $this->board->undo_move();
            return true;
        }

        // Check if king is in check
        $is_legal = !$this->is_square_attacked($king_row, $king_col, $this->board->current_player);
        
        // Undo the move
        $this->board->undo_move();
        
        return $is_legal;
    }
    
    public function parse_move(string $move_str): ?Move {
        $move_str = trim($move_str);
        
        if (strlen($move_str) < 4) {
            return null;
        }
        
        $from_col = ord(strtolower($move_str[0])) - ord('a');
        $from_row = 8 - intval($move_str[1]);
        $to_col = ord(strtolower($move_str[2])) - ord('a');
        $to_row = 8 - intval($move_str[3]);
        
        if ($from_row < 0 || $from_row >= 8 || $from_col < 0 || $from_col >= 8 ||
            $to_row < 0 || $to_row >= 8 || $to_col < 0 || $to_col >= 8) {
            return null;
        }
        
        // Check for promotion
        $promotion = null;
        if (strlen($move_str) > 4) {
            $promo_char = strtoupper($move_str[4]);
            $promotion = match($promo_char) {
                'Q' => CHESS_QUEEN,
                'R' => CHESS_ROOK,
                'B' => CHESS_BISHOP,
                'N' => CHESS_KNIGHT,
                default => null
            };
        }
        
        // Auto-promote to queen if pawn reaches last rank
        [$piece, $_] = $this->board->get_piece($from_row, $from_col);
        if ($piece === CHESS_PAWN && ($to_row === 0 || $to_row === 7) && $promotion === null) {
            $promotion = CHESS_QUEEN;
        }
        
        // Check for castling
        $is_castling = false;
        if ($piece === CHESS_KING && ($to_col === 2 || $to_col === 6)) {
            $is_castling = true;
        }
        
        // Check for en passant
        $is_en_passant = false;
        if ($piece === CHESS_PAWN && $this->board->en_passant_target !== null) {
            [$ep_row, $ep_col] = $this->board->en_passant_target;
            if ($to_row === $ep_row && $to_col === $ep_col) {
                $is_en_passant = true;
            }
        }
        
        return new Move($from_row, $from_col, $to_row, $to_col, $promotion, $is_castling, $is_en_passant);
    }
    
    public function is_checkmate(): bool {
        return $this->is_in_check() && empty($this->generate_moves());
    }
    
    public function is_stalemate(): bool {
        return !$this->is_in_check() && empty($this->generate_moves());
    }
    
    public function is_in_check(): bool {
        // Find king position
        for ($row = 0; $row < 8; $row++) {
            for ($col = 0; $col < 8; $col++) {
                [$piece, $color] = $this->board->get_piece($row, $col);
                if ($piece === CHESS_KING && $color === $this->board->current_player) {
                    return $this->is_square_attacked($row, $col, 1 - $this->board->current_player);
                }
            }
        }
        return false;
    }
}
