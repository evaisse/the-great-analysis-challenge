<?php

namespace Chess;

require_once __DIR__ . '/Types.php';
require_once __DIR__ . '/Board.php';

/**
 * Move generation and validation
 */
class MoveGenerator {
    private Board $board;
    
    public function __construct(Board $board) {
        $this->board = $board;
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
        $deltas = [[-2, -1], [-2, 1], [-1, -2], [-1, 2], [1, -2], [1, 2], [2, -1], [2, 1]];
        
        foreach ($deltas as [$drow, $dcol]) {
            $new_row = $row + $drow;
            $new_col = $col + $dcol;
            if ($new_row >= 0 && $new_row < 8 && $new_col >= 0 && $new_col < 8) {
                [$target_piece, $target_color] = $this->board->get_piece($new_row, $new_col);
                if ($target_piece === CHESS_EMPTY || $target_color !== $this->board->current_player) {
                    $moves[] = new Move($row, $col, $new_row, $new_col);
                }
            }
        }
        
        return $moves;
    }
    
    private function generate_sliding_moves(int $row, int $col, array $directions): array {
        $moves = [];
        
        foreach ($directions as [$drow, $dcol]) {
            $new_row = $row + $drow;
            $new_col = $col + $dcol;
            
            while ($new_row >= 0 && $new_row < 8 && $new_col >= 0 && $new_col < 8) {
                [$target_piece, $target_color] = $this->board->get_piece($new_row, $new_col);
                
                if ($target_piece === CHESS_EMPTY) {
                    $moves[] = new Move($row, $col, $new_row, $new_col);
                } else {
                    if ($target_color !== $this->board->current_player) {
                        $moves[] = new Move($row, $col, $new_row, $new_col);
                    }
                    break;
                }
                
                $new_row += $drow;
                $new_col += $dcol;
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
        $deltas = [[-1, -1], [-1, 0], [-1, 1], [0, -1], [0, 1], [1, -1], [1, 0], [1, 1]];
        
        foreach ($deltas as [$drow, $dcol]) {
            $new_row = $row + $drow;
            $new_col = $col + $dcol;
            if ($new_row >= 0 && $new_row < 8 && $new_col >= 0 && $new_col < 8) {
                [$target_piece, $target_color] = $this->board->get_piece($new_row, $new_col);
                if ($target_piece === CHESS_EMPTY || $target_color !== $this->board->current_player) {
                    $moves[] = new Move($row, $col, $new_row, $new_col);
                }
            }
        }
        
        // Castling
        $color = $this->board->current_player;
        $base_row = $color === CHESS_WHITE ? 7 : 0;
        
        if ($row === $base_row && $col === 4) {
            // Kingside castling
            $can_castle_kingside = $color === CHESS_WHITE ? $this->board->castling_rights[0] : $this->board->castling_rights[2];
            if ($can_castle_kingside) {
                [$r1, $_] = $this->board->get_piece($base_row, 5);
                [$r2, $_] = $this->board->get_piece($base_row, 6);
                if ($r1 === CHESS_EMPTY && $r2 === CHESS_EMPTY) {
                    if (!$this->is_square_attacked($base_row, 4, 1 - $color) &&
                        !$this->is_square_attacked($base_row, 5, 1 - $color) &&
                        !$this->is_square_attacked($base_row, 6, 1 - $color)) {
                        $moves[] = new Move($row, $col, $base_row, 6, null, true);
                    }
                }
            }
            
            // Queenside castling
            $can_castle_queenside = $color === CHESS_WHITE ? $this->board->castling_rights[1] : $this->board->castling_rights[3];
            if ($can_castle_queenside) {
                [$r1, $_] = $this->board->get_piece($base_row, 1);
                [$r2, $_] = $this->board->get_piece($base_row, 2);
                [$r3, $_] = $this->board->get_piece($base_row, 3);
                if ($r1 === CHESS_EMPTY && $r2 === CHESS_EMPTY && $r3 === CHESS_EMPTY) {
                    if (!$this->is_square_attacked($base_row, 4, 1 - $color) &&
                        !$this->is_square_attacked($base_row, 3, 1 - $color) &&
                        !$this->is_square_attacked($base_row, 2, 1 - $color)) {
                        $moves[] = new Move($row, $col, $base_row, 2, null, true);
                    }
                }
            }
        }
        
        return $moves;
    }
    
    public function is_square_attacked(int $row, int $col, int $by_color): bool {
        // Check if square is attacked by any piece of given color
        for ($r = 0; $r < 8; $r++) {
            for ($c = 0; $c < 8; $c++) {
                [$piece, $piece_color] = $this->board->get_piece($r, $c);
                if ($piece !== CHESS_EMPTY && $piece_color === $by_color) {
                    if ($this->can_piece_attack($r, $c, $piece, $row, $col)) {
                        return true;
                    }
                }
            }
        }
        return false;
    }
    
    private function can_piece_attack(int $from_row, int $from_col, int $piece, int $to_row, int $to_col): bool {
        $drow = $to_row - $from_row;
        $dcol = $to_col - $from_col;
        
        if ($piece === CHESS_PAWN) {
            $direction = $this->board->get_piece($from_row, $from_col)[1] === CHESS_WHITE ? -1 : 1;
            return $drow === $direction && abs($dcol) === 1;
        } elseif ($piece === CHESS_KNIGHT) {
            return (abs($drow) === 2 && abs($dcol) === 1) || (abs($drow) === 1 && abs($dcol) === 2);
        } elseif ($piece === CHESS_KING) {
            return abs($drow) <= 1 && abs($dcol) <= 1;
        }
        
        // Sliding pieces
        if ($piece === CHESS_BISHOP || $piece === CHESS_QUEEN) {
            if (abs($drow) === abs($dcol) && $drow !== 0) {
                return $this->is_path_clear($from_row, $from_col, $to_row, $to_col);
            }
        }
        
        if ($piece === CHESS_ROOK || $piece === CHESS_QUEEN) {
            if (($drow === 0 && $dcol !== 0) || ($drow !== 0 && $dcol === 0)) {
                return $this->is_path_clear($from_row, $from_col, $to_row, $to_col);
            }
        }
        
        return false;
    }
    
    private function is_path_clear(int $from_row, int $from_col, int $to_row, int $to_col): bool {
        $drow = $to_row <=> $from_row;
        $dcol = $to_col <=> $from_col;
        
        $row = $from_row + $drow;
        $col = $from_col + $dcol;
        
        while ($row !== $to_row || $col !== $to_col) {
            [$piece, $_] = $this->board->get_piece($row, $col);
            if ($piece !== CHESS_EMPTY) {
                return false;
            }
            $row += $drow;
            $col += $dcol;
        }
        
        return true;
    }
    
    private function is_legal(Move $move): bool {
        // Make the move temporarily
        $this->board->make_move($move);
        
        // Find king position
        $king_row = -1;
        $king_col = -1;
        $king_color = 1 - $this->board->current_player;
        
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
        if ($piece === CHESS_KING && abs($to_col - $from_col) === 2) {
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
