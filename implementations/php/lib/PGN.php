<?php

namespace Chess;

require_once __DIR__ . '/Board.php';
require_once __DIR__ . '/FenParser.php';
require_once __DIR__ . '/MoveGenerator.php';
require_once __DIR__ . '/Types.php';

class PgnMoveNode {
    public string $san;
    public Move $move;
    public string $fen_before;
    public string $fen_after;
    /** @var string[] */
    public array $nags;
    /** @var string[] */
    public array $comments;
    /** @var array<int,array<int,PgnMoveNode>> */
    public array $variations;

    public function __construct(string $san, Move $move, string $fen_before, string $fen_after) {
        $this->san = $san;
        $this->move = $move;
        $this->fen_before = $fen_before;
        $this->fen_after = $fen_after;
        $this->nags = [];
        $this->comments = [];
        $this->variations = [];
    }
}

class PgnGame {
    /** @var array<string,string> */
    public array $tags;
    /** @var PgnMoveNode[] */
    public array $moves;
    public string $result;
    public string $source;
    public string $initial_fen;
    /** @var string[] */
    public array $initial_comments;

    /** @param PgnMoveNode[] $moves */
    public function __construct(array $tags, array $moves, string $result = '*', string $source = 'current-game', string $initial_fen = PgnSupport::START_FEN) {
        $this->tags = $tags;
        $this->moves = $moves;
        $this->result = $result;
        $this->source = $source;
        $this->initial_fen = $initial_fen;
        $this->initial_comments = [];
    }

    /** @return string[] */
    public function mainline_sans(): array {
        return array_map(static fn(PgnMoveNode $node): string => $node->san, $this->moves);
    }
}

class PgnSupport {
    public const START_FEN = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
    private const RESULT_TOKENS = ['1-0', '0-1', '1/2-1/2', '*'];

    public static function copyMove(Move $move): Move {
        $copy = new Move(
            $move->from_row,
            $move->from_col,
            $move->to_row,
            $move->to_col,
            $move->promotion,
            $move->is_castling,
            $move->is_en_passant,
        );
        $copy->captured_piece = $move->captured_piece;
        return $copy;
    }

    public static function moveToSan(Board $board, Move $move): string {
        $moveGen = new MoveGenerator($board);
        [$piece, $color] = $board->get_piece($move->from_row, $move->from_col);
        if ($piece === CHESS_EMPTY) {
            throw new \RuntimeException('missing moving piece for SAN serialization');
        }

        [$targetPiece, ] = $board->get_piece($move->to_row, $move->to_col);
        $isCapture = $targetPiece !== CHESS_EMPTY || $move->is_en_passant;

        if ($move->is_castling) {
            $san = $move->to_col === 6 ? 'O-O' : 'O-O-O';
        } else {
            $destination = self::squareName($move->to_row, $move->to_col);
            $promotion = $move->promotion !== null ? '=' . self::pieceLetter($move->promotion) : '';
            if ($piece === CHESS_PAWN) {
                $prefix = $isCapture ? chr(ord('a') + $move->from_col) . 'x' : '';
                $san = $prefix . $destination . $promotion;
            } else {
                $prefix = self::pieceLetter($piece) . self::disambiguation($board, $moveGen, $move, $piece, $color);
                if ($isCapture) {
                    $prefix .= 'x';
                }
                $san = $prefix . $destination . $promotion;
            }
        }

        $testBoard = self::cloneBoard($board);
        $testBoard->make_move(self::copyMove($move));
        $testGen = new MoveGenerator($testBoard);
        if ($testGen->is_in_check()) {
            $san .= count($testGen->generate_moves()) === 0 ? '#' : '+';
        }

        return $san;
    }

    public static function sanToMove(Board $board, string $san): Move {
        $normalized = self::normalizeSan($san);
        $moveGen = new MoveGenerator($board);
        foreach ($moveGen->generate_moves() as $move) {
            if (self::normalizeSan(self::moveToSan($board, $move)) === $normalized) {
                return $move;
            }
        }
        throw new \RuntimeException("unresolved SAN move: {$san}");
    }

    public static function parsePgn(string $content, string $source = 'current-game'): PgnGame {
        $tokens = self::tokenize($content);
        $index = 0;
        $tags = [];
        $initialComments = [];

        while ($index < count($tokens) && $tokens[$index]['kind'] === 'TAG') {
            [$name, $value] = explode("\n", $tokens[$index]['value'], 2);
            $tags[$name] = $value;
            $index++;
        }

        $initialFen = $tags['FEN'] ?? self::START_FEN;
        [$board, $fenParser] = self::stateFromFen($initialFen);
        [$moves, $result, $pending] = self::parseSequence($tokens, $index, $board, $fenParser);
        $initialComments = array_merge($initialComments, $pending);

        if ($result === '*' && isset($tags['Result'])) {
            $result = $tags['Result'];
        }
        if (!isset($tags['Result'])) {
            $tags['Result'] = $result;
        }

        $game = new PgnGame($tags, $moves, $result, $source, $initialFen);
        $game->initial_comments = $initialComments;
        return $game;
    }

    public static function serializeGame(PgnGame $game): string {
        $lines = [];
        foreach ($game->tags as $name => $value) {
            $escaped = str_replace('"', '\\"', $value);
            $lines[] = sprintf('[%s "%s"]', $name, $escaped);
        }
        if (!empty($lines)) {
            $lines[] = '';
        }

        [$moveNumber, $color] = self::startingPly($game->initial_fen);
        $moveText = self::serializeSequence($game->moves, $moveNumber, $color);
        if (!empty($game->initial_comments)) {
            $prefix = implode(' ', array_map(static fn(string $comment): string => '{' . $comment . '}', $game->initial_comments));
            $moveText = trim($prefix . ' ' . $moveText);
        }
        if ($game->result !== '') {
            $moveText = trim($moveText . ' ' . $game->result);
        }
        $lines[] = $moveText !== '' ? $moveText : $game->result;

        return trim(implode("\n", $lines)) . "\n";
    }

    /** @param Move[] $moveHistory */
    public static function buildGameFromHistory(array $moveHistory, string $startFen = self::START_FEN, string $source = 'current-game'): PgnGame {
        [$board, $fenParser] = self::stateFromFen($startFen);
        $moves = [];
        foreach ($moveHistory as $rawMove) {
            $move = self::copyMove($rawMove);
            $fenBefore = $fenParser->export_fen();
            $san = self::moveToSan($board, $move);
            $board->make_move($move);
            $fenAfter = $fenParser->export_fen();
            $moves[] = new PgnMoveNode($san, $move, $fenBefore, $fenAfter);
        }

        $tags = [
            'Event' => 'CLI Game',
            'Site' => 'Local',
            'Result' => '*',
        ];
        if ($startFen !== self::START_FEN) {
            $tags['SetUp'] = '1';
            $tags['FEN'] = $startFen;
        }

        return new PgnGame($tags, $moves, '*', $source, $startFen);
    }

    private static function squareName(int $row, int $col): string {
        return chr(ord('a') + $col) . (8 - $row);
    }

    private static function pieceLetter(int $piece): string {
        return match ($piece) {
            CHESS_PAWN => '',
            CHESS_KNIGHT => 'N',
            CHESS_BISHOP => 'B',
            CHESS_ROOK => 'R',
            CHESS_QUEEN => 'Q',
            CHESS_KING => 'K',
            default => '',
        };
    }

    private static function normalizeSan(string $token): string {
        $cleaned = trim($token);
        $cleaned = preg_replace('/^(\d+)\.(\.\.)?/', '', $cleaned) ?? $cleaned;
        $cleaned = preg_replace('/[!?]+$/', '', $cleaned) ?? $cleaned;
        $cleaned = preg_replace('/(?:\+|#)+$/', '', $cleaned) ?? $cleaned;
        $cleaned = str_replace(['0-0-0', '0-0', 'e.p.', 'ep'], ['O-O-O', 'O-O', '', ''], $cleaned);
        return trim($cleaned);
    }

    private static function disambiguation(Board $board, MoveGenerator $moveGen, Move $move, int $piece, int $color): string {
        $clashes = [];
        foreach ($moveGen->generate_moves() as $candidate) {
            if (self::movesEqual($candidate, $move)) {
                continue;
            }
            [$otherPiece, $otherColor] = $board->get_piece($candidate->from_row, $candidate->from_col);
            if ($otherPiece !== $piece || $otherColor !== $color) {
                continue;
            }
            if ($candidate->to_row === $move->to_row && $candidate->to_col === $move->to_col) {
                $clashes[] = $candidate;
            }
        }

        if (empty($clashes)) {
            return '';
        }

        $sameFile = false;
        $sameRank = false;
        foreach ($clashes as $candidate) {
            if ($candidate->from_col === $move->from_col) {
                $sameFile = true;
            }
            if ($candidate->from_row === $move->from_row) {
                $sameRank = true;
            }
        }

        if (!$sameFile) {
            return chr(ord('a') + $move->from_col);
        }
        if (!$sameRank) {
            return (string) (8 - $move->from_row);
        }
        return chr(ord('a') + $move->from_col) . (8 - $move->from_row);
    }

    private static function movesEqual(Move $a, Move $b): bool {
        return $a->from_row === $b->from_row &&
            $a->from_col === $b->from_col &&
            $a->to_row === $b->to_row &&
            $a->to_col === $b->to_col &&
            $a->promotion === $b->promotion;
    }

    /** @return array{0:Board,1:FenParser} */
    private static function stateFromFen(string $fen): array {
        $board = new Board();
        $parser = new FenParser($board);
        if (!$parser->load_fen($fen)) {
            throw new \RuntimeException('invalid FEN while preparing PGN state');
        }
        $board->game_history = [];
        $board->position_history = [];
        $board->irreversible_history = [];
        return [$board, $parser];
    }

    private static function cloneBoard(Board $board): Board {
        $parser = new FenParser($board);
        [$clone, ] = self::stateFromFen($parser->export_fen());
        return $clone;
    }

    /** @return array<int,array{kind:string,value:string}> */
    private static function tokenize(string $content): array {
        $tokens = [];
        $length = strlen($content);
        $index = 0;

        while ($index < $length) {
            $char = $content[$index];
            if (ctype_space($char)) {
                $index++;
                continue;
            }

            if ($char === '[') {
                $end = strpos($content, ']', $index);
                if ($end === false) {
                    throw new \RuntimeException('unterminated PGN tag');
                }
                $raw = trim(substr($content, $index + 1, $end - $index - 1));
                if (!preg_match('/^([A-Za-z0-9_]+)\s+"((?:\\.|[^"])*)"$/', $raw, $matches)) {
                    throw new \RuntimeException("invalid PGN tag: [{$raw}]");
                }
                $tokens[] = ['kind' => 'TAG', 'value' => $matches[1] . "\n" . str_replace('\\"', '"', $matches[2])];
                $index = $end + 1;
                continue;
            }

            if ($char === '{') {
                $end = strpos($content, '}', $index);
                if ($end === false) {
                    throw new \RuntimeException('unterminated PGN comment');
                }
                $tokens[] = ['kind' => 'COMMENT', 'value' => trim(substr($content, $index + 1, $end - $index - 1))];
                $index = $end + 1;
                continue;
            }

            if ($char === ';') {
                $end = strpos($content, "\n", $index);
                if ($end === false) {
                    $end = $length;
                }
                $tokens[] = ['kind' => 'COMMENT', 'value' => trim(substr($content, $index + 1, $end - $index - 1))];
                $index = $end;
                continue;
            }

            if ($char === '(') {
                $tokens[] = ['kind' => 'LPAREN', 'value' => '('];
                $index++;
                continue;
            }

            if ($char === ')') {
                $tokens[] = ['kind' => 'RPAREN', 'value' => ')'];
                $index++;
                continue;
            }

            if ($char === '$') {
                $start = $index;
                $index++;
                while ($index < $length && ctype_digit($content[$index])) {
                    $index++;
                }
                $tokens[] = ['kind' => 'NAG', 'value' => substr($content, $start, $index - $start)];
                continue;
            }

            $start = $index;
            while ($index < $length && !ctype_space($content[$index]) && strpos('[]{}();', $content[$index]) === false) {
                $index++;
            }
            $value = substr($content, $start, $index - $start);
            if (in_array($value, self::RESULT_TOKENS, true)) {
                $tokens[] = ['kind' => 'RESULT', 'value' => $value];
            } elseif (preg_match('/^\d+\.(\.\.)?$/', $value)) {
                $tokens[] = ['kind' => 'MOVE_NO', 'value' => $value];
            } else {
                $tokens[] = ['kind' => 'SAN', 'value' => $value];
            }
        }

        return $tokens;
    }

    /** @return array{0:array<int,PgnMoveNode>,1:string,2:array<int,string>} */
    private static function parseSequence(array $tokens, int &$index, Board $board, FenParser $fenParser): array {
        $moves = [];
        $trailingComments = [];
        $result = '*';
        $count = count($tokens);

        while ($index < $count) {
            $token = $tokens[$index];
            if ($token['kind'] === 'RPAREN') {
                break;
            }
            if ($token['kind'] === 'RESULT') {
                $result = $token['value'];
                $index++;
                break;
            }
            if ($token['kind'] === 'MOVE_NO') {
                $index++;
                continue;
            }
            if ($token['kind'] === 'COMMENT') {
                if (!empty($moves)) {
                    $moves[count($moves) - 1]->comments[] = $token['value'];
                } else {
                    $trailingComments[] = $token['value'];
                }
                $index++;
                continue;
            }
            if ($token['kind'] === 'NAG') {
                if (empty($moves)) {
                    throw new \RuntimeException('NAG without move');
                }
                $moves[count($moves) - 1]->nags[] = $token['value'];
                $index++;
                continue;
            }
            if ($token['kind'] === 'LPAREN') {
                if (empty($moves)) {
                    throw new \RuntimeException('variation without anchor move');
                }
                $index++;
                $anchor = $moves[count($moves) - 1];
                [$variationBoard, $variationParser] = self::stateFromFen($anchor->fen_before);
                [$variationMoves, $variationResult, $pending] = self::parseSequence($tokens, $index, $variationBoard, $variationParser);
                if ($index >= $count || $tokens[$index]['kind'] !== 'RPAREN') {
                    throw new \RuntimeException('unterminated PGN variation');
                }
                $index++;
                if (!empty($pending) && !empty($variationMoves)) {
                    $variationMoves[count($variationMoves) - 1]->comments = array_merge($variationMoves[count($variationMoves) - 1]->comments, $pending);
                }
                if ($variationResult !== '*' && !empty($variationMoves)) {
                    $variationMoves[count($variationMoves) - 1]->comments[] = 'result ' . $variationResult;
                }
                $anchor->variations[] = $variationMoves;
                continue;
            }
            if ($token['kind'] !== 'SAN') {
                throw new \RuntimeException('unexpected PGN token: ' . $token['kind']);
            }

            $fenBefore = $fenParser->export_fen();
            $move = self::sanToMove($board, $token['value']);
            $canonical = self::moveToSan($board, $move);
            $board->make_move($move);
            $fenAfter = $fenParser->export_fen();
            $moves[] = new PgnMoveNode($canonical, self::copyMove($move), $fenBefore, $fenAfter);
            $index++;
        }

        return [$moves, $result, $trailingComments];
    }

    /** @return array{0:int,1:int} */
    private static function startingPly(string $fen): array {
        $parts = preg_split('/\s+/', trim($fen)) ?: [];
        if (count($parts) >= 6) {
            $moveNumber = max(1, intval($parts[5]));
            $color = ($parts[1] ?? 'w') === 'b' ? CHESS_BLACK : CHESS_WHITE;
            return [$moveNumber, $color];
        }
        return [1, CHESS_WHITE];
    }

    /** @param PgnMoveNode[] $moves */
    private static function serializeSequence(array $moves, int $moveNumber, int $color): string {
        $parts = [];
        $currentNumber = $moveNumber;
        $currentColor = $color;

        foreach ($moves as $node) {
            if ($currentColor === CHESS_WHITE) {
                $parts[] = $currentNumber . '. ' . $node->san;
            } else {
                if (empty($parts) || !str_starts_with(end($parts), $currentNumber . '.')) {
                    $parts[] = $currentNumber . '... ' . $node->san;
                } else {
                    $parts[] = $node->san;
                }
            }

            foreach ($node->nags as $nag) {
                $parts[] = $nag;
            }
            foreach ($node->comments as $comment) {
                $parts[] = '{' . $comment . '}';
            }
            foreach ($node->variations as $variation) {
                $parts[] = '(' . self::serializeSequence($variation, $currentNumber, $currentColor) . ')';
            }

            if ($currentColor === CHESS_BLACK) {
                $currentNumber++;
                $currentColor = CHESS_WHITE;
            } else {
                $currentColor = CHESS_BLACK;
            }
        }

        return trim(implode(' ', array_filter($parts, static fn($part): bool => $part !== '')));
    }
}
