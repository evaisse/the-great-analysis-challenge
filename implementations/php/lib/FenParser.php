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
        
        // Parse active color
        $this->board->current_player = $parts[1] === 'w' ? CHESS_WHITE : CHESS_BLACK;
        
        // Parse castling rights
        $this->board->castling_rights = [false, false, false, false];
        if ($parts[2] !== '-') {
            for ($i = 0; $i < strlen($parts[2]); $i++) {
                $char = $parts[2][$i];
                switch ($char) {
                    case 'K':
                        $this->board->castling_rights[0] = true;
                        break;
                    case 'Q':
                        $this->board->castling_rights[1] = true;
                        break;
                    case 'k':
                        $this->board->castling_rights[2] = true;
                        break;
                    case 'q':
                        $this->board->castling_rights[3] = true;
                        break;
                }
            }
        }
        
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
        $castling = '';
        if ($this->board->castling_rights[0]) $castling .= 'K';
        if ($this->board->castling_rights[1]) $castling .= 'Q';
        if ($this->board->castling_rights[2]) $castling .= 'k';
        if ($this->board->castling_rights[3]) $castling .= 'q';
        $fen .= ' ' . ($castling === '' ? '-' : $castling);
        
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
