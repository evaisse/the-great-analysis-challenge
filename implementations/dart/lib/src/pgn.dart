import 'package:chess_engine/chess_engine.dart';

class PgnMoveNode {
  final String san;
  final String uci;
  final int moveNumber;
  final PieceColor color;
  final String positionBeforeFen;
  final List<String> nags;
  final List<String> commentsAfter;
  final List<PgnVariation> variations;

  PgnMoveNode(
    this.san,
    this.uci,
    this.moveNumber,
    this.color,
    this.positionBeforeFen, {
    List<String>? nags,
    List<String>? commentsAfter,
    List<PgnVariation>? variations,
  }) : nags = nags ?? <String>[],
       commentsAfter = commentsAfter ?? <String>[],
       variations = variations ?? <PgnVariation>[];
}

class PgnVariation {
  final String startFen;
  final List<String> leadingComments;
  final List<PgnMoveNode> moves;
  String? result;

  PgnVariation(
    this.startFen, {
    List<String>? leadingComments,
    List<PgnMoveNode>? moves,
    this.result,
  }) : leadingComments = leadingComments ?? <String>[],
       moves = moves ?? <PgnMoveNode>[];
}

class _PgnCursor {
  final PgnVariation variation;
  int cursorIndex;

  _PgnCursor(this.variation, this.cursorIndex);
}

class PgnGame {
  String source;
  final Map<String, String> tags;
  final PgnVariation mainline;
  String result;
  List<_PgnCursor> _cursorStack = <_PgnCursor>[];

  PgnGame(
    this.source,
    Map<String, String> tags,
    this.mainline, [
    String? result,
  ]) : tags = Map<String, String>.from(tags),
       result = result ?? '*' {
    _syncResultTag();
    resetCursor();
  }

  factory PgnGame.createLiveGame([
    String source = 'current-game',
    String? initialFen,
  ]) {
    final startFen = (initialFen == null || initialFen.trim().isEmpty)
        ? PgnSanCodec.startFen
        : initialFen.trim();
    final now = DateTime.now().toUtc();
    final tags = <String, String>{
      'Event': 'CLI Game',
      'Site': 'Local',
      'Date':
          '${now.year.toString().padLeft(4, '0')}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}',
      'Round': '-',
      'White': 'White',
      'Black': 'Black',
      'Result': '*',
    };
    if (startFen != PgnSanCodec.startFen) {
      tags['SetUp'] = '1';
      tags['FEN'] = startFen;
    }
    return PgnGame(source, tags, PgnVariation(startFen), '*');
  }

  void resetCursor() {
    _cursorStack = <_PgnCursor>[
      _PgnCursor(mainline, mainline.moves.length - 1),
    ];
  }

  void setSource(String value) {
    source = value;
  }

  void setResult(String value) {
    result = value;
    _syncResultTag();
  }

  List<String> mainlineMoves() {
    return mainline.moves.map((move) => move.san).toList(growable: false);
  }

  void appendMove(PgnMoveNode move) {
    final context = _cursorStack.last;
    context.variation.moves.add(move);
    context.cursorIndex = context.variation.moves.length - 1;
  }

  bool rewindLastMove() {
    final context = _cursorStack.last;
    if (context.cursorIndex != context.variation.moves.length - 1 ||
        context.cursorIndex < 0) {
      return false;
    }
    context.variation.moves.removeLast();
    context.cursorIndex = context.variation.moves.length - 1;
    setResult('*');
    return true;
  }

  void addComment(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final move = currentMove();
    if (move != null) {
      move.commentsAfter.add(trimmed);
      return;
    }
    currentVariation().leadingComments.add(trimmed);
  }

  ({bool ok, String message}) enterVariation() {
    final move = currentMove();
    if (move == null) {
      return (
        ok: false,
        message: 'ERROR: pgn variation enter requires a current move',
      );
    }
    if (move.variations.isEmpty) {
      move.variations.add(PgnVariation(move.positionBeforeFen));
    }
    final variation = move.variations.first;
    _cursorStack.add(_PgnCursor(variation, variation.moves.length - 1));
    return (
      ok: true,
      message:
          'PGN: variation depth=${_cursorStack.length - 1}; moves=${variation.moves.length}',
    );
  }

  ({bool ok, String message}) exitVariation() {
    if (_cursorStack.length <= 1) {
      return (ok: false, message: 'ERROR: already at mainline');
    }
    _cursorStack.removeLast();
    return (
      ok: true,
      message:
          'PGN: variation depth=${_cursorStack.length - 1}; moves=${currentVariation().moves.length}',
    );
  }

  PgnVariation currentVariation() => _cursorStack.last.variation;

  PgnMoveNode? currentMove() {
    final context = _cursorStack.last;
    if (context.cursorIndex < 0 ||
        context.cursorIndex >= context.variation.moves.length) {
      return null;
    }
    return context.variation.moves[context.cursorIndex];
  }

  String serialize() => PgnSerializer.serialize(this);

  void _syncResultTag() {
    tags['Result'] = result;
  }
}

class _PgnToken {
  final String type;
  final String value;
  final String? name;

  const _PgnToken(this.type, this.value, {this.name});
}

class PgnParser {
  List<_PgnToken> _tokens = <_PgnToken>[];
  int _index = 0;

  PgnGame parse(String content, [String source = 'current-game']) {
    _tokens = _tokenize(content);
    _index = 0;

    final tags = <String, String>{};
    while (true) {
      final token = _peek();
      if (token == null || token.type != 'TAG') {
        break;
      }
      _index++;
      tags[token.name!] = token.value;
    }

    final effectiveTags = tags.isEmpty
        ? PgnGame.createLiveGame(source).tags
        : Map<String, String>.from(tags);
    var startFen = PgnSanCodec.startFen;
    if (effectiveTags['SetUp'] == '1' &&
        (effectiveTags['FEN'] ?? '').trim().isNotEmpty) {
      startFen = effectiveTags['FEN']!.trim();
    }

    final parsed = _parseVariation(startFen, true);
    final gameResult = parsed.$2 ?? effectiveTags['Result'] ?? '*';
    return PgnGame(source, effectiveTags, parsed.$1, gameResult);
  }

  (PgnVariation, String?) _parseVariation(String startFen, bool isRoot) {
    final variation = PgnVariation(startFen);
    final board = Board.fromFen(startFen);
    String? result;
    PgnMoveNode? lastMove;

    while (true) {
      final token = _peek();
      if (token == null) {
        break;
      }

      if (token.type == 'VARIATION_END') {
        if (!isRoot) {
          _index++;
        }
        break;
      }

      if (token.type == 'RESULT') {
        _index++;
        if (isRoot) {
          result = token.value;
        } else {
          variation.result = token.value;
        }
        continue;
      }

      if (token.type == 'COMMENT') {
        _index++;
        if (lastMove != null) {
          lastMove.commentsAfter.add(token.value);
        } else {
          variation.leadingComments.add(token.value);
        }
        continue;
      }

      if (token.type == 'MOVE_NUMBER') {
        _index++;
        continue;
      }

      if (token.type == 'NAG') {
        _index++;
        if (lastMove != null) {
          lastMove.nags.add(token.value);
        }
        continue;
      }

      if (token.type == 'VARIATION_START') {
        _index++;
        final anchorFen = lastMove?.positionBeforeFen ?? startFen;
        final child = _parseVariation(anchorFen, false).$1;
        if (lastMove != null) {
          lastMove.variations.add(child);
        }
        continue;
      }

      if (token.type != 'SAN') {
        throw FormatException('Unsupported PGN token: ${token.type}');
      }

      _index++;
      final split = PgnSanCodec.splitAnnotatedSan(token.value);
      final rawSan = split.$1;
      final inlineNags = split.$2;
      final beforeFen = board.toFen();
      final legalMoves = board.generateMoves();
      final move = PgnSanCodec.resolveSan(
        board,
        rawSan,
        legalMoves: legalMoves,
      );
      final canonicalSan = PgnSanCodec.moveToSan(
        board,
        move,
        legalMoves: legalMoves,
      );
      final node = PgnMoveNode(
        canonicalSan,
        move.toString().toLowerCase(),
        board.get_fullmoveNumber_val(),
        board.turn == 'w' ? PieceColor.white : PieceColor.black,
        beforeFen,
        nags: List<String>.from(inlineNags),
      );
      variation.moves.add(node);
      lastMove = node;
      board.move(move.toString());
    }

    return (variation, result);
  }

  List<_PgnToken> _tokenize(String content) {
    final normalized = content.startsWith('\ufeff')
        ? content.substring(1)
        : content;
    final tokens = <_PgnToken>[];
    var i = 0;

    while (i < normalized.length) {
      final char = normalized[i];
      if (_isWhitespace(char)) {
        i++;
        continue;
      }

      if (char == '[') {
        final tag = _readTagToken(normalized, i);
        tokens.add(tag.$1);
        i = tag.$2;
        continue;
      }

      if (char == '{') {
        final end = normalized.indexOf('}', i + 1);
        final stop = end >= 0 ? end : normalized.length - 1;
        tokens.add(
          _PgnToken('COMMENT', normalized.substring(i + 1, stop).trim()),
        );
        i = stop + 1;
        continue;
      }

      if (char == ';') {
        final end = normalized.indexOf('\n', i + 1);
        final stop = end >= 0 ? end : normalized.length;
        tokens.add(
          _PgnToken('COMMENT', normalized.substring(i + 1, stop).trim()),
        );
        i = stop;
        continue;
      }

      if (char == '(') {
        tokens.add(const _PgnToken('VARIATION_START', '('));
        i++;
        continue;
      }

      if (char == ')') {
        tokens.add(const _PgnToken('VARIATION_END', ')'));
        i++;
        continue;
      }

      if (char == r'$') {
        var j = i + 1;
        while (j < normalized.length && _isDigit(normalized[j])) {
          j++;
        }
        tokens.add(_PgnToken('NAG', normalized.substring(i, j)));
        i = j;
        continue;
      }

      var j = i;
      while (j < normalized.length &&
          !_isWhitespace(normalized[j]) &&
          !_isDelimiter(normalized[j])) {
        j++;
      }

      final value = normalized.substring(i, j).trim();
      i = j;
      if (value.isEmpty) {
        continue;
      }

      if (_isResultToken(value)) {
        tokens.add(_PgnToken('RESULT', value));
      } else if (_isMoveNumberToken(value)) {
        tokens.add(_PgnToken('MOVE_NUMBER', value));
      } else {
        tokens.add(_PgnToken('SAN', value));
      }
    }

    return tokens;
  }

  (_PgnToken, int) _readTagToken(String content, int start) {
    var i = start + 1;
    while (i < content.length && _isWhitespace(content[i])) {
      i++;
    }

    final nameBuffer = StringBuffer();
    while (i < content.length && _isTagNameChar(content[i])) {
      nameBuffer.write(content[i]);
      i++;
    }

    while (i < content.length && _isWhitespace(content[i])) {
      i++;
    }

    final valueBuffer = StringBuffer();
    if (i < content.length && content[i] == '"') {
      i++;
      while (i < content.length) {
        if (content[i] == '\\' && i + 1 < content.length) {
          valueBuffer.write(content[i + 1]);
          i += 2;
          continue;
        }
        if (content[i] == '"') {
          i++;
          break;
        }
        valueBuffer.write(content[i]);
        i++;
      }
    }

    while (i < content.length && content[i] != ']') {
      i++;
    }
    if (i < content.length && content[i] == ']') {
      i++;
    }

    return (
      _PgnToken('TAG', valueBuffer.toString(), name: nameBuffer.toString()),
      i,
    );
  }

  _PgnToken? _peek() {
    if (_index >= _tokens.length) {
      return null;
    }
    return _tokens[_index];
  }

  bool _isWhitespace(String char) => RegExp(r'\s').hasMatch(char);

  bool _isDigit(String char) => RegExp(r'\d').hasMatch(char);

  bool _isDelimiter(String char) => '[]{}();'.contains(char);

  bool _isTagNameChar(String char) => RegExp(r'[A-Za-z0-9_]').hasMatch(char);

  bool _isResultToken(String value) {
    return value == '1-0' ||
        value == '0-1' ||
        value == '1/2-1/2' ||
        value == '*';
  }

  bool _isMoveNumberToken(String value) {
    return RegExp(r'^\d+\.(?:\.\.)?$').hasMatch(value) ||
        RegExp(r'^\d+\.\.\.$').hasMatch(value);
  }
}

class PgnSerializer {
  static String serialize(PgnGame game) {
    final lines = <String>[];
    for (final entry in _orderedTags(game.tags)) {
      final escaped = entry.$2.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
      lines.add('[${entry.$1} "$escaped"]');
    }
    lines.add('');
    final moveText = _serializeVariation(game.mainline, true).trim();
    if (moveText.isEmpty) {
      lines.add(game.result);
    } else {
      lines.add('$moveText ${game.result}');
    }
    return lines.join('\n');
  }

  static List<(String, String)> _orderedTags(Map<String, String> tags) {
    const orderedNames = <String>[
      'Event',
      'Site',
      'Date',
      'Round',
      'White',
      'Black',
      'Result',
      'SetUp',
      'FEN',
    ];
    final remaining = Map<String, String>.from(tags);
    final ordered = <(String, String)>[];
    for (final name in orderedNames) {
      final value = remaining.remove(name);
      if (value != null) {
        ordered.add((name, value));
      }
    }
    final extraKeys = remaining.keys.toList()..sort();
    for (final key in extraKeys) {
      ordered.add((key, remaining[key]!));
    }
    return ordered;
  }

  static String _serializeVariation(PgnVariation variation, bool isRoot) {
    final parts = <String>[];
    for (final comment in variation.leadingComments) {
      parts.add(_commentText(comment));
    }

    PieceColor? previousColor;
    for (final move in variation.moves) {
      if (move.color == PieceColor.white) {
        parts.add('${move.moveNumber}.');
      } else if (previousColor != PieceColor.white) {
        parts.add('${move.moveNumber}...');
      }

      parts.add(move.san);
      parts.addAll(move.nags);
      for (final comment in move.commentsAfter) {
        parts.add(_commentText(comment));
      }
      for (final child in move.variations) {
        parts.add('(${_serializeVariation(child, false)})');
      }

      previousColor = move.color;
    }

    if (!isRoot && (variation.result ?? '').trim().isNotEmpty) {
      parts.add(variation.result!.trim());
    }

    return parts.where((part) => part.trim().isNotEmpty).join(' ').trim();
  }

  static String _commentText(String comment) => '{${comment.trim()}}';
}

class PgnSanCodec {
  static const String startFen =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  static (String, List<String>) splitAnnotatedSan(String token) {
    var san = token.trim();
    final nags = <String>[];
    const annotationToNag = <String, String>{
      '!!': r'$3',
      '??': r'$4',
      '!?': r'$5',
      '?!': r'$6',
      '!': r'$1',
      '?': r'$2',
    };

    while (true) {
      var matched = false;
      for (final suffix in <String>['!!', '??', '!?', '?!', '!', '?']) {
        if (san.endsWith(suffix)) {
          nags.insert(0, annotationToNag[suffix]!);
          san = san.substring(0, san.length - suffix.length).trim();
          matched = true;
          break;
        }
      }
      if (!matched) {
        break;
      }
    }

    return (san, nags);
  }

  static Move resolveSan(Board board, String san, {List<Move>? legalMoves}) {
    final candidates = legalMoves ?? board.generateMoves();
    final target = normalizeSan(san);
    final matches = <Move>[];
    for (final move in candidates) {
      final candidate = moveToSan(board, move, legalMoves: candidates);
      if (normalizeSan(candidate) == target) {
        matches.add(move);
      }
    }
    if (matches.length == 1) {
      return matches.first;
    }
    if (matches.isEmpty) {
      throw FormatException('Illegal SAN move: $san');
    }
    throw FormatException('Ambiguous SAN move: $san');
  }

  static String moveToSan(Board board, Move move, {List<Move>? legalMoves}) {
    final candidates = legalMoves ?? board.generateMoves();
    final piece = board.squares[move.fromRow][move.fromCol];
    if (piece == null) {
      throw FormatException('Missing source piece for move ${move.toString()}');
    }

    late String san;
    if (move.isCastling) {
      san = move.toCol > move.fromCol ? 'O-O' : 'O-O-O';
    } else {
      final destination = _squareName(move.toRow, move.toCol);
      var isCapture = move.isEnPassant;
      if (!isCapture) {
        final target = board.squares[move.toRow][move.toCol];
        isCapture = target != null && target.color != piece.color;
      }

      final buffer = StringBuffer();
      if (piece.type == PieceType.pawn) {
        if (isCapture) {
          buffer.write(_fileChar(move.fromCol));
        }
      } else {
        buffer.write(_pieceLetter(piece.type));
        buffer.write(_disambiguation(board, move, piece.type, candidates));
      }
      if (isCapture) {
        buffer.write('x');
      }
      buffer.write(destination);
      if (move.promotion != null) {
        buffer.write('=');
        buffer.write(_pieceLetter(move.promotion!));
      }
      san = buffer.toString();
    }

    final clone = board.clone();
    clone.move(move.toString());
    final nextMoves = clone.generateMoves();
    final sideToMove = clone.turn == 'w' ? PieceColor.white : PieceColor.black;
    if (nextMoves.isEmpty && clone.isKingInCheck(sideToMove)) {
      return '$san#';
    }
    if (clone.isKingInCheck(sideToMove)) {
      return '$san+';
    }
    return san;
  }

  static String normalizeSan(String san) {
    var normalized = san.trim().replaceAll('0', 'O');
    normalized = normalized.replaceAll(RegExp(r'[+#]+$'), '');
    normalized = splitAnnotatedSan(normalized).$1;
    return normalized.trim();
  }

  static String _pieceLetter(PieceType pieceType) {
    switch (pieceType) {
      case PieceType.knight:
        return 'N';
      case PieceType.bishop:
        return 'B';
      case PieceType.rook:
        return 'R';
      case PieceType.queen:
        return 'Q';
      case PieceType.king:
        return 'K';
      case PieceType.pawn:
        return '';
    }
  }

  static String _squareName(int row, int col) => '${_fileChar(col)}${8 - row}';

  static String _fileChar(int col) =>
      String.fromCharCode('a'.codeUnitAt(0) + col);

  static String _disambiguation(
    Board board,
    Move move,
    PieceType pieceType,
    List<Move> legalMoves,
  ) {
    final matches = <Move>[];
    for (final candidate in legalMoves) {
      if (candidate.fromRow == move.fromRow &&
          candidate.fromCol == move.fromCol &&
          candidate.toRow == move.toRow &&
          candidate.toCol == move.toCol &&
          candidate.promotion == move.promotion) {
        continue;
      }
      if (candidate.toRow != move.toRow || candidate.toCol != move.toCol) {
        continue;
      }
      if (candidate.promotion != move.promotion) {
        continue;
      }
      final piece = board.squares[candidate.fromRow][candidate.fromCol];
      if (piece != null &&
          piece.type == pieceType &&
          piece.color ==
              (board.turn == 'w' ? PieceColor.white : PieceColor.black)) {
        matches.add(candidate);
      }
    }

    if (matches.isEmpty) {
      return '';
    }

    var shareFile = false;
    var shareRank = false;
    for (final candidate in matches) {
      if (candidate.fromCol == move.fromCol) {
        shareFile = true;
      }
      if (candidate.fromRow == move.fromRow) {
        shareRank = true;
      }
    }

    final file = _fileChar(move.fromCol);
    final rank = '${8 - move.fromRow}';
    if (!shareFile) {
      return file;
    }
    if (!shareRank) {
      return rank;
    }
    return '$file$rank';
  }
}
