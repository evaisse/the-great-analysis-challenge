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
    /** @var PgnVariation[] */
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

class PgnVariation {
    public string $start_fen;
    /** @var string[] */
    public array $leading_comments;
    /** @var PgnMoveNode[] */
    public array $moves;
    public string $result;

    public function __construct(string $start_fen) {
        $this->start_fen = $start_fen;
        $this->leading_comments = [];
        $this->moves = [];
        $this->result = '';
    }
}

class PgnGame {
    /** @var array<string,string> */
    public array $tags;
    public PgnVariation $mainline;
    public string $result;
    public string $source;
    /** @var array<int,array{variation:PgnVariation}> */
    private array $cursor_stack;

    /** @param array<string,string> $tags */
    public function __construct(array $tags, PgnVariation $mainline, string $result = '*', string $source = 'current-game') {
        $this->tags = $tags;
        $this->mainline = $mainline;
        $this->result = $result;
        $this->source = $source;
        $this->cursor_stack = [];
        $this->sync_result_tag();
        $this->reset_cursor();
    }

    /** @return string[] */
    public function mainline_sans(): array {
        return array_map(static fn(PgnMoveNode $node): string => $node->san, $this->mainline->moves);
    }

    public function set_source(string $source): void {
        $this->source = $source;
    }

    public function set_result(string $result): void {
        $this->result = $result;
        $this->mainline->result = $result;
        $this->sync_result_tag();
    }

    public function reset_cursor(): void {
        $this->cursor_stack = [
            ['variation' => $this->mainline],
        ];
    }

    public function current_variation(): PgnVariation {
        if (empty($this->cursor_stack)) {
            $this->reset_cursor();
        }
        return $this->cursor_stack[count($this->cursor_stack) - 1]['variation'];
    }

    public function current_move(): ?PgnMoveNode {
        $variation = $this->current_variation();
        if (empty($variation->moves)) {
            return null;
        }
        return $variation->moves[count($variation->moves) - 1];
    }

    /** @return string[] */
    public function current_sans(): array {
        return array_map(static fn(PgnMoveNode $node): string => $node->san, $this->current_variation()->moves);
    }

    public function append_move(PgnMoveNode $node): void {
        $variation = $this->current_variation();
        $variation->moves[] = $node;
    }

    public function rewind_last_move(): bool {
        $variation = $this->current_variation();
        if (empty($variation->moves)) {
            return false;
        }
        array_pop($variation->moves);
        $this->set_result('*');
        return true;
    }

    public function add_comment(string $text): void {
        $text = trim($text);
        if ($text === '') {
            return;
        }
        $move = $this->current_move();
        if ($move !== null) {
            $move->comments[] = $text;
            return;
        }
        $this->current_variation()->leading_comments[] = $text;
    }

    /** @return array{ok:bool,message:string} */
    public function enter_variation(): array {
        $move = $this->current_move();
        if ($move === null) {
            return ['ok' => false, 'message' => 'ERROR: pgn variation enter requires a current move'];
        }
        if (empty($move->variations)) {
            $move->variations[] = new PgnVariation($move->fen_before);
        }
        $variation = $move->variations[0];
        if ($variation->start_fen === '') {
            $variation->start_fen = $move->fen_before;
        }
        $this->cursor_stack[] = ['variation' => $variation];
        return [
            'ok' => true,
            'message' => 'PGN: variation depth=' . (count($this->cursor_stack) - 1) . '; moves=' . count($variation->moves),
        ];
    }

    /** @return array{ok:bool,message:string} */
    public function exit_variation(): array {
        if (count($this->cursor_stack) <= 1) {
            return ['ok' => false, 'message' => 'ERROR: already at mainline'];
        }
        array_pop($this->cursor_stack);
        return [
            'ok' => true,
            'message' => 'PGN: variation depth=' . (count($this->cursor_stack) - 1) . '; moves=' . count($this->current_variation()->moves),
        ];
    }

    private function sync_result_tag(): void {
        $this->tags['Result'] = $this->result;
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

        while ($index < count($tokens) && $tokens[$index]['kind'] === 'TAG') {
            [$name, $value] = explode("\n", $tokens[$index]['value'], 2);
            $tags[$name] = $value;
            $index++;
        }

        $initialFen = $tags['FEN'] ?? self::START_FEN;
        [$board, $fenParser] = self::stateFromFen($initialFen);
        [$mainline, $result] = self::parseSequence($tokens, $index, $board, $fenParser, $initialFen);

        if ($result === '*' && isset($tags['Result'])) {
            $result = $tags['Result'];
        }
        if (!isset($tags['Result'])) {
            $tags['Result'] = $result;
        }

        $mainline->result = $result;
        return new PgnGame($tags, $mainline, $result, $source);
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

        [$moveNumber, $color] = self::startingPly($game->mainline->start_fen);
        $moveText = self::serializeVariation($game->mainline, $moveNumber, $color, true);
        if ($game->result !== '') {
            $moveText = trim($moveText . ' ' . $game->result);
        }
        $lines[] = $moveText !== '' ? $moveText : $game->result;

        return trim(implode("\n", $lines)) . "\n";
    }

    /** @param Move[] $moveHistory */
    public static function buildGameFromHistory(array $moveHistory, string $startFen = self::START_FEN, string $source = 'current-game'): PgnGame {
        [$board, $fenParser] = self::stateFromFen($startFen);
        $mainline = new PgnVariation($startFen);
        foreach ($moveHistory as $rawMove) {
            $move = self::copyMove($rawMove);
            $fenBefore = $fenParser->export_fen();
            $san = self::moveToSan($board, $move);
            $board->make_move($move);
            $fenAfter = $fenParser->export_fen();
            $mainline->moves[] = new PgnMoveNode($san, $move, $fenBefore, $fenAfter);
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

        return new PgnGame($tags, $mainline, '*', $source);
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

    /** @return array{0:PgnVariation,1:string} */
    private static function parseSequence(array $tokens, int &$index, Board $board, FenParser $fenParser, string $startFen): array {
        $variation = new PgnVariation($startFen);
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
                if (!empty($variation->moves)) {
                    $variation->moves[count($variation->moves) - 1]->comments[] = $token['value'];
                } else {
                    $variation->leading_comments[] = $token['value'];
                }
                $index++;
                continue;
            }
            if ($token['kind'] === 'NAG') {
                if (empty($variation->moves)) {
                    throw new \RuntimeException('NAG without move');
                }
                $variation->moves[count($variation->moves) - 1]->nags[] = $token['value'];
                $index++;
                continue;
            }
            if ($token['kind'] === 'LPAREN') {
                if (empty($variation->moves)) {
                    throw new \RuntimeException('variation without anchor move');
                }
                $index++;
                $anchor = $variation->moves[count($variation->moves) - 1];
                [$variationBoard, $variationParser] = self::stateFromFen($anchor->fen_before);
                [$child, $variationResult] = self::parseSequence($tokens, $index, $variationBoard, $variationParser, $anchor->fen_before);
                if ($index >= $count || $tokens[$index]['kind'] !== 'RPAREN') {
                    throw new \RuntimeException('unterminated PGN variation');
                }
                $index++;
                if ($variationResult !== '' && $variationResult !== '*') {
                    $child->result = $variationResult;
                }
                $anchor->variations[] = $child;
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
            $variation->moves[] = new PgnMoveNode($canonical, self::copyMove($move), $fenBefore, $fenAfter);
            $index++;
        }

        return [$variation, $result];
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

    private static function serializeVariation(PgnVariation $variation, int $moveNumber, int $color, bool $isRoot): string {
        $parts = [];
        foreach ($variation->leading_comments as $comment) {
            $parts[] = '{' . $comment . '}';
        }
        $currentNumber = $moveNumber;
        $currentColor = $color;

        foreach ($variation->moves as $node) {
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
                $parts[] = '(' . self::serializeVariation($variation, $currentNumber, $currentColor, false) . ')';
            }

            if ($currentColor === CHESS_BLACK) {
                $currentNumber++;
                $currentColor = CHESS_WHITE;
            } else {
                $currentColor = CHESS_BLACK;
            }
        }

        if (!$isRoot && $variation->result !== '' && $variation->result !== '*') {
            $parts[] = $variation->result;
        }

        return trim(implode(' ', array_filter($parts, static fn($part): bool => $part !== '')));
    }
}
