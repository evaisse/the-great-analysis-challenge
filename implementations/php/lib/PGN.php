<?php

namespace Chess;

require_once __DIR__ . '/Board.php';
require_once __DIR__ . '/FenParser.php';
require_once __DIR__ . '/MoveGenerator.php';
require_once __DIR__ . '/Types.php';
require_once __DIR__ . '/Zobrist.php';

class PgnMoveNode {
    public string $san;
    public string $uci;
    public int $move_number;
    public int $color;
    public string $position_before_fen;
    /** @var string[] */
    public array $nags = [];
    /** @var string[] */
    public array $comments_after = [];
    /** @var PgnVariation[] */
    public array $variations = [];

    public function __construct(
        string $san,
        string $uci,
        int $move_number,
        int $color,
        string $position_before_fen
    ) {
        $this->san = $san;
        $this->uci = $uci;
        $this->move_number = $move_number;
        $this->color = $color;
        $this->position_before_fen = $position_before_fen;
    }
}

class PgnVariation {
    public string $start_fen;
    /** @var string[] */
    public array $leading_comments = [];
    /** @var PgnMoveNode[] */
    public array $moves = [];
    public ?string $result = null;

    public function __construct(string $start_fen) {
        $this->start_fen = $start_fen;
    }
}

class PgnGame {
    public string $source;
    /** @var array<string,string> */
    public array $tags;
    public PgnVariation $mainline;
    public string $result;
    /** @var array<int,array{variation:PgnVariation,cursor_index:int}> */
    private array $cursor_stack = [];

    /**
     * @param array<string,string> $tags
     */
    public function __construct(string $source, array $tags, PgnVariation $mainline, string $result = '*') {
        $this->source = $source;
        $this->tags = $tags;
        $this->mainline = $mainline;
        $this->result = $result;
        $this->sync_result_tag();
        $this->reset_cursor();
    }

    public static function create_live_game(string $source = 'current-game', ?string $initial_fen = null): self {
        $start_fen = $initial_fen ?? PgnSanCodec::start_fen();
        $tags = [
            'Event' => 'CLI Game',
            'Site' => 'Local',
            'Date' => gmdate('Y.m.d'),
            'Round' => '-',
            'White' => 'White',
            'Black' => 'Black',
            'Result' => '*',
        ];

        if ($start_fen !== PgnSanCodec::start_fen()) {
            $tags['SetUp'] = '1';
            $tags['FEN'] = $start_fen;
        }

        return new self($source, $tags, new PgnVariation($start_fen), '*');
    }

    public function reset_cursor(): void {
        $this->cursor_stack = [
            ['variation' => $this->mainline, 'cursor_index' => count($this->mainline->moves) - 1],
        ];
    }

    public function set_source(string $source): void {
        $this->source = $source;
    }

    public function set_result(string $result): void {
        $this->result = $result;
        $this->sync_result_tag();
    }

    /** @return string[] */
    public function mainline_moves(): array {
        $moves = [];
        foreach ($this->mainline->moves as $move) {
            $moves[] = $move->san;
        }
        return $moves;
    }

    public function append_move(PgnMoveNode $move): void {
        $context_index = count($this->cursor_stack) - 1;
        $variation = $this->cursor_stack[$context_index]['variation'];
        $variation->moves[] = $move;
        $this->cursor_stack[$context_index]['cursor_index'] = count($variation->moves) - 1;
    }

    public function rewind_last_move(): bool {
        $context_index = count($this->cursor_stack) - 1;
        $variation = $this->cursor_stack[$context_index]['variation'];
        $cursor_index = $this->cursor_stack[$context_index]['cursor_index'];

        if ($cursor_index !== count($variation->moves) - 1 || $cursor_index < 0) {
            return false;
        }

        array_pop($variation->moves);
        $this->cursor_stack[$context_index]['cursor_index'] = count($variation->moves) - 1;
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
            $move->comments_after[] = $text;
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

        if (count($move->variations) === 0) {
            $move->variations[] = new PgnVariation($move->position_before_fen);
        }

        $variation = $move->variations[0];
        $this->cursor_stack[] = [
            'variation' => $variation,
            'cursor_index' => count($variation->moves) - 1,
        ];

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

    public function current_variation(): PgnVariation {
        return $this->cursor_stack[count($this->cursor_stack) - 1]['variation'];
    }

    public function current_move(): ?PgnMoveNode {
        $context = $this->cursor_stack[count($this->cursor_stack) - 1];
        if ($context['cursor_index'] < 0) {
            return null;
        }
        return $context['variation']->moves[$context['cursor_index']] ?? null;
    }

    public function serialize(): string {
        return PgnSerializer::serialize($this);
    }

    private function sync_result_tag(): void {
        $this->tags['Result'] = $this->result;
    }
}

class PgnParser {
    /** @var array<int,array{type:string,value:string,name?:string}> */
    private array $tokens = [];
    private int $index = 0;

    public function parse(string $content, string $source = 'current-game'): PgnGame {
        $this->tokens = $this->tokenize($content);
        $this->index = 0;

        $tags = [];
        while (($token = $this->peek()) !== null && $token['type'] === 'TAG') {
            $this->index++;
            /** @var string $name */
            $name = $token['name'];
            $tags[$name] = $token['value'];
        }

        if (count($tags) === 0) {
            $tags = PgnGame::create_live_game($source)->tags;
        }

        $start_fen = PgnSanCodec::start_fen();
        if (($tags['SetUp'] ?? '') === '1' && isset($tags['FEN']) && trim($tags['FEN']) !== '') {
            $start_fen = $tags['FEN'];
        }

        [$mainline, $result] = $this->parse_variation($start_fen, true);
        $game_result = $result ?? ($tags['Result'] ?? '*');
        $game = new PgnGame($source, $tags, $mainline, $game_result);
        $game->reset_cursor();
        return $game;
    }

    /**
     * @return array{0:PgnVariation,1:?string}
     */
    private function parse_variation(string $start_fen, bool $is_root): array {
        $variation = new PgnVariation($start_fen);
        [$board, $move_gen, $fen_parser] = PgnSanCodec::create_state($start_fen);
        $result = null;
        $last_move = null;

        while (($token = $this->peek()) !== null) {
            if ($token['type'] === 'VARIATION_END') {
                if (!$is_root) {
                    $this->index++;
                }
                break;
            }

            if ($token['type'] === 'RESULT') {
                $this->index++;
                if ($is_root) {
                    $result = $token['value'];
                } else {
                    $variation->result = $token['value'];
                }
                continue;
            }

            if ($token['type'] === 'COMMENT') {
                $this->index++;
                if ($last_move instanceof PgnMoveNode) {
                    $last_move->comments_after[] = $token['value'];
                } else {
                    $variation->leading_comments[] = $token['value'];
                }
                continue;
            }

            if ($token['type'] === 'MOVE_NUMBER') {
                $this->index++;
                continue;
            }

            if ($token['type'] === 'NAG') {
                $this->index++;
                if ($last_move instanceof PgnMoveNode) {
                    $last_move->nags[] = $token['value'];
                }
                continue;
            }

            if ($token['type'] === 'VARIATION_START') {
                $this->index++;
                $anchor_fen = $last_move instanceof PgnMoveNode ? $last_move->position_before_fen : $start_fen;
                [$child_variation, $_] = $this->parse_variation($anchor_fen, false);
                if ($last_move instanceof PgnMoveNode) {
                    $last_move->variations[] = $child_variation;
                }
                continue;
            }

            if ($token['type'] !== 'SAN') {
                throw new \RuntimeException('Unsupported PGN token: ' . $token['type']);
            }

            $this->index++;
            [$raw_san, $inline_nags] = PgnSanCodec::split_annotated_san($token['value']);
            $before_fen = $fen_parser->export_fen();
            $move = PgnSanCodec::resolve_san($board, $move_gen, $fen_parser, $raw_san);
            $canonical_san = PgnSanCodec::move_to_san($board, $move_gen, $fen_parser, $move);
            $node = new PgnMoveNode(
                $canonical_san,
                strtolower($move->to_string()),
                $board->fullmove_number,
                $board->current_player,
                $before_fen
            );
            $node->nags = array_merge($node->nags, $inline_nags);
            $variation->moves[] = $node;
            $last_move = $node;
            $board->make_move($move);
        }

        return [$variation, $result];
    }

    /**
     * @return array<int,array{type:string,value:string,name?:string}>
     */
    private function tokenize(string $content): array {
        $content = preg_replace('/^\xEF\xBB\xBF/', '', $content) ?? $content;
        $tokens = [];
        $length = strlen($content);
        $i = 0;

        while ($i < $length) {
            $char = $content[$i];

            if (ctype_space($char)) {
                $i++;
                continue;
            }

            if ($char === '[') {
                $tokens[] = $this->read_tag_token($content, $i, $length);
                continue;
            }

            if ($char === '{') {
                $end = strpos($content, '}', $i + 1);
                if ($end === false) {
                    $end = $length - 1;
                }
                $value = trim(substr($content, $i + 1, max(0, $end - $i - 1)));
                $tokens[] = ['type' => 'COMMENT', 'value' => $value];
                $i = $end + 1;
                continue;
            }

            if ($char === ';') {
                $end = strpos($content, "\n", $i + 1);
                if ($end === false) {
                    $end = $length;
                }
                $value = trim(substr($content, $i + 1, max(0, $end - $i - 1)));
                $tokens[] = ['type' => 'COMMENT', 'value' => $value];
                $i = $end;
                continue;
            }

            if ($char === '(') {
                $tokens[] = ['type' => 'VARIATION_START', 'value' => '('];
                $i++;
                continue;
            }

            if ($char === ')') {
                $tokens[] = ['type' => 'VARIATION_END', 'value' => ')'];
                $i++;
                continue;
            }

            if ($char === '$') {
                $j = $i + 1;
                while ($j < $length && ctype_digit($content[$j])) {
                    $j++;
                }
                $tokens[] = ['type' => 'NAG', 'value' => substr($content, $i, $j - $i)];
                $i = $j;
                continue;
            }

            $j = $i;
            while ($j < $length && !ctype_space($content[$j]) && strpos('[]{}();', $content[$j]) === false) {
                $j++;
            }

            $value = trim(substr($content, $i, $j - $i));
            $i = $j;
            if ($value === '') {
                continue;
            }

            if (preg_match('/^(1-0|0-1|1\/2-1\/2|\*)$/', $value) === 1) {
                $tokens[] = ['type' => 'RESULT', 'value' => $value];
                continue;
            }

            if (preg_match('/^\d+\.(?:\.\.)?$/', $value) === 1 || preg_match('/^\d+\.\.\.$/', $value) === 1) {
                $tokens[] = ['type' => 'MOVE_NUMBER', 'value' => $value];
                continue;
            }

            $tokens[] = ['type' => 'SAN', 'value' => $value];
        }

        return $tokens;
    }

    /**
     * @return array{type:string,value:string,name:string}
     */
    private function read_tag_token(string $content, int &$i, int $length): array {
        $i++;
        while ($i < $length && ctype_space($content[$i])) {
            $i++;
        }

        $name_start = $i;
        while ($i < $length && preg_match('/[A-Za-z0-9_]/', $content[$i]) === 1) {
            $i++;
        }
        $name = substr($content, $name_start, $i - $name_start);

        while ($i < $length && ctype_space($content[$i])) {
            $i++;
        }

        $value = '';
        if ($i < $length && $content[$i] === '"') {
            $i++;
            while ($i < $length) {
                if ($content[$i] === '\\' && ($i + 1) < $length) {
                    $value .= $content[$i + 1];
                    $i += 2;
                    continue;
                }
                if ($content[$i] === '"') {
                    $i++;
                    break;
                }
                $value .= $content[$i];
                $i++;
            }
        }

        while ($i < $length && $content[$i] !== ']') {
            $i++;
        }
        if ($i < $length && $content[$i] === ']') {
            $i++;
        }

        return ['type' => 'TAG', 'name' => $name, 'value' => $value];
    }

    /** @return array{type:string,value:string,name?:string}|null */
    private function peek(): ?array {
        return $this->tokens[$this->index] ?? null;
    }
}

class PgnSerializer {
    public static function serialize(PgnGame $game): string {
        $lines = [];
        foreach (self::ordered_tags($game->tags) as [$name, $value]) {
            $escaped = str_replace(['\\', '"'], ['\\\\', '\\"'], $value);
            $lines[] = '[' . $name . ' "' . $escaped . '"]';
        }

        $lines[] = '';
        $move_text = trim(self::serialize_variation($game->mainline, true));
        if ($move_text !== '') {
            $lines[] = $move_text . ' ' . $game->result;
        } else {
            $lines[] = $game->result;
        }

        return implode("\n", $lines);
    }

    /**
     * @param array<string,string> $tags
     * @return array<int,array{0:string,1:string}>
     */
    private static function ordered_tags(array $tags): array {
        $ordered_names = ['Event', 'Site', 'Date', 'Round', 'White', 'Black', 'Result', 'SetUp', 'FEN'];
        $ordered = [];
        foreach ($ordered_names as $name) {
            if (isset($tags[$name])) {
                $ordered[] = [$name, $tags[$name]];
                unset($tags[$name]);
            }
        }

        ksort($tags);
        foreach ($tags as $name => $value) {
            $ordered[] = [$name, $value];
        }

        return $ordered;
    }

    private static function serialize_variation(PgnVariation $variation, bool $is_root): string {
        $parts = [];
        foreach ($variation->leading_comments as $comment) {
            $parts[] = self::comment_text($comment);
        }

        $previous_color = null;
        foreach ($variation->moves as $move) {
            if ($move->color === CHESS_WHITE) {
                $parts[] = $move->move_number . '.';
            } elseif ($previous_color !== CHESS_WHITE) {
                $parts[] = $move->move_number . '...';
            }

            $parts[] = $move->san;

            foreach ($move->nags as $nag) {
                $parts[] = $nag;
            }
            foreach ($move->comments_after as $comment) {
                $parts[] = self::comment_text($comment);
            }
            foreach ($move->variations as $child) {
                $parts[] = '(' . self::serialize_variation($child, false) . ')';
            }

            $previous_color = $move->color;
        }

        if (!$is_root && $variation->result !== null && $variation->result !== '') {
            $parts[] = $variation->result;
        }

        return trim(implode(' ', array_values(array_filter($parts, fn($part) => $part !== ''))));
    }

    private static function comment_text(string $comment): string {
        return '{' . trim($comment) . '}';
    }
}

class PgnSanCodec {
    public static function start_fen(): string {
        return 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
    }

    /**
     * @return array{0:Board,1:MoveGenerator,2:FenParser}
     */
    public static function create_state(string $fen): array {
        $board = new Board();
        $fen_parser = new FenParser($board);
        if (!$fen_parser->load_fen($fen)) {
            throw new \RuntimeException('Invalid PGN position state');
        }
        return [$board, new MoveGenerator($board), $fen_parser];
    }

    /**
     * @return array{0:string,1:array<int,string>}
     */
    public static function split_annotated_san(string $token): array {
        $san = trim($token);
        $nags = [];
        $map = [
            '!!' => '$3',
            '??' => '$4',
            '!?' => '$5',
            '?!' => '$6',
            '!' => '$1',
            '?' => '$2',
        ];

        while (preg_match('/(\!\!|\?\?|\!\?|\?\!|\!|\?)$/', $san, $matches) === 1) {
            $annotation = $matches[1];
            array_unshift($nags, $map[$annotation]);
            $san = substr($san, 0, -strlen($annotation));
        }

        return [trim($san), $nags];
    }

    public static function resolve_san(Board $board, MoveGenerator $move_gen, FenParser $fen_parser, string $san): Move {
        $legal_moves = $move_gen->generate_moves();
        $target = self::normalize_san($san);
        $matches = [];

        foreach ($legal_moves as $move) {
            $candidate = self::move_to_san($board, $move_gen, $fen_parser, $move, $legal_moves);
            if (self::normalize_san($candidate) === $target) {
                $matches[] = $move;
            }
        }

        if (count($matches) === 1) {
            return $matches[0];
        }
        if (count($matches) > 1) {
            throw new \RuntimeException('Ambiguous SAN move: ' . $san);
        }

        throw new \RuntimeException('Illegal SAN move: ' . $san);
    }

    public static function move_to_san(
        Board $board,
        MoveGenerator $move_gen,
        FenParser $fen_parser,
        Move $move,
        ?array $legal_moves = null
    ): string {
        $legal_moves = $legal_moves ?? $move_gen->generate_moves();
        [$piece, $color] = $board->get_piece($move->from_row, $move->from_col);

        if ($move->is_castling) {
            $san = $move->to_col > $move->from_col ? 'O-O' : 'O-O-O';
        } else {
            $destination = self::square_name($move->to_row, $move->to_col);
            $is_capture = $move->is_en_passant || $board->get_piece($move->to_row, $move->to_col)[0] !== CHESS_EMPTY;
            $san = '';

            if ($piece === CHESS_PAWN) {
                if ($is_capture) {
                    $san .= chr(ord('a') + $move->from_col);
                }
            } else {
                $san .= self::piece_letter($piece);
                $san .= self::disambiguation($board, $move, $piece, $legal_moves);
            }

            if ($is_capture) {
                $san .= 'x';
            }
            $san .= $destination;

            if ($move->promotion !== null) {
                $san .= '=' . self::piece_letter($move->promotion);
            }
        }

        $board->make_move($move);
        $next_gen = new MoveGenerator($board);
        if ($next_gen->is_checkmate()) {
            $san .= '#';
        } elseif ($next_gen->is_in_check()) {
            $san .= '+';
        }
        $board->undo_move();

        return $san;
    }

    private static function normalize_san(string $san): string {
        $san = trim($san);
        $san = str_replace('0', 'O', $san);
        $san = preg_replace('/(?:\s+|\{.*)$/', '', $san) ?? $san;
        $san = preg_replace('/[+#]+$/', '', $san) ?? $san;
        [$san, $_] = self::split_annotated_san($san);
        return $san;
    }

    private static function piece_letter(int $piece): string {
        return match($piece) {
            CHESS_KNIGHT => 'N',
            CHESS_BISHOP => 'B',
            CHESS_ROOK => 'R',
            CHESS_QUEEN => 'Q',
            CHESS_KING => 'K',
            default => '',
        };
    }

    private static function square_name(int $row, int $col): string {
        return chr(ord('a') + $col) . (8 - $row);
    }

    private static function disambiguation(Board $board, Move $move, int $piece, array $legal_moves): string {
        $candidates = [];
        foreach ($legal_moves as $candidate) {
            if ($candidate->from_row === $move->from_row &&
                $candidate->from_col === $move->from_col &&
                $candidate->to_row === $move->to_row &&
                $candidate->to_col === $move->to_col &&
                $candidate->promotion === $move->promotion) {
                continue;
            }
            if ($candidate->to_row !== $move->to_row || $candidate->to_col !== $move->to_col) {
                continue;
            }
            if ($candidate->promotion !== $move->promotion) {
                continue;
            }
            [$candidate_piece, $candidate_color] = $board->get_piece($candidate->from_row, $candidate->from_col);
            if ($candidate_piece === $piece && $candidate_color === $board->current_player) {
                $candidates[] = $candidate;
            }
        }

        if (count($candidates) === 0) {
            return '';
        }

        $share_file = false;
        $share_rank = false;
        foreach ($candidates as $candidate) {
            if ($candidate->from_col === $move->from_col) {
                $share_file = true;
            }
            if ($candidate->from_row === $move->from_row) {
                $share_rank = true;
            }
        }

        $file = chr(ord('a') + $move->from_col);
        $rank = (string) (8 - $move->from_row);

        if (!$share_file) {
            return $file;
        }
        if (!$share_rank) {
            return $rank;
        }

        return $file . $rank;
    }
}
