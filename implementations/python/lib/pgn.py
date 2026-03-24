"""PGN parsing, validation, and serialization helpers."""

from __future__ import annotations

from dataclasses import dataclass, field
import re
from typing import Dict, List, Optional, Tuple

from lib.board import Board
from lib.fen_parser import FenParser
from lib.move_generator import MoveGenerator
from lib.types import Color, Move, PieceType


START_FEN = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'
RESULT_TOKENS = ('1-0', '0-1', '1/2-1/2', '*')
PIECE_LETTERS = {
    PieceType.PAWN: '',
    PieceType.KNIGHT: 'N',
    PieceType.BISHOP: 'B',
    PieceType.ROOK: 'R',
    PieceType.QUEEN: 'Q',
    PieceType.KING: 'K',
}
PROMOTION_MAP = {
    'Q': PieceType.QUEEN,
    'R': PieceType.ROOK,
    'B': PieceType.BISHOP,
    'N': PieceType.KNIGHT,
}


@dataclass
class PgnMoveNode:
    san: str
    move: Move
    fen_before: str
    fen_after: str
    nags: List[str] = field(default_factory=list)
    comments: List[str] = field(default_factory=list)
    variations: List[List['PgnMoveNode']] = field(default_factory=list)


@dataclass
class PgnGame:
    tags: Dict[str, str]
    moves: List[PgnMoveNode]
    result: str = '*'
    source: str = 'current-game'
    initial_fen: str = START_FEN
    initial_comments: List[str] = field(default_factory=list)

    def mainline_sans(self) -> List[str]:
        return [node.san for node in self.moves]


def copy_move(move: Move) -> Move:
    return Move(
        move.from_row,
        move.from_col,
        move.to_row,
        move.to_col,
        move.promotion,
        is_castling=move.is_castling,
        is_en_passant=move.is_en_passant,
        en_passant_target=move.en_passant_target,
    )


@dataclass
class Token:
    kind: str
    value: str


def _state_from_fen(fen: str) -> Tuple[Board, MoveGenerator, FenParser]:
    board = Board()
    parser = FenParser(board)
    parser.parse(fen)
    board.game_history = []
    board.position_history = []
    board.irreversible_history = []
    return board, MoveGenerator(board), parser


def _clone_board(board: Board) -> Board:
    parser = FenParser(board)
    fen = parser.export()
    cloned, _, _ = _state_from_fen(fen)
    return cloned


def _copy_node(node: PgnMoveNode) -> PgnMoveNode:
    return PgnMoveNode(
        san=node.san,
        move=copy_move(node.move),
        fen_before=node.fen_before,
        fen_after=node.fen_after,
        nags=list(node.nags),
        comments=list(node.comments),
        variations=[[_copy_node(child) for child in variation] for variation in node.variations],
    )


def _square_name(row: int, col: int) -> str:
    return chr(ord('a') + col) + str(row + 1)


def _normalize_san(token: str) -> str:
    cleaned = token.strip()
    cleaned = re.sub(r'^(\d+)\.(\.\.)?', '', cleaned)
    cleaned = re.sub(r'[!?]+$', '', cleaned)
    cleaned = re.sub(r'(?:\+|#)+$', '', cleaned)
    cleaned = cleaned.replace('0-0-0', 'O-O-O').replace('0-0', 'O-O')
    cleaned = cleaned.replace('ep', '').replace('e.p.', '')
    return cleaned.strip()


def _disambiguation(board: Board, move_generator: MoveGenerator, move: Move) -> str:
    piece = board.get_piece(move.from_row, move.from_col)
    if piece is None or piece.type == PieceType.PAWN:
        return ''

    clashes = []
    for candidate in move_generator.generate_legal_moves():
        if candidate == move:
            continue
        other_piece = board.get_piece(candidate.from_row, candidate.from_col)
        if other_piece is None:
            continue
        if other_piece.color != piece.color or other_piece.type != piece.type:
            continue
        if candidate.to_row == move.to_row and candidate.to_col == move.to_col:
            clashes.append(candidate)

    if not clashes:
        return ''

    same_file = any(candidate.from_col == move.from_col for candidate in clashes)
    same_rank = any(candidate.from_row == move.from_row for candidate in clashes)

    if not same_file:
        return chr(ord('a') + move.from_col)
    if not same_rank:
        return str(move.from_row + 1)
    return chr(ord('a') + move.from_col) + str(move.from_row + 1)


def move_to_san(board: Board, move: Move) -> str:
    move_generator = MoveGenerator(board)
    piece = board.get_piece(move.from_row, move.from_col)
    if piece is None:
        raise ValueError('missing moving piece for SAN serialization')

    target_piece = board.get_piece(move.to_row, move.to_col)
    is_capture = target_piece is not None or move.is_en_passant

    if move.is_castling:
        san = 'O-O' if move.to_col == 6 else 'O-O-O'
    else:
        destination = _square_name(move.to_row, move.to_col)
        promotion = ''
        if move.promotion is not None:
            promotion = '=' + PIECE_LETTERS[move.promotion]

        if piece.type == PieceType.PAWN:
            prefix = ''
            if is_capture:
                prefix = chr(ord('a') + move.from_col) + 'x'
            san = prefix + destination + promotion
        else:
            prefix = PIECE_LETTERS[piece.type] + _disambiguation(board, move_generator, move)
            if is_capture:
                prefix += 'x'
            san = prefix + destination + promotion

    test_board = _clone_board(board)
    test_move = Move(
        move.from_row,
        move.from_col,
        move.to_row,
        move.to_col,
        move.promotion,
        is_castling=move.is_castling,
        is_en_passant=move.is_en_passant,
    )
    test_board.make_move(test_move)

    opponent = test_board.to_move
    if test_board.is_in_check(opponent):
        if len(MoveGenerator(test_board).generate_legal_moves()) == 0:
            san += '#'
        else:
            san += '+'

    return san


def san_to_move(board: Board, san: str) -> Move:
    normalized = _normalize_san(san)
    legal_moves = MoveGenerator(board).generate_legal_moves()
    for move in legal_moves:
        generated = _normalize_san(move_to_san(board, move))
        if generated == normalized:
            return move
    raise ValueError(f'unresolved SAN move: {san}')


def tokenize_pgn(content: str) -> List[Token]:
    tokens: List[Token] = []
    idx = 0
    length = len(content)

    while idx < length:
        char = content[idx]
        if char.isspace():
            idx += 1
            continue

        if char == '[':
            end = content.find(']', idx)
            if end < 0:
                raise ValueError('unterminated PGN tag')
            raw = content[idx + 1:end].strip()
            match = re.match(r'([A-Za-z0-9_]+)\s+"((?:\\.|[^"])*)"$', raw)
            if not match:
                raise ValueError(f'invalid PGN tag: [{raw}]')
            name = match.group(1)
            value = match.group(2).replace('\\"', '"')
            tokens.append(Token('TAG', name + '\n' + value))
            idx = end + 1
            continue

        if char == '{':
            end = content.find('}', idx)
            if end < 0:
                raise ValueError('unterminated PGN comment')
            tokens.append(Token('COMMENT', content[idx + 1:end].strip()))
            idx = end + 1
            continue

        if char == ';':
            end = content.find('\n', idx)
            if end < 0:
                end = length
            tokens.append(Token('COMMENT', content[idx + 1:end].strip()))
            idx = end
            continue

        if char == '(':
            tokens.append(Token('LPAREN', char))
            idx += 1
            continue

        if char == ')':
            tokens.append(Token('RPAREN', char))
            idx += 1
            continue

        if char == '$':
            start = idx
            idx += 1
            while idx < length and content[idx].isdigit():
                idx += 1
            tokens.append(Token('NAG', content[start:idx]))
            continue

        start = idx
        while idx < length and not content[idx].isspace() and content[idx] not in '[]{}();':
            idx += 1
        value = content[start:idx]
        if value in RESULT_TOKENS:
            tokens.append(Token('RESULT', value))
        elif re.match(r'^\d+\.(\.\.)?$', value):
            tokens.append(Token('MOVE_NO', value))
        else:
            tokens.append(Token('SAN', value))

    return tokens


class Parser:
    def __init__(self, tokens: List[Token]):
        self.tokens = tokens
        self.index = 0

    def at_end(self) -> bool:
        return self.index >= len(self.tokens)

    def peek(self) -> Optional[Token]:
        if self.at_end():
            return None
        return self.tokens[self.index]

    def pop(self) -> Token:
        token = self.peek()
        if token is None:
            raise ValueError('unexpected end of PGN')
        self.index += 1
        return token


def parse_pgn(content: str, source: str = 'current-game') -> PgnGame:
    parser = Parser(tokenize_pgn(content))
    tags: Dict[str, str] = {}
    initial_comments: List[str] = []

    while not parser.at_end():
        token = parser.peek()
        if token is None or token.kind != 'TAG':
            break
        token = parser.pop()
        name, value = token.value.split('\n', 1)
        tags[name] = value

    initial_fen = tags.get('FEN', START_FEN)
    board, _, fen_parser = _state_from_fen(initial_fen)
    moves, result, pending = _parse_sequence(parser, board, fen_parser)
    initial_comments.extend(pending)

    if result == '*' and 'Result' in tags:
        result = tags['Result']
    if 'Result' not in tags:
        tags['Result'] = result

    return PgnGame(
        tags=tags,
        moves=moves,
        result=result,
        source=source,
        initial_fen=initial_fen,
        initial_comments=initial_comments,
    )


def _parse_sequence(
    parser: Parser,
    board: Board,
    fen_parser: FenParser,
) -> Tuple[List[PgnMoveNode], str, List[str]]:
    moves: List[PgnMoveNode] = []
    trailing_comments: List[str] = []
    result = '*'

    while not parser.at_end():
        token = parser.peek()
        if token is None:
            break
        if token.kind == 'RPAREN':
            break
        if token.kind == 'RESULT':
            result = parser.pop().value
            break
        if token.kind == 'MOVE_NO':
            parser.pop()
            continue
        if token.kind == 'COMMENT':
            comment = parser.pop().value
            if moves:
                moves[-1].comments.append(comment)
            else:
                trailing_comments.append(comment)
            continue
        if token.kind == 'NAG':
            nag = parser.pop().value
            if not moves:
                raise ValueError(f'NAG without move: {nag}')
            moves[-1].nags.append(nag)
            continue
        if token.kind == 'LPAREN':
            parser.pop()
            if not moves:
                raise ValueError('variation without anchor move')
            anchor = moves[-1]
            variation_board, _, variation_parser = _state_from_fen(anchor.fen_before)
            variation_moves, variation_result, pending = _parse_sequence(parser, variation_board, variation_parser)
            closing = parser.peek()
            if parser.at_end() or closing is None or closing.kind != 'RPAREN':
                raise ValueError('unterminated PGN variation')
            parser.pop()
            if pending and variation_moves:
                variation_moves[-1].comments.extend(pending)
            if variation_result != '*' and variation_moves:
                variation_moves[-1].comments.append(f'result {variation_result}')
            anchor.variations.append(variation_moves)
            continue
        if token.kind != 'SAN':
            raise ValueError(f'unexpected PGN token: {token.kind}')

        san_token = parser.pop().value
        fen_before = fen_parser.export()
        move = san_to_move(board, san_token)
        canonical = move_to_san(board, move)
        board.make_move(move)
        fen_after = fen_parser.export()
        moves.append(PgnMoveNode(canonical, move, fen_before, fen_after))

    return moves, result, trailing_comments


def serialize_game(game: PgnGame) -> str:
    lines = [f'[{name} "{value}"]' for name, value in game.tags.items()]
    if lines:
        lines.append('')
    move_number, color = _starting_ply(game.initial_fen)
    move_text = _serialize_sequence(game.moves, move_number, color)
    if game.initial_comments:
        prefix = ' '.join('{' + comment + '}' for comment in game.initial_comments)
        move_text = (prefix + ' ' + move_text).strip()
    if game.result:
        move_text = (move_text + ' ' + game.result).strip()
    lines.append(move_text if move_text else game.result)
    return '\n'.join(lines).strip() + '\n'


def _starting_ply(fen: str) -> Tuple[int, Color]:
    parts = fen.strip().split()
    if len(parts) >= 6:
        try:
            move_number = max(1, int(parts[5]))
        except ValueError:
            move_number = 1
        color = Color.BLACK if parts[1] == 'b' else Color.WHITE
        return move_number, color
    return 1, Color.WHITE


def _serialize_sequence(moves: List[PgnMoveNode], move_number: int, color: Color) -> str:
    parts: List[str] = []
    current_number = move_number
    current_color = color

    for node in moves:
        if current_color == Color.WHITE:
            parts.append(f'{current_number}. {node.san}')
        else:
            if not parts or not parts[-1].startswith(f'{current_number}.'):
                parts.append(f'{current_number}... {node.san}')
            else:
                parts.append(node.san)

        for nag in node.nags:
            parts.append(nag)
        for comment in node.comments:
            parts.append('{' + comment + '}')

        next_number = current_number + 1 if current_color == Color.BLACK else current_number
        next_color = Color.WHITE if current_color == Color.BLACK else Color.BLACK
        for variation in node.variations:
            parts.append('(' + _serialize_sequence(variation, next_number, next_color) + ')')

        current_number = next_number
        current_color = next_color

    return ' '.join(part for part in parts if part).strip()


def build_game_from_history(move_history: List[Move], start_fen: str = START_FEN, source: str = 'current-game') -> PgnGame:
    board, _, fen_parser = _state_from_fen(start_fen)
    moves: List[PgnMoveNode] = []
    for raw_move in move_history:
        move = Move(
            raw_move.from_row,
            raw_move.from_col,
            raw_move.to_row,
            raw_move.to_col,
            raw_move.promotion,
            is_castling=raw_move.is_castling,
            is_en_passant=raw_move.is_en_passant,
        )
        fen_before = fen_parser.export()
        san = move_to_san(board, move)
        board.make_move(move)
        fen_after = fen_parser.export()
        moves.append(PgnMoveNode(san, move, fen_before, fen_after))

    tags = {
        'Event': 'CLI Game',
        'Site': 'Local',
        'Result': '*',
    }
    if start_fen != START_FEN:
        tags['SetUp'] = '1'
        tags['FEN'] = start_fen

    return PgnGame(
        tags=tags,
        moves=moves,
        result='*',
        source=source,
        initial_fen=start_fen,
    )
def merge_game_with_history(
    previous: Optional[PgnGame],
    move_history: List[Move],
    start_fen: str = START_FEN,
    source: str = 'current-game',
) -> PgnGame:
    fresh = build_game_from_history(move_history, start_fen=start_fen, source=source)
    if previous is None:
        return fresh

    merged_tags = dict(previous.tags)
    merged_tags.setdefault('Event', 'CLI Game')
    merged_tags.setdefault('Site', 'Local')
    merged_tags['Result'] = previous.result if previous.result else '*'
    if start_fen != START_FEN:
        merged_tags['SetUp'] = '1'
        merged_tags['FEN'] = start_fen
    else:
        merged_tags.pop('SetUp', None)
        merged_tags.pop('FEN', None)

    fresh.tags = merged_tags
    fresh.result = previous.result if previous.result else '*'
    fresh.initial_comments = list(previous.initial_comments)

    overlap = min(len(previous.moves), len(fresh.moves))
    for index in range(overlap):
        old_node = previous.moves[index]
        new_node = fresh.moves[index]
        if (
            old_node.san == new_node.san
            and old_node.fen_before == new_node.fen_before
            and old_node.fen_after == new_node.fen_after
        ):
            new_node.nags = list(old_node.nags)
            new_node.comments = list(old_node.comments)
            new_node.variations = [
                [_copy_node(child) for child in variation]
                for variation in old_node.variations
            ]

    return fresh
