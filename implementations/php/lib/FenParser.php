<?php

namespace Chess;

require_once __DIR__ . '/Types.php';
require_once __DIR__ . '/Board.php';

/**
 * FEN (Forsyth-Edwards Notation) parser and exporter
 */
class FenParser {
    private Board $board;
    
    public function __construct(Board $board) {
        $this->board = $board;
    }
    
    public function load_fen(string $fen): bool {
        $parts = preg_split('/\s+/', trim($fen));
        
        if (count($parts) < 4) {
            return false;
        }
        
        // Parse board position
        $rows = explode('/', $parts[0]);
        if (count($rows) !== 8) {
            return false;
        }
        
        for ($row = 0; $row < 8; $row++) {
            $col = 0;
            $row_str = $rows[$row];
            
            for ($i = 0; $i < strlen($row_str); $i++) {
                $char = $row_str[$i];
                
                if (is_numeric($char)) {
                    // Empty squares
                    $empty_count = intval($char);
                    for ($j = 0; $j < $empty_count; $j++) {
                        if ($col < 8) {
                            $this->board->set_piece($row, $col, CHESS_EMPTY, CHESS_WHITE);
                            $col++;
                        }
                    }
                } else {
                    // Piece
                    $piece = $this->char_to_piece($char);
                    $color = ctype_upper($char) ? CHESS_WHITE : CHESS_BLACK;
                    if ($col < 8 && $piece !== null) {
                        $this->board->set_piece($row, $col, $piece, $color);
                        $col++;
                    }
                }
            }
        }

        $this->board->castling_config = new CastlingConfig();
        $this->board->chess960_mode = false;
        $white_king_col = $this->board->find_home_rank_piece(CHESS_WHITE, CHESS_KING);
        $black_king_col = $this->board->find_home_rank_piece(CHESS_BLACK, CHESS_KING);
        if ($white_king_col !== null) {
            $this->board->castling_config->white_king_col = $white_king_col;
        }
        if ($black_king_col !== null) {
            $this->board->castling_config->black_king_col = $black_king_col;
        }
        
        // Parse active color
        $this->board->current_player = $parts[1] === 'w' ? CHESS_WHITE : CHESS_BLACK;
        
        // Parse castling rights
        $rights = new CastlingRights();
        $rights->white_kingside = false;
        $rights->white_queenside = false;
        $rights->black_kingside = false;
        $rights->black_queenside = false;
        
        if ($parts[2] !== '-') {
            for ($i = 0; $i < strlen($parts[2]); $i++) {
                $char = $parts[2][$i];
                switch ($char) {
                    case 'K':
                        $rights->white_kingside = true;
                        break;
                    case 'Q':
                        $rights->white_queenside = true;
                        break;
                    case 'k':
                        $rights->black_kingside = true;
                        break;
                    case 'q':
                        $rights->black_queenside = true;
                        break;
                    default:
                        if ($char >= 'A' && $char <= 'H' && $white_king_col !== null) {
                            $rook_col = ord($char) - ord('A');
                            $this->board->chess960_mode = true;
                            if ($rook_col > $white_king_col) {
                                $rights->white_kingside = true;
                                $this->board->castling_config->white_kingside_rook_col = $rook_col;
                            } else {
                                $rights->white_queenside = true;
                                $this->board->castling_config->white_queenside_rook_col = $rook_col;
                            }
                        } elseif ($char >= 'a' && $char <= 'h' && $black_king_col !== null) {
                            $rook_col = ord($char) - ord('a');
                            $this->board->chess960_mode = true;
                            if ($rook_col > $black_king_col) {
                                $rights->black_kingside = true;
                                $this->board->castling_config->black_kingside_rook_col = $rook_col;
                            } else {
                                $rights->black_queenside = true;
                                $this->board->castling_config->black_queenside_rook_col = $rook_col;
                            }
                        }
                        break;
                }
            }
        }
        $this->board->castling_rights = $rights;
        
        // Parse en passant target
        $this->board->en_passant_target = null;
        if ($parts[3] !== '-') {
            $col = ord(strtolower($parts[3][0])) - ord('a');
            $row = 8 - intval($parts[3][1]);
            if ($row >= 0 && $row < 8 && $col >= 0 && $col < 8) {
                $this->board->en_passant_target = [$row, $col];
            }
        }
        
        // Parse halfmove clock
        if (count($parts) > 4) {
            $this->board->halfmove_clock = intval($parts[4]);
        } else {
            $this->board->halfmove_clock = 0;
        }
        
        // Parse fullmove number
        if (count($parts) > 5) {
            $this->board->fullmove_number = intval($parts[5]);
        } else {
            $this->board->fullmove_number = 1;
        }

        require_once __DIR__ . '/Zobrist.php';
        $this->board->zobrist_hash = Zobrist::getInstance()->compute_hash($this->board);
        
        return true;
    }
    
    public function export_fen(): string {
        $fen = '';
        
        // Board position
        for ($row = 0; $row < 8; $row++) {
            $empty_count = 0;
            for ($col = 0; $col < 8; $col++) {
                [$piece, $color] = $this->board->get_piece($row, $col);
                
                if ($piece === CHESS_EMPTY) {
                    $empty_count++;
                } else {
                    if ($empty_count > 0) {
                        $fen .= $empty_count;
                        $empty_count = 0;
                    }
                    $char = $this->piece_to_char($piece);
                    $fen .= $color === CHESS_BLACK ? strtolower($char) : $char;
                }
            }
            
            if ($empty_count > 0) {
                $fen .= $empty_count;
            }
            
            if ($row < 7) {
                $fen .= '/';
            }
        }
        
        // Active color
        $fen .= ' ' . ($this->board->current_player === CHESS_WHITE ? 'w' : 'b');
        
        // Castling rights
        $fen .= ' ' . $this->board->castling_rights->to_fen(
            $this->board->castling_config,
            $this->board->chess960_mode
        );
        
        // En passant target
        if ($this->board->en_passant_target !== null) {
            [$row, $col] = $this->board->en_passant_target;
            $fen .= ' ' . chr(ord('a') + $col) . (8 - $row);
        } else {
            $fen .= ' -';
        }
        
        // Halfmove clock and fullmove number
        $fen .= ' ' . $this->board->halfmove_clock;
        $fen .= ' ' . $this->board->fullmove_number;
        
        return $fen;
    }
    
    private function char_to_piece(string $char): ?int {
        return match(strtoupper($char)) {
            'P' => CHESS_PAWN,
            'N' => CHESS_KNIGHT,
            'B' => CHESS_BISHOP,
            'R' => CHESS_ROOK,
            'Q' => CHESS_QUEEN,
            'K' => CHESS_KING,
            default => null
        };
    }
    
    private function piece_to_char(int $piece): string {
        return match($piece) {
            CHESS_PAWN => 'P',
            CHESS_KNIGHT => 'N',
            CHESS_BISHOP => 'B',
            CHESS_ROOK => 'R',
            CHESS_QUEEN => 'Q',
            CHESS_KING => 'K',
            default => ''
        };
    }
}
