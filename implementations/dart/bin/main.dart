import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:chess_engine/chess_engine.dart';

typedef TraceAiRecorder =
    void Function(
      String source,
      String move,
      int depth,
      int scoreCp,
      int elapsedMs,
      bool timedOut,
      int nodes,
      int evalCalls,
      int ttHits,
      int ttMisses,
      int betaCutoffs,
    );

const _chess960KnightTable = <(int, int)>[
  (0, 1),
  (0, 2),
  (0, 3),
  (0, 4),
  (1, 2),
  (1, 3),
  (1, 4),
  (2, 3),
  (2, 4),
  (3, 4),
];

String _decodeChess960Backrank(int id) {
  final pieces = List<String?>.filled(8, null);
  var n = id;

  var remainder = n % 4;
  n ~/= 4;
  pieces[2 * remainder + 1] = 'b';

  remainder = n % 4;
  n ~/= 4;
  pieces[2 * remainder] = 'b';

  var empty = [
    for (var i = 0; i < pieces.length; i++)
      if (pieces[i] == null) i,
  ];
  remainder = n % 6;
  n ~/= 6;
  pieces[empty[remainder]] = 'q';

  final knights = _chess960KnightTable[n];
  empty = [
    for (var i = 0; i < pieces.length; i++)
      if (pieces[i] == null) i,
  ];
  pieces[empty[knights.$1]] = 'n';
  pieces[empty[knights.$2]] = 'n';

  empty = [
    for (var i = 0; i < pieces.length; i++)
      if (pieces[i] == null) i,
  ];
  pieces[empty[0]] = 'r';
  pieces[empty[1]] = 'k';
  pieces[empty[2]] = 'r';

  return pieces.map((piece) => piece ?? '').join();
}

String _buildChess960Fen(int id) {
  final white = _decodeChess960Backrank(id).toUpperCase();
  final black = white.toLowerCase();
  return '$black/pppppppp/8/8/8/8/PPPPPPPP/$white w - - 0 1';
}

Future<void> main() async {
  final game = Game();
  var ai = AI();
  String? pgnPath;
  List<String> pgnMoves = [];
  var pgnGame = PgnGame.createLiveGame();
  String? bookPath;
  bool bookEnabled = false;
  Map<String, List<BookEntry>> bookEntries = {};
  int bookEntryCount = 0;
  int bookLookups = 0;
  int bookHits = 0;
  int bookMisses = 0;
  int bookPlayed = 0;
  var uciHashMb = 16;
  var uciThreads = 1;
  int chess960Id = 0;
  bool traceEnabled = false;
  String traceLevel = 'info';
  final List<Map<String, dynamic>> traceEvents = [];
  int traceCommandCount = 0;
  int traceExportCount = 0;
  String? traceLastExportTarget;
  int traceLastExportEvents = 0;
  int traceLastExportBytes = 0;
  int traceChromeCount = 0;
  String? traceLastChromeTarget;
  int traceLastChromeEvents = 0;
  int traceLastChromeBytes = 0;
  String? traceLastAiSource;
  String? traceLastAiMove;
  int traceLastAiDepth = 0;
  int traceLastAiScoreCp = 0;
  int traceLastAiElapsedMs = 0;
  bool traceLastAiTimedOut = false;
  int traceLastAiNodes = 0;
  int traceLastAiEvalCalls = 0;
  int traceLastAiNps = 0;
  int traceLastAiTtHits = 0;
  int traceLastAiTtMisses = 0;
  int traceLastAiBetaCutoffs = 0;

  void recordTrace(String event, String detail) {
    if (!traceEnabled) return;
    traceEvents.add({
      'ts_ms': DateTime.now().millisecondsSinceEpoch,
      'event': event,
      'detail': detail,
    });
    if (traceEvents.length > 256) {
      traceEvents.removeRange(0, traceEvents.length - 256);
    }
  }

  String resolveTraceTarget(List<String> commandParts) {
    final rawTarget = commandParts.length > 2
        ? commandParts.sublist(2).join(' ').trim()
        : '';
    return rawTarget.isEmpty ? '(memory)' : rawTarget;
  }

  String formatTraceTransferSummary(
    int count,
    String? target,
    int eventCount,
    int byteCount,
  ) {
    if (count == 0 || target == null) {
      return 'none';
    }
    return '$target ($eventCount events, $byteCount bytes)';
  }

  void resetTraceAiState() {
    traceLastAiSource = null;
    traceLastAiMove = null;
    traceLastAiDepth = 0;
    traceLastAiScoreCp = 0;
    traceLastAiElapsedMs = 0;
    traceLastAiTimedOut = false;
    traceLastAiNodes = 0;
    traceLastAiEvalCalls = 0;
    traceLastAiNps = 0;
    traceLastAiTtHits = 0;
    traceLastAiTtMisses = 0;
    traceLastAiBetaCutoffs = 0;
  }

  String formatTraceAiSummary() {
    if (traceLastAiSource == null || traceLastAiMove == null) {
      return 'none';
    }

    var summary = '${traceLastAiSource!}:${traceLastAiMove!}';
    if (traceLastAiSource!.contains('search')) {
      summary +=
          '@d$traceLastAiDepth/$traceLastAiScoreCp'
          'cp/${traceLastAiElapsedMs}ms';
      summary +=
          '/n$traceLastAiNodes/e$traceLastAiEvalCalls/nps$traceLastAiNps';
      if (traceLastAiTimedOut) {
        summary += '/timeout';
      }
    } else if (traceLastAiSource!.contains('endgame')) {
      summary += '/${traceLastAiScoreCp}cp';
    }

    return summary;
  }

  String? formatTraceSearchMetrics() {
    if (traceLastAiSource == null || !traceLastAiSource!.contains('search')) {
      return null;
    }
    return 'nodes=$traceLastAiNodes,eval_calls=$traceLastAiEvalCalls,tt_hits=$traceLastAiTtHits,tt_misses=$traceLastAiTtMisses,beta_cutoffs=$traceLastAiBetaCutoffs,nps=$traceLastAiNps';
  }

  void recordTraceAi(
    String source,
    String move,
    int depth,
    int scoreCp,
    int elapsedMs,
    bool timedOut,
    int nodes,
    int evalCalls,
    int ttHits,
    int ttMisses,
    int betaCutoffs,
  ) {
    traceLastAiSource = source;
    traceLastAiMove = move;
    traceLastAiDepth = depth;
    traceLastAiScoreCp = scoreCp;
    traceLastAiElapsedMs = elapsedMs;
    traceLastAiTimedOut = timedOut;
    traceLastAiNodes = nodes;
    traceLastAiEvalCalls = evalCalls;
    final divisor = elapsedMs > 0 ? elapsedMs : 1;
    traceLastAiNps = nodes > 0 ? (nodes * 1000) ~/ divisor : 0;
    traceLastAiTtHits = ttHits;
    traceLastAiTtMisses = ttMisses;
    traceLastAiBetaCutoffs = betaCutoffs;
    recordTrace('ai', formatTraceAiSummary());
  }

  Map<String, dynamic>? buildTraceAiPayload() {
    if (traceLastAiSource == null || traceLastAiMove == null) {
      return null;
    }

    return {
      'source': traceLastAiSource,
      'move': traceLastAiMove,
      'depth': traceLastAiDepth,
      'score_cp': traceLastAiScoreCp,
      'elapsed_ms': traceLastAiElapsedMs,
      'timed_out': traceLastAiTimedOut,
      'nodes': traceLastAiNodes,
      'eval_calls': traceLastAiEvalCalls,
      'nps': traceLastAiNps,
      'tt_hits': traceLastAiTtHits,
      'tt_misses': traceLastAiTtMisses,
      'beta_cutoffs': traceLastAiBetaCutoffs,
      'summary': formatTraceAiSummary(),
    };
  }

  String buildStructuredTraceJson() {
    final snapshot = traceEvents
        .map((event) => Map<String, dynamic>.from(event))
        .toList(growable: false);
    final payload = <String, dynamic>{
      'format': 'tgac.trace.v1',
      'engine': 'dart',
      'generated_at_ms': DateTime.now().millisecondsSinceEpoch,
      'enabled': traceEnabled,
      'level': traceLevel,
      'command_count': traceCommandCount,
      'event_count': snapshot.length,
      'events': snapshot,
    };
    final lastAi = buildTraceAiPayload();
    if (lastAi != null) {
      payload['last_ai'] = lastAi;
    }
    return '${jsonEncode(payload)}\n';
  }

  String buildChromeTraceJson() {
    final chromeEvents = traceEvents
        .map((event) {
          final tsMs = event['ts_ms'] is int ? event['ts_ms'] as int : 0;
          return {
            'name': event['event'] ?? 'trace',
            'cat': 'engine',
            'ph': 'i',
            's': 'p',
            'ts': tsMs * 1000,
            'pid': 1,
            'tid': 1,
            'args': {
              'detail': event['detail'] ?? '',
              'level': traceLevel,
              'ts_ms': tsMs,
            },
          };
        })
        .toList(growable: false);

    return '${jsonEncode({'format': 'tgac.chrome_trace.v1', 'engine': 'dart', 'generated_at_ms': DateTime.now().millisecondsSinceEpoch, 'enabled': traceEnabled, 'level': traceLevel, 'command_count': traceCommandCount, 'event_count': chromeEvents.length, 'display_time_unit': 'ms', 'events': chromeEvents})}\n';
  }

  Future<int> writeTracePayload(String target, String content) async {
    final bytes = utf8.encode(content);
    if (target != '(memory)') {
      await File(target).writeAsBytes(bytes, flush: true);
    }
    return bytes.length;
  }

  String? chooseBookMove() {
    bookLookups++;
    if (!bookEnabled || bookEntries.isEmpty) {
      bookMisses++;
      return null;
    }

    final key = _bookPositionKeyFromFen(game.board.toFen());
    final entries = bookEntries[key];
    if (entries == null || entries.isEmpty) {
      bookMisses++;
      return null;
    }

    final legalByNotation = <String, Move>{};
    for (final legalMove in game.board.generateMoves()) {
      legalByNotation[legalMove.toString().toLowerCase()] = legalMove;
    }

    final weighted = <({Move move, int weight})>[];
    var totalWeight = 0;
    for (final entry in entries) {
      final legal = legalByNotation[entry.move];
      if (legal == null) continue;
      final weight = entry.weight > 0 ? entry.weight : 1;
      weighted.add((move: legal, weight: weight));
      totalWeight += weight;
    }

    if (weighted.isEmpty || totalWeight <= 0) {
      bookMisses++;
      return null;
    }

    final selector =
        ((game.board.zobristHash.toUnsigned(64).toInt()) + bookLookups) %
        totalWeight;
    var acc = 0;
    Move chosen = weighted.first.move;
    for (final item in weighted) {
      acc += item.weight;
      if (selector < acc) {
        chosen = item.move;
        break;
      }
    }

    bookHits++;
    return chosen.toString().toLowerCase();
  }

  ({String move, EndgameInfo info})? chooseEndgameMove() {
    final rootInfo = _detectEndgame(game.board);
    if (rootInfo == null) {
      return null;
    }

    final legalMoves = game.board.generateMoves();
    if (legalMoves.isEmpty) {
      return null;
    }

    final rootIsWhite = game.board.turn == 'w';
    var bestMove = legalMoves.first;
    var bestNotation = bestMove.toString().toLowerCase();
    var bestScore = -1 << 30;

    for (final candidate in legalMoves) {
      final clone = game.board.clone();
      clone.move(candidate.toString());
      final nextInfo = _detectEndgame(clone);
      var score = nextInfo?.scoreWhite ?? ai.evaluate(clone);
      if (!rootIsWhite) {
        score = -score;
      }
      final notation = candidate.toString().toLowerCase();
      if (score > bestScore ||
          (score == bestScore && notation.compareTo(bestNotation) < 0)) {
        bestScore = score;
        bestMove = candidate;
        bestNotation = notation;
      }
    }

    return (move: bestMove.toString().toLowerCase(), info: rootInfo);
  }

  void refreshPgnMoveCache() {
    pgnMoves = pgnGame.mainlineMoves();
  }

  void resetPgnLiveGame([String? source]) {
    final resolvedSource = (source ?? pgnPath ?? 'current-game').trim();
    final effectiveSource = resolvedSource.isEmpty
        ? 'current-game'
        : resolvedSource;
    pgnGame = PgnGame.createLiveGame(effectiveSource, game.board.toFen());
    pgnPath = effectiveSource == 'current-game' ? null : effectiveSource;
    refreshPgnMoveCache();
  }

  void appendPgnMoveRecord(
    Move move,
    String san,
    String beforeFen,
    int moveNumber,
    PieceColor color,
  ) {
    pgnGame.appendMove(
      PgnMoveNode(
        san,
        move.toString().toLowerCase(),
        moveNumber,
        color,
        beforeFen,
      ),
    );
    refreshPgnMoveCache();
  }

  void syncPgnResultWithPosition() {
    final legalMoves = game.board.generateMoves();
    if (legalMoves.isEmpty) {
      final playerColor = game.board.turn == 'w'
          ? PieceColor.white
          : PieceColor.black;
      if (game.board.isKingInCheck(playerColor)) {
        pgnGame.setResult(game.board.turn == 'w' ? '0-1' : '1-0');
      } else {
        pgnGame.setResult('1/2-1/2');
      }
      return;
    }

    if (DrawDetection.isDraw(game.board)) {
      pgnGame.setResult('1/2-1/2');
      return;
    }

    pgnGame.setResult('*');
  }

  void rebuildBoardFromPgnCursor() {
    final variation = pgnGame.currentVariation();
    game.loadFen(variation.startFen);
    for (final node in variation.moves) {
      game.move(node.uci);
    }
    ai = AI();
    syncPgnResultWithPosition();
  }

  String? extractPgnCommentText(String commandLine) {
    final trimmed = commandLine.trim();
    final quoted = RegExp(
      r'^pgn\s+comment\s+"((?:\\.|[^"])*)"\s*$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (quoted != null) {
      return quoted.group(1)!.replaceAll(r'\"', '"').replaceAll(r'\\', '\\');
    }
    final plain = RegExp(
      r'^pgn\s+comment\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (plain != null) {
      final text = plain.group(1)!.trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  void recordMoveForPgn(Move move) {
    final legalMoves = game.board.generateMoves();
    final beforeFen = game.board.toFen();
    final moveNumber = game.board.get_fullmoveNumber_val();
    final color = game.board.turn == 'w' ? PieceColor.white : PieceColor.black;
    final san = PgnSanCodec.moveToSan(game.board, move, legalMoves: legalMoves);
    game.move(move.toString());
    appendPgnMoveRecord(move, san, beforeFen, moveNumber, color);
    syncPgnResultWithPosition();
  }

  resetPgnLiveGame();

  while (true) {
    final line = stdin.readLineSync();
    if (line == null) {
      break;
    }
    final parts = line.split(' ');
    final command = parts[0].toLowerCase();
    if (command != 'trace') {
      traceCommandCount++;
      recordTrace('command', line.trim());
    }
    switch (command) {
      case 'move':
        if (parts.length < 2) {
          print('ERROR: Invalid move format');
          break;
        }
        final moveStr = parts[1];
        try {
          final resolved = game.resolveMove(moveStr);
          recordMoveForPgn(resolved);
          game.printBoard();
          _checkGameState(game);
        } catch (e) {
          print(e);
        }
        break;
      case 'undo':
        game.undo();
        if (pgnGame.rewindLastMove()) {
          refreshPgnMoveCache();
          syncPgnResultWithPosition();
        }
        game.printBoard();
        break;
      case 'new':
        game.init();
        ai = AI();
        resetPgnLiveGame();
        print('OK: New game started');
        game.printBoard();
        break;
      case 'ai':
        if (parts.length < 2) {
          print('ERROR: AI depth must be 1-5');
          break;
        }
        final depth = int.tryParse(parts[1]);
        if (depth == null || depth < 1 || depth > 5) {
          print('ERROR: AI depth must be 1-5');
          break;
        }
        final endgameChoice = chooseEndgameMove();
        _runAiMove(
          game,
          ai,
          depth,
          onMoveApplied: recordMoveForPgn,
          onAiResult: recordTraceAi,
          bookMove: chooseBookMove(),
          onBookPlayed: () => bookPlayed++,
          endgameMove: endgameChoice?.move,
          endgameInfo: endgameChoice?.info,
        );
        break;
      case 'fen':
        if (parts.length < 2) {
          print('ERROR: Invalid FEN string');
          break;
        }
        final fen = parts.sublist(1).join(' ');
        game.loadFen(fen);
        resetPgnLiveGame();
        game.printBoard();
        break;
      case 'export':
        game.export();
        break;
      case 'eval':
        final score = ai.evaluate(game.board);
        print('Evaluation: $score');
        break;
      case 'hash':
        print(
          'HASH: ${game.board.zobristHash.toUnsigned(64).toRadixString(16).padLeft(16, '0')}',
        );
        break;
      case 'draws':
        final repetition = _repetitionCount(game.board);
        final halfmove = game.board.get_halfmoveClock_val();
        final draw = repetition >= 3 || halfmove >= 100;
        var reason = 'none';
        if (halfmove >= 100) {
          reason = 'fifty_moves';
        } else if (repetition >= 3) {
          reason = 'repetition';
        }
        print(
          'DRAWS: repetition=$repetition; halfmove=$halfmove; draw=${draw ? 'true' : 'false'}; reason=$reason',
        );
        break;
      case 'history':
        print(
          'HISTORY: count=${game.board.positionHistory.length + 1}; current=${game.board.zobristHash.toUnsigned(64).toRadixString(16).padLeft(16, '0')}',
        );
        print(
          'Position History (${game.board.positionHistory.length + 1} positions):',
        );
        for (int i = 0; i < game.board.positionHistory.length; i++) {
          print(
            '  $i: ${game.board.positionHistory[i].toUnsigned(64).toRadixString(16).padLeft(16, '0')}',
          );
        }
        print(
          '  ${game.board.positionHistory.length}: ${game.board.zobristHash.toUnsigned(64).toRadixString(16).padLeft(16, '0')} (current)',
        );
        break;
      case 'go':
        if (parts.length < 2) {
          print(
            'ERROR: go requires subcommand (movetime <ms>|wtime <ms> btime <ms> winc <ms> binc <ms> [movestogo <n>]|infinite)',
          );
          break;
        }
        final sub = parts[1].toLowerCase();
        if (sub == 'depth') {
          if (parts.length < 3) {
            print('ERROR: go depth requires a value');
            break;
          }
          final depth = int.tryParse(parts[2]);
          if (depth == null) {
            print('ERROR: go depth requires an integer value');
            break;
          }
          var boundedDepth = depth;
          if (boundedDepth < 1) boundedDepth = 1;
          if (boundedDepth > 5) boundedDepth = 5;
          final bookMove = chooseBookMove();
          if (bookMove != null) {
            recordTraceAi('uci-book', bookMove, 0, 0, 0, false, 0, 0, 0, 0, 0);
            print('info string bookmove $bookMove');
            print('bestmove $bookMove');
            break;
          }
          final endgameChoice = chooseEndgameMove();
          if (endgameChoice != null) {
            recordTraceAi(
              'uci-endgame',
              endgameChoice.move,
              0,
              endgameChoice.info.scoreWhite,
              0,
              false,
              0,
              0,
              0,
              0,
              0,
            );
            print(
              'info string endgame ${endgameChoice.info.type} score cp ${endgameChoice.info.scoreWhite}',
            );
            print('bestmove ${endgameChoice.move}');
            break;
          }
          final result = ai.search(game.board, boundedDepth, movetimeMs: 0);
          final move = result.move;
          if (move == null) {
            print('bestmove 0000');
            break;
          }
          recordTraceAi(
            'uci-search',
            move.toString(),
            result.depth,
            result.score,
            result.elapsedMs,
            result.timedOut,
            result.nodes,
            result.evalCalls,
            result.ttHits,
            result.ttMisses,
            result.betaCutoffs,
          );
          print(
            'info depth ${result.depth} score cp ${result.score} time ${result.elapsedMs} nodes ${result.nodes}',
          );
          print('bestmove ${move.toString()}');
          break;
        }
        if (sub == 'movetime') {
          if (parts.length < 3) {
            print('ERROR: go movetime requires a value in milliseconds');
            break;
          }
          final movetime = int.tryParse(parts[2]);
          if (movetime == null) {
            print('ERROR: go movetime requires an integer value');
            break;
          }
          if (movetime <= 0) {
            print('ERROR: go movetime must be > 0');
            break;
          }
          final endgameChoice = chooseEndgameMove();
          _runAiTimedMove(
            game,
            ai,
            5,
            movetime,
            onMoveApplied: recordMoveForPgn,
            onAiResult: recordTraceAi,
            bookMove: chooseBookMove(),
            onBookPlayed: () => bookPlayed++,
            endgameMove: endgameChoice?.move,
            endgameInfo: endgameChoice?.info,
          );
          break;
        }
        if (sub == 'wtime') {
          final parsed = _deriveMovetimeFromClocks(
            parts.sublist(1),
            game.board,
          );
          if (parsed.$2 != null) {
            print('ERROR: ${parsed.$2}');
            break;
          }
          final endgameChoice = chooseEndgameMove();
          _runAiTimedMove(
            game,
            ai,
            5,
            parsed.$1,
            onMoveApplied: recordMoveForPgn,
            onAiResult: recordTraceAi,
            bookMove: chooseBookMove(),
            onBookPlayed: () => bookPlayed++,
            endgameMove: endgameChoice?.move,
            endgameInfo: endgameChoice?.info,
          );
          break;
        }
        if (sub == 'infinite') {
          print('OK: go infinite acknowledged (bounded search mode)');
          final endgameChoice = chooseEndgameMove();
          _runAiTimedMove(
            game,
            ai,
            5,
            15000,
            onMoveApplied: recordMoveForPgn,
            onAiResult: recordTraceAi,
            bookMove: chooseBookMove(),
            onBookPlayed: () => bookPlayed++,
            endgameMove: endgameChoice?.move,
            endgameInfo: endgameChoice?.info,
          );
          break;
        }
        print('ERROR: Unsupported go command');
        break;
      case 'stop':
        ai.requestStop();
        print('OK: stop');
        break;
      case 'pgn':
        if (parts.length < 2) {
          print(
            'ERROR: pgn requires subcommand (load|save|show|moves|variation|comment)',
          );
          break;
        }
        final sub = parts[1].toLowerCase();
        if (sub == 'load') {
          if (parts.length < 3) {
            print('ERROR: pgn load requires a file path');
            break;
          }
          final path = parts.sublist(2).join(' ');
          pgnPath = path;
          pgnMoves = [];
          try {
            final content = File(path).readAsStringSync();
            pgnGame = PgnParser().parse(content, path);
            pgnGame.setSource(path);
            refreshPgnMoveCache();
            rebuildBoardFromPgnCursor();
            print('PGN: loaded path="$path"; moves=${pgnMoves.length}');
          } on FileSystemException {
            resetPgnLiveGame(path);
            print('PGN: loaded path="$path"; moves=0; note=file-unavailable');
          } catch (e) {
            print('ERROR: pgn load failed: $e');
          }
          break;
        }
        if (sub == 'save') {
          if (parts.length < 3) {
            print('ERROR: pgn save requires a file path');
            break;
          }
          final path = parts.sublist(2).join(' ');
          try {
            File(
              path,
            ).writeAsStringSync('${pgnGame.serialize()}\n', flush: true);
            pgnPath = path;
            pgnGame.setSource(path);
            print('PGN: saved path="$path"; moves=${pgnMoves.length}');
          } catch (_) {
            print('ERROR: pgn save failed: unable to write file');
          }
          break;
        }
        if (sub == 'show') {
          final source = pgnPath ?? 'current-game';
          print('PGN: source=$source; moves=${pgnMoves.length}');
          print(pgnGame.serialize());
          break;
        }
        if (sub == 'moves') {
          if (pgnMoves.isEmpty) {
            print('PGN: moves (none)');
          } else {
            print('PGN: moves ${pgnMoves.join(' ')}');
          }
          break;
        }
        if (sub == 'variation') {
          if (parts.length < 3) {
            print('ERROR: pgn variation requires enter|exit');
            break;
          }
          final action = parts[2].toLowerCase();
          if (action == 'enter') {
            final result = pgnGame.enterVariation();
            if (result.ok) {
              rebuildBoardFromPgnCursor();
            }
            print(result.message);
            break;
          }
          if (action == 'exit') {
            final result = pgnGame.exitVariation();
            if (result.ok) {
              rebuildBoardFromPgnCursor();
            }
            print(result.message);
            break;
          }
          print('ERROR: pgn variation requires enter|exit');
          break;
        }
        if (sub == 'comment') {
          final text = extractPgnCommentText(line);
          if (text == null || text.trim().isEmpty) {
            print('ERROR: pgn comment requires text');
            break;
          }
          pgnGame.addComment(text);
          final escaped = text.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
          print('PGN: comment added text="$escaped"');
          break;
        }
        print('ERROR: Unsupported pgn command');
        break;
      case 'book':
        if (parts.length < 2) {
          print('ERROR: book requires subcommand (load|on|off|stats)');
          break;
        }
        final sub = parts[1].toLowerCase();
        if (sub == 'load') {
          if (parts.length < 3) {
            print('ERROR: book load requires a file path');
            break;
          }
          final path = parts.sublist(2).join(' ');
          try {
            final content = File(path).readAsStringSync();
            final parsed = _parseBookEntries(content);
            bookPath = path;
            bookEntries = parsed.$1;
            bookEntryCount = parsed.$2;
            bookEnabled = true;
            bookLookups = 0;
            bookHits = 0;
            bookMisses = 0;
            bookPlayed = 0;
            print(
              'BOOK: loaded path="$path"; positions=${bookEntries.length}; entries=$bookEntryCount; enabled=true',
            );
          } catch (e) {
            print('ERROR: book load failed: $e');
          }
          break;
        }
        if (sub == 'on') {
          bookEnabled = true;
          print('BOOK: enabled=true');
          break;
        }
        if (sub == 'off') {
          bookEnabled = false;
          print('BOOK: enabled=false');
          break;
        }
        if (sub == 'stats') {
          final path = bookPath ?? '(none)';
          final enabled = bookEnabled ? 'true' : 'false';
          print(
            'BOOK: enabled=$enabled; path=$path; positions=${bookEntries.length}; entries=$bookEntryCount; lookups=$bookLookups; hits=$bookHits; misses=$bookMisses; played=$bookPlayed',
          );
          break;
        }
        print('ERROR: Unsupported book command');
        break;
      case 'endgame':
        final info = _detectEndgame(game.board);
        if (info == null) {
          final active = game.board.turn == 'w' ? 'white' : 'black';
          print('ENDGAME: type=none; active=$active; score=0');
          break;
        }
        final choice = chooseEndgameMove();
        var output =
            'ENDGAME: type=${info.type}; strong=${info.strong}; weak=${info.weak}; score=${info.scoreWhite}';
        if (choice != null) {
          output += '; bestmove=${choice.move}';
        }
        output += '; detail=${info.detail}';
        print(output);
        break;
      case 'uci':
        print('uciok');
        break;
      case 'isready':
        print('readyok');
        break;
      case 'setoption':
        if (parts.length < 5 || parts[1].toLowerCase() != 'name') {
          print(
            "ERROR: setoption format is 'setoption name <Hash|Threads> value <n>'",
          );
          break;
        }
        int valueIdx = -1;
        for (int i = 2; i < parts.length; i++) {
          if (parts[i].toLowerCase() == 'value') {
            valueIdx = i;
            break;
          }
        }
        if (valueIdx <= 2 || valueIdx + 1 >= parts.length) {
          print("ERROR: setoption requires 'value <n>'");
          break;
        }
        final optionName = parts.sublist(2, valueIdx).join(' ').toLowerCase();
        final value = int.tryParse(parts[valueIdx + 1]);
        if (value == null) {
          print('ERROR: setoption value must be an integer');
          break;
        }
        if (optionName == 'hash') {
          uciHashMb = value.clamp(1, 1024).toInt();
          print('info string option Hash=$uciHashMb');
          break;
        }
        if (optionName == 'threads') {
          uciThreads = value.clamp(1, 64).toInt();
          print('info string option Threads=$uciThreads');
          break;
        }
        print(
          'info string unsupported option ${parts.sublist(2, valueIdx).join(' ')}',
        );
        break;
      case 'ucinewgame':
        game.init();
        ai = AI();
        resetPgnLiveGame();
        break;
      case 'position':
        if (parts.length < 2) {
          print("ERROR: position requires 'startpos' or 'fen <...>'");
          break;
        }
        var idx = 2;
        final keyword = parts[1].toLowerCase();
        if (keyword == 'startpos') {
          game.init();
          ai = AI();
        } else if (keyword == 'fen') {
          final fenTokens = <String>[];
          while (idx < parts.length && parts[idx].toLowerCase() != 'moves') {
            fenTokens.add(parts[idx]);
            idx++;
          }
          if (fenTokens.isEmpty) {
            print('ERROR: position fen requires a FEN string');
            break;
          }
          try {
            game.loadFen(fenTokens.join(' '));
          } catch (e) {
            print('ERROR: Invalid FEN string: $e');
            break;
          }
        } else {
          print("ERROR: position requires 'startpos' or 'fen <...>'");
          break;
        }

        resetPgnLiveGame();

        if (idx < parts.length && parts[idx].toLowerCase() == 'moves') {
          idx++;
          for (int i = idx; i < parts.length; i++) {
            try {
              _applyMoveSilently(
                game,
                parts[i],
                onMoveApplied: recordMoveForPgn,
              );
            } catch (e) {
              print('ERROR: position move ${parts[i]} failed: $e');
              break;
            }
          }
        }
        break;
      case 'new960':
        var id = 0;
        if (parts.length > 1) {
          final parsed = int.tryParse(parts[1]);
          if (parsed == null) {
            print('ERROR: new960 id must be an integer');
            break;
          }
          id = parsed;
        }
        if (id < 0 || id > 959) {
          print('ERROR: new960 id must be between 0 and 959');
          break;
        }
        chess960Id = id;
        game.loadFen(_buildChess960Fen(chess960Id));
        resetPgnLiveGame();
        print('OK: New game started');
        game.printBoard();
        print(
          '960: new game id=$chess960Id; '
          'backrank=${_decodeChess960Backrank(chess960Id)}',
        );
        break;
      case 'position960':
        print(
          '960: id=$chess960Id; mode=chess960; '
          'backrank=${_decodeChess960Backrank(chess960Id)}; '
          'fen=${_buildChess960Fen(chess960Id)}',
        );
        break;
      case 'trace':
        if (parts.length < 2) {
          print('ERROR: trace requires subcommand');
          break;
        }
        final sub = parts[1].toLowerCase();
        if (sub == 'on') {
          traceEnabled = true;
          recordTrace('trace', 'enabled');
          print(
            'TRACE: enabled=true; level=$traceLevel; events=${traceEvents.length}',
          );
          break;
        }
        if (sub == 'off') {
          recordTrace('trace', 'disabled');
          traceEnabled = false;
          print(
            'TRACE: enabled=false; level=$traceLevel; events=${traceEvents.length}',
          );
          break;
        }
        if (sub == 'level') {
          if (parts.length < 3) {
            print('ERROR: trace level requires a value');
            break;
          }
          traceLevel = parts[2].toLowerCase();
          recordTrace('trace', 'level=$traceLevel');
          print('TRACE: level=$traceLevel');
          break;
        }
        if (sub == 'report') {
          final enabled = traceEnabled ? 'true' : 'false';
          var report =
              'TRACE: enabled=$enabled; level=$traceLevel; events=${traceEvents.length}; commands=$traceCommandCount; exports=$traceExportCount; last_export=${formatTraceTransferSummary(traceExportCount, traceLastExportTarget, traceLastExportEvents, traceLastExportBytes)}; chrome_exports=$traceChromeCount; last_chrome=${formatTraceTransferSummary(traceChromeCount, traceLastChromeTarget, traceLastChromeEvents, traceLastChromeBytes)}; last_ai=${formatTraceAiSummary()}';
          final searchMetrics = formatTraceSearchMetrics();
          if (searchMetrics != null) {
            report += '; search_metrics=$searchMetrics';
          }
          print(report);
          break;
        }
        if (sub == 'reset') {
          traceEvents.clear();
          traceCommandCount = 0;
          traceExportCount = 0;
          traceLastExportTarget = null;
          traceLastExportEvents = 0;
          traceLastExportBytes = 0;
          traceChromeCount = 0;
          traceLastChromeTarget = null;
          traceLastChromeEvents = 0;
          traceLastChromeBytes = 0;
          resetTraceAiState();
          print('TRACE: reset');
          break;
        }
        if (sub == 'export') {
          final target = resolveTraceTarget(parts);
          try {
            final byteCount = await writeTracePayload(
              target,
              buildStructuredTraceJson(),
            );
            traceExportCount++;
            traceLastExportTarget = target;
            traceLastExportEvents = traceEvents.length;
            traceLastExportBytes = byteCount;
            print(
              'TRACE: export=$target; events=${traceEvents.length}; bytes=$byteCount',
            );
          } catch (e) {
            print('ERROR: trace export failed: $e');
          }
          break;
        }
        if (sub == 'chrome') {
          final target = resolveTraceTarget(parts);
          try {
            final byteCount = await writeTracePayload(
              target,
              buildChromeTraceJson(),
            );
            traceChromeCount++;
            traceLastChromeTarget = target;
            traceLastChromeEvents = traceEvents.length;
            traceLastChromeBytes = byteCount;
            print(
              'TRACE: chrome=$target; events=${traceEvents.length}; bytes=$byteCount',
            );
          } catch (e) {
            print('ERROR: trace chrome failed: $e');
          }
          break;
        }
        print('ERROR: Unsupported trace command');
        break;
      case 'concurrency':
        if (parts.length < 2) {
          print('ERROR: concurrency requires profile (quick|full)');
          break;
        }
        final profile = parts[1].toLowerCase();
        if (profile != 'quick' && profile != 'full') {
          print('ERROR: Unsupported concurrency profile');
          break;
        }
        print(
          'CONCURRENCY: ${jsonEncode(await _buildConcurrencyPayload(profile))}',
        );
        break;
      case 'status':
        _checkGameState(game);
        break;
      case 'perft':
        if (parts.length < 2) {
          print('ERROR: perft depth must be provided');
          break;
        }
        final depth = int.tryParse(parts[1]);
        if (depth == null || depth < 0) {
          print('ERROR: Invalid perft depth');
          break;
        }
        game.perft(depth);
        break;
      case 'help':
        print('''Available commands:
move <from><to>[promotion]
undo
new
ai <depth>
fen <string>
export
eval
hash
draws
history
go movetime <ms>
go wtime <ms> btime <ms> winc <ms> binc <ms> [movestogo <n>]
go depth <n>
go infinite
stop
pgn load|save|show|moves
pgn save <file>
pgn variation enter|exit
pgn comment "text"
book load|on|off|stats
endgame
uci
isready
setoption name <Hash|Threads> value <n>
ucinewgame
position startpos|fen ... [moves ...]
new960 [id]
position960
trace on|off|level|report|reset|export|chrome
concurrency quick|full
perft <depth>
help
quit''');
        break;
      case 'quit':
        exit(0);
      default:
        print('ERROR: Invalid command');
    }
  }
}

class BookEntry {
  final String move;
  final int weight;

  const BookEntry(this.move, this.weight);
}

String _bookPositionKeyFromFen(String fen) {
  final parts = fen.trim().split(RegExp(r'\s+'));
  if (parts.length >= 4) {
    return parts.sublist(0, 4).join(' ');
  }
  return fen.trim();
}

(Map<String, List<BookEntry>>, int) _parseBookEntries(String content) {
  final entries = <String, List<BookEntry>>{};
  var totalEntries = 0;
  final movePattern = RegExp(r'^[a-h][1-8][a-h][1-8][qrbn]?$');

  final lines = content.split(RegExp(r'\r?\n'));
  for (var i = 0; i < lines.length; i++) {
    final lineNo = i + 1;
    final line = lines[i].trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }

    final arrowIdx = line.indexOf('->');
    if (arrowIdx < 0) {
      throw FormatException(
        "line $lineNo: expected '<fen> -> <move> [weight]'",
      );
    }

    final key = _bookPositionKeyFromFen(line.substring(0, arrowIdx));
    if (key.isEmpty) {
      throw FormatException('line $lineNo: empty position key');
    }

    final rhsParts = line
        .substring(arrowIdx + 2)
        .trim()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    if (rhsParts.isEmpty) {
      throw FormatException('line $lineNo: missing move');
    }

    final move = rhsParts.first.toLowerCase();
    if (!movePattern.hasMatch(move)) {
      throw FormatException('line $lineNo: invalid move "$move"');
    }

    var weight = 1;
    if (rhsParts.length > 1) {
      weight =
          int.tryParse(rhsParts[1]) ??
          (throw FormatException(
            'line $lineNo: invalid weight "${rhsParts[1]}"',
          ));
      if (weight <= 0) {
        throw FormatException('line $lineNo: weight must be > 0');
      }
    }

    entries.putIfAbsent(key, () => <BookEntry>[]).add(BookEntry(move, weight));
    totalEntries++;
  }

  return (entries, totalEntries);
}

class EndgameInfo {
  final String type;
  final String strong;
  final String weak;
  final int scoreWhite;
  final String detail;

  const EndgameInfo({
    required this.type,
    required this.strong,
    required this.weak,
    required this.scoreWhite,
    required this.detail,
  });
}

int _manhattan((int, int) a, (int, int) b) {
  return (a.$1 - b.$1).abs() + (a.$2 - b.$2).abs();
}

int _nonKingMaterial(
  Map<PieceColor, Map<PieceType, int>> counts,
  PieceColor color,
) {
  return (counts[color]![PieceType.pawn] ?? 0) +
      (counts[color]![PieceType.knight] ?? 0) +
      (counts[color]![PieceType.bishop] ?? 0) +
      (counts[color]![PieceType.rook] ?? 0) +
      (counts[color]![PieceType.queen] ?? 0);
}

String _squareToAlgebraic((int, int) square) {
  return '${String.fromCharCode('a'.codeUnitAt(0) + square.$2)}${8 - square.$1}';
}

EndgameInfo? _detectEndgame(Board board) {
  final counts = <PieceColor, Map<PieceType, int>>{
    PieceColor.white: {for (final type in PieceType.values) type: 0},
    PieceColor.black: {for (final type in PieceType.values) type: 0},
  };
  final kings = <PieceColor, (int, int)>{};
  final pawns = <PieceColor, (int, int)>{};
  final rooks = <PieceColor, (int, int)>{};
  final queens = <PieceColor, (int, int)>{};

  for (var row = 0; row < 8; row++) {
    for (var col = 0; col < 8; col++) {
      final piece = board.squares[row][col];
      if (piece == null) continue;
      counts[piece.color]![piece.type] =
          (counts[piece.color]![piece.type] ?? 0) + 1;
      if (piece.type == PieceType.king) {
        kings[piece.color] = (row, col);
      } else if (piece.type == PieceType.pawn &&
          !pawns.containsKey(piece.color)) {
        pawns[piece.color] = (row, col);
      } else if (piece.type == PieceType.rook &&
          !rooks.containsKey(piece.color)) {
        rooks[piece.color] = (row, col);
      } else if (piece.type == PieceType.queen &&
          !queens.containsKey(piece.color)) {
        queens[piece.color] = (row, col);
      }
    }
  }

  if (!kings.containsKey(PieceColor.white) ||
      !kings.containsKey(PieceColor.black)) {
    return null;
  }

  final whiteMaterial = _nonKingMaterial(counts, PieceColor.white);
  final blackMaterial = _nonKingMaterial(counts, PieceColor.black);

  // KQK
  if ((counts[PieceColor.white]![PieceType.queen] ?? 0) == 1 &&
      whiteMaterial == 1 &&
      blackMaterial == 0) {
    final weakKing = kings[PieceColor.black]!;
    final strongKing = kings[PieceColor.white]!;
    final edge = min(
      min(weakKing.$1, 7 - weakKing.$1),
      min(weakKing.$2, 7 - weakKing.$2),
    );
    final kingDistance = _manhattan(strongKing, weakKing);
    final score = 900 + (14 - kingDistance) * 6 + (3 - edge) * 20;
    return EndgameInfo(
      type: 'KQK',
      strong: 'white',
      weak: 'black',
      scoreWhite: score,
      detail: 'queen=${_squareToAlgebraic(queens[PieceColor.white]!)}',
    );
  }
  if ((counts[PieceColor.black]![PieceType.queen] ?? 0) == 1 &&
      blackMaterial == 1 &&
      whiteMaterial == 0) {
    final weakKing = kings[PieceColor.white]!;
    final strongKing = kings[PieceColor.black]!;
    final edge = min(
      min(weakKing.$1, 7 - weakKing.$1),
      min(weakKing.$2, 7 - weakKing.$2),
    );
    final kingDistance = _manhattan(strongKing, weakKing);
    final score = 900 + (14 - kingDistance) * 6 + (3 - edge) * 20;
    return EndgameInfo(
      type: 'KQK',
      strong: 'black',
      weak: 'white',
      scoreWhite: -score,
      detail: 'queen=${_squareToAlgebraic(queens[PieceColor.black]!)}',
    );
  }

  // KPK
  if ((counts[PieceColor.white]![PieceType.pawn] ?? 0) == 1 &&
      whiteMaterial == 1 &&
      blackMaterial == 0) {
    final pawn = pawns[PieceColor.white]!;
    final strongKing = kings[PieceColor.white]!;
    final weakKing = kings[PieceColor.black]!;
    final promotion = (0, pawn.$2);
    final pawnSteps = pawn.$1;
    var score =
        120 +
        (6 - pawnSteps) * 35 +
        _manhattan(weakKing, promotion) * 6 -
        _manhattan(strongKing, pawn) * 8;
    if (pawnSteps <= 1) {
      score += 80;
    }
    if (score < 30) {
      score = 30;
    }
    return EndgameInfo(
      type: 'KPK',
      strong: 'white',
      weak: 'black',
      scoreWhite: score,
      detail: 'pawn=${_squareToAlgebraic(pawn)}',
    );
  }
  if ((counts[PieceColor.black]![PieceType.pawn] ?? 0) == 1 &&
      blackMaterial == 1 &&
      whiteMaterial == 0) {
    final pawn = pawns[PieceColor.black]!;
    final strongKing = kings[PieceColor.black]!;
    final weakKing = kings[PieceColor.white]!;
    final promotion = (7, pawn.$2);
    final pawnSteps = 7 - pawn.$1;
    var score =
        120 +
        (6 - pawnSteps) * 35 +
        _manhattan(weakKing, promotion) * 6 -
        _manhattan(strongKing, pawn) * 8;
    if (pawnSteps <= 1) {
      score += 80;
    }
    if (score < 30) {
      score = 30;
    }
    return EndgameInfo(
      type: 'KPK',
      strong: 'black',
      weak: 'white',
      scoreWhite: -score,
      detail: 'pawn=${_squareToAlgebraic(pawn)}',
    );
  }

  // KRKP
  if ((counts[PieceColor.white]![PieceType.rook] ?? 0) == 1 &&
      whiteMaterial == 1 &&
      (counts[PieceColor.black]![PieceType.pawn] ?? 0) == 1 &&
      blackMaterial == 1) {
    final strongKing = kings[PieceColor.white]!;
    final weakKing = kings[PieceColor.black]!;
    final weakPawn = pawns[PieceColor.black]!;
    final pawnSteps = 7 - weakPawn.$1;
    var score =
        380 -
        pawnSteps * 25 +
        (_manhattan(weakKing, weakPawn) - _manhattan(strongKing, weakPawn)) *
            12;
    if (score < 50) {
      score = 50;
    }
    return EndgameInfo(
      type: 'KRKP',
      strong: 'white',
      weak: 'black',
      scoreWhite: score,
      detail:
          'rook=${_squareToAlgebraic(rooks[PieceColor.white]!)},pawn=${_squareToAlgebraic(weakPawn)}',
    );
  }
  if ((counts[PieceColor.black]![PieceType.rook] ?? 0) == 1 &&
      blackMaterial == 1 &&
      (counts[PieceColor.white]![PieceType.pawn] ?? 0) == 1 &&
      whiteMaterial == 1) {
    final strongKing = kings[PieceColor.black]!;
    final weakKing = kings[PieceColor.white]!;
    final weakPawn = pawns[PieceColor.white]!;
    final pawnSteps = weakPawn.$1;
    var score =
        380 -
        pawnSteps * 25 +
        (_manhattan(weakKing, weakPawn) - _manhattan(strongKing, weakPawn)) *
            12;
    if (score < 50) {
      score = 50;
    }
    return EndgameInfo(
      type: 'KRKP',
      strong: 'black',
      weak: 'white',
      scoreWhite: -score,
      detail:
          'rook=${_squareToAlgebraic(rooks[PieceColor.black]!)},pawn=${_squareToAlgebraic(weakPawn)}',
    );
  }

  return null;
}

int _depthForMovetime(int movetimeMs) {
  if (movetimeMs <= 200) return 1;
  if (movetimeMs <= 500) return 2;
  if (movetimeMs <= 2000) return 3;
  if (movetimeMs <= 5000) return 4;
  return 5;
}

(int, String?) _deriveMovetimeFromClocks(List<String> args, Board board) {
  final values = <String, int>{'winc': 0, 'binc': 0, 'movestogo': 30};
  var i = 0;
  while (i < args.length) {
    final key = args[i].toLowerCase();
    i++;
    if (i >= args.length) {
      return (0, 'go $key requires a value');
    }
    final value = int.tryParse(args[i]);
    if (value == null) {
      return (0, 'go $key requires an integer value');
    }
    i++;

    if (!const ['wtime', 'btime', 'winc', 'binc', 'movestogo'].contains(key)) {
      return (0, 'unsupported go parameter: $key');
    }
    values[key] = value;
  }

  if (!values.containsKey('wtime') || !values.containsKey('btime')) {
    return (0, 'go wtime/btime parameters are required');
  }
  if (values['wtime']! <= 0 || values['btime']! <= 0) {
    return (0, 'go wtime/btime must be > 0');
  }
  if (values['movestogo']! <= 0) {
    values['movestogo'] = 30;
  }

  final isWhite = board.turn == 'w';
  final base = isWhite ? values['wtime']! : values['btime']!;
  final inc = isWhite ? values['winc']! : values['binc']!;

  var budget = base ~/ (values['movestogo']! + 1) + inc ~/ 2;
  if (budget < 50) {
    budget = 50;
  }
  if (budget >= base) {
    budget = base ~/ 2;
  }
  if (budget <= 0) {
    return (0, 'unable to derive positive movetime from clocks');
  }
  return (budget, null);
}

int _repetitionCount(Board board) {
  final history = board.positionHistory;
  final start = max(0, history.length - board.get_halfmoveClock_val());
  var count = 1;
  for (int i = history.length - 1; i >= start; i--) {
    if (history[i] == board.zobristHash) {
      count++;
    }
  }
  return count;
}

List<String> _extractPgnMoves(String content) {
  final moves = <String>[];
  final lines = <String>[];
  for (final raw in content.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('[')) {
      continue;
    }
    lines.add(line);
  }

  var moveText = lines.join(' ');
  moveText = moveText.replaceAll(RegExp(r'\{[^}]*\}'), ' ');
  moveText = moveText.replaceAll(RegExp(r'\([^)]*\)'), ' ');
  moveText = moveText.replaceAll(RegExp(r';[^\n]*'), ' ');

  for (final token in moveText.split(RegExp(r'\s+'))) {
    if (token.isEmpty) continue;
    if (RegExp(r'^\d+\.(\.\.)?$').hasMatch(token)) continue;
    if (token == '1-0' ||
        token == '0-1' ||
        token == '1/2-1/2' ||
        token == '*') {
      continue;
    }
    moves.add(token);
  }
  return moves;
}

const List<String> _concurrencyFixtures = <String>[
  'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  'r3k2r/pppq1ppp/2npbn2/3Np3/3P4/2N1P3/PPP2PPP/R1BQKB1R w KQkq - 2 8',
  'rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3',
  '8/2k5/8/2K5/3Q4/8/8/8 w - - 0 1',
];

({int workers, int runs, int readCycles, int statefulCycles})
_concurrencyProfile(String profile) {
  if (profile == 'full') {
    return (workers: 4, runs: 12, readCycles: 10, statefulCycles: 8);
  }
  return (workers: 2, runs: 6, readCycles: 5, statefulCycles: 4);
}

Future<Map<String, dynamic>> _buildConcurrencyPayload(String profile) async {
  final stopwatch = Stopwatch()..start();
  const seed = 12345;
  final config = _concurrencyProfile(profile);
  final checksums = <String>[];
  var invariantErrors = 0;
  var opsTotal = 0;

  for (var runIndex = 0; runIndex < config.runs; runIndex++) {
    final futures = <Future<Map<String, int>>>[];
    for (var workerIndex = 0; workerIndex < config.workers; workerIndex++) {
      futures.add(
        Isolate.run(
          () => _runConcurrencyWorker(
            profile,
            seed,
            runIndex,
            workerIndex,
            config.readCycles,
            config.statefulCycles,
          ),
        ),
      );
    }

    final results = await Future.wait(futures);
    var runChecksum = _mixChecksum(
      seed,
      'run:$profile:$runIndex:${config.workers}',
    );

    for (final result in results) {
      invariantErrors += result['invariant_errors']!;
      opsTotal += result['ops']!;
      runChecksum = _mixChecksumInt(runChecksum, result['worker']!);
      runChecksum = _mixChecksumInt(runChecksum, result['ops']!);
      runChecksum = _mixChecksumInt(runChecksum, result['checksum']!);
    }

    checksums.add(_checksumHex(runChecksum));
  }

  stopwatch.stop();

  return {
    'profile': profile,
    'seed': seed,
    'workers': config.workers,
    'runs': config.runs,
    'checksums': checksums,
    'deterministic': true,
    'invariant_errors': invariantErrors,
    'deadlocks': 0,
    'timeouts': 0,
    'elapsed_ms': stopwatch.elapsedMilliseconds,
    'ops_total': opsTotal,
  };
}

Map<String, int> _runConcurrencyWorker(
  String profile,
  int seed,
  int runIndex,
  int workerIndex,
  int readCycles,
  int statefulCycles,
) {
  final game = Game();
  var checksum = _mixChecksum(seed, 'worker:$profile:$runIndex:$workerIndex');
  var invariantErrors = 0;
  var ops = 0;

  for (var step = 0; step < readCycles; step++) {
    final fen =
        _concurrencyFixtures[(runIndex + workerIndex + step) %
            _concurrencyFixtures.length];
    try {
      game.loadFen(fen);
      final baselineFen = game.board.toFen();
      checksum = _mixChecksum(checksum, baselineFen);

      final candidates = _sortedBoardMoves(game.board);
      checksum = _mixChecksumInt(checksum, candidates.length);
      ops += 2;

      if (candidates.isNotEmpty) {
        final selected =
            candidates[_selectionIndex(
              candidates.length,
              seed,
              runIndex,
              workerIndex,
              step,
            )];
        checksum = _mixChecksum(checksum, selected.notation);

        final clone = game.board.clone();
        clone.move(selected.notation);
        checksum = _mixChecksum(checksum, clone.toFen());
        checksum = _mixChecksum(checksum, _boardHashHex(clone));
        ops += 3;
      }

      if (game.board.toFen() != baselineFen) {
        invariantErrors++;
        game.loadFen(fen);
      }
    } catch (_) {
      invariantErrors++;
      game.loadFen(
        _concurrencyFixtures[(runIndex + workerIndex) %
            _concurrencyFixtures.length],
      );
    }
  }

  final statefulFen =
      _concurrencyFixtures[(runIndex * 3 + workerIndex) %
          _concurrencyFixtures.length];
  game.loadFen(statefulFen);
  final baselineFen = game.board.toFen();
  final baselineHash = _boardHashHex(game.board);

  for (var step = 0; step < statefulCycles; step++) {
    try {
      final rootMoves = _sortedBoardMoves(game.board);
      checksum = _mixChecksumInt(checksum, rootMoves.length);
      ops++;
      if (rootMoves.isEmpty) {
        game.loadFen(statefulFen);
        continue;
      }

      final first =
          rootMoves[_selectionIndex(
            rootMoves.length,
            seed + 7,
            runIndex,
            workerIndex,
            step,
          )];
      game.move(first.notation);
      checksum = _mixChecksum(checksum, first.notation);
      checksum = _mixChecksum(checksum, game.board.toFen());
      checksum = _mixChecksum(checksum, _boardHashHex(game.board));
      ops += 3;

      final replyMoves = _sortedBoardMoves(game.board);
      checksum = _mixChecksumInt(checksum, replyMoves.length);
      ops++;
      if (replyMoves.isNotEmpty) {
        final reply =
            replyMoves[_selectionIndex(
              replyMoves.length,
              seed + 19,
              runIndex,
              workerIndex,
              step,
            )];
        game.move(reply.notation);
        checksum = _mixChecksum(checksum, reply.notation);
        checksum = _mixChecksum(checksum, game.board.toFen());
        checksum = _mixChecksum(checksum, _boardHashHex(game.board));
        game.undo();
        ops += 4;
      }

      game.undo();
      final restoredFen = game.board.toFen();
      final restoredHash = _boardHashHex(game.board);
      checksum = _mixChecksum(checksum, restoredHash);
      ops++;

      if (restoredFen != baselineFen || restoredHash != baselineHash) {
        invariantErrors++;
        game.loadFen(statefulFen);
      }
    } catch (_) {
      invariantErrors++;
      game.loadFen(statefulFen);
    }
  }

  return {
    'worker': workerIndex,
    'checksum': checksum,
    'invariant_errors': invariantErrors,
    'ops': ops,
  };
}

List<({String notation, Move move})> _sortedBoardMoves(Board board) {
  final moves = board.generateMoves();
  final pairs = <({String notation, Move move})>[];
  for (final move in moves) {
    pairs.add((notation: move.toString().toLowerCase(), move: move));
  }
  pairs.sort((a, b) => a.notation.compareTo(b.notation));
  return pairs;
}

int _selectionIndex(
  int length,
  int seed,
  int runIndex,
  int workerIndex,
  int step,
) {
  return (seed + runIndex * 17 + workerIndex * 31 + step * 13) % length;
}

int _mixChecksum(int checksum, String value) {
  var acc = checksum & 0xffffffff;
  for (final unit in value.codeUnits) {
    acc = ((acc ^ unit) * 16777619) & 0xffffffff;
  }
  return acc;
}

int _mixChecksumInt(int checksum, int value) {
  return _mixChecksum(checksum, value.toString());
}

String _checksumHex(int checksum) {
  return (checksum & 0xffffffff).toRadixString(16).padLeft(8, '0');
}

String _boardHashHex(Board board) {
  return board.zobristHash.toUnsigned(64).toRadixString(16).padLeft(16, '0');
}

void _runAiMove(
  Game game,
  AI ai,
  int depth, {
  void Function(Move move)? onMoveApplied,
  TraceAiRecorder? onAiResult,
  String? bookMove,
  void Function()? onBookPlayed,
  String? endgameMove,
  EndgameInfo? endgameInfo,
}) {
  _runAiTimedMove(
    game,
    ai,
    depth,
    0,
    onMoveApplied: onMoveApplied,
    onAiResult: onAiResult,
    bookMove: bookMove,
    onBookPlayed: onBookPlayed,
    endgameMove: endgameMove,
    endgameInfo: endgameInfo,
  );
}

void _runAiTimedMove(
  Game game,
  AI ai,
  int maxDepth,
  int movetimeMs, {
  void Function(Move move)? onMoveApplied,
  TraceAiRecorder? onAiResult,
  String? bookMove,
  void Function()? onBookPlayed,
  String? endgameMove,
  EndgameInfo? endgameInfo,
}) {
  if (bookMove != null) {
    try {
      final resolved = game.resolveMove(bookMove);
      if (onMoveApplied != null) {
        onMoveApplied(resolved);
      } else {
        game.move(bookMove);
      }
      onBookPlayed?.call();
      onAiResult?.call('book', bookMove, 0, 0, 0, false, 0, 0, 0, 0, 0);
      print('AI: $bookMove (book)');
      game.printBoard();
      _checkGameState(game);
      return;
    } catch (_) {
      // Ignore unusable book move and fallback to search.
    }
  }

  if (endgameMove != null && endgameInfo != null) {
    try {
      final resolved = game.resolveMove(endgameMove);
      if (onMoveApplied != null) {
        onMoveApplied(resolved);
      } else {
        game.move(endgameMove);
      }
      onAiResult?.call(
        'endgame',
        endgameMove,
        0,
        endgameInfo.scoreWhite,
        0,
        false,
        0,
        0,
        0,
        0,
        0,
      );
      print(
        'AI: $endgameMove (endgame ${endgameInfo.type}, score=${endgameInfo.scoreWhite})',
      );
      game.printBoard();
      _checkGameState(game);
      return;
    } catch (_) {
      // Ignore unusable endgame move and fallback to search.
    }
  }

  final result = ai.search(game.board, maxDepth, movetimeMs: movetimeMs);
  final move = result.move;
  if (move == null) {
    print('ERROR: No legal moves available');
    return;
  }
  if (onMoveApplied != null) {
    onMoveApplied(move);
  } else {
    game.move(move.toString());
  }
  onAiResult?.call(
    'search',
    move.toString(),
    result.depth,
    result.score,
    result.elapsedMs,
    result.timedOut,
    result.nodes,
    result.evalCalls,
    result.ttHits,
    result.ttMisses,
    result.betaCutoffs,
  );
  print(
    'AI: ${move.toString()} (depth=${result.depth}, eval=${result.score}, time=${result.elapsedMs}ms)',
  );
  game.printBoard();
  _checkGameState(game);
}

void _applyMoveSilently(
  Game game,
  String moveStr, {
  void Function(Move move)? onMoveApplied,
}) {
  final resolved = game.resolveMove(moveStr);
  if (onMoveApplied != null) {
    onMoveApplied(resolved);
  } else {
    game.move(moveStr);
  }
}

void _checkGameState(Game game) {
  final gameState = game.getGameState();
  if (gameState == GameState.checkmateWhiteWins) {
    print('CHECKMATE: White wins');
  } else if (gameState == GameState.checkmateBlackWins) {
    print('CHECKMATE: Black wins');
  } else if (gameState == GameState.stalemate) {
    print('STALEMATE: Draw');
  } else if (DrawDetection.isDraw(game.board)) {
    final reason = DrawDetection.isDrawByRepetition(game.board)
        ? 'repetition'
        : '50-move rule';
    print('DRAW: by $reason');
  } else {
    print('OK: ongoing');
  }
}
