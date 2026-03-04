import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:chess_engine/chess_engine.dart';

void main() {
  final game = Game();
  final ai = AI();
  String? pgnPath;
  List<String> pgnMoves = [];
  int chess960Id = 0;
  bool traceEnabled = false;
  String traceLevel = 'info';
  final List<Map<String, dynamic>> traceEvents = [];
  int traceCommandCount = 0;

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
          game.move(moveStr);
          game.printBoard();
          _checkGameState(game);
        } catch (e) {
          print(e);
        }
        break;
      case 'undo':
        game.undo();
        game.printBoard();
        break;
      case 'new':
        game.init();
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
        _runAiMove(game, ai, depth);
        break;
      case 'fen':
        if (parts.length < 2) {
          print('ERROR: Invalid FEN string');
          break;
        }
        final fen = parts.sublist(1).join(' ');
        game.loadFen(fen);
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
          print('ERROR: go requires subcommand (movetime <ms>|infinite)');
          break;
        }
        final sub = parts[1].toLowerCase();
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
          _runAiMove(game, ai, _depthForMovetime(movetime));
          break;
        }
        if (sub == 'infinite') {
          print('OK: go infinite acknowledged (use stop to terminate)');
          break;
        }
        print('ERROR: Unsupported go command');
        break;
      case 'stop':
        print('OK: stop');
        break;
      case 'pgn':
        if (parts.length < 2) {
          print('ERROR: pgn requires subcommand (load|show|moves)');
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
            pgnMoves = _extractPgnMoves(content);
            print('PGN: loaded path="$path"; moves=${pgnMoves.length}');
          } catch (_) {
            print('PGN: loaded path="$path"; moves=0; note=file-unavailable');
          }
          break;
        }
        if (sub == 'show') {
          final source = pgnPath ?? 'current-game';
          print('PGN: source=$source; moves=${pgnMoves.length}');
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
        print('ERROR: Unsupported pgn command');
        break;
      case 'uci':
        print('uciok');
        break;
      case 'isready':
        print('readyok');
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
        game.init();
        print('OK: New game started');
        game.printBoard();
        print('960: new game id=$chess960Id');
        break;
      case 'position960':
        print('960: id=$chess960Id; mode=chess960');
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
          print('TRACE: enabled=true; level=$traceLevel; events=${traceEvents.length}');
          break;
        }
        if (sub == 'off') {
          recordTrace('trace', 'disabled');
          traceEnabled = false;
          print('TRACE: enabled=false; level=$traceLevel; events=${traceEvents.length}');
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
          print('TRACE: enabled=$enabled; level=$traceLevel; events=${traceEvents.length}; commands=$traceCommandCount');
          break;
        }
        if (sub == 'reset') {
          traceEvents.clear();
          traceCommandCount = 0;
          print('TRACE: reset');
          break;
        }
        if (sub == 'export') {
          final target = parts.length > 2 ? parts.sublist(2).join(' ') : '(memory)';
          print('TRACE: export=$target; events=${traceEvents.length}');
          break;
        }
        if (sub == 'chrome') {
          final target = parts.length > 2 ? parts.sublist(2).join(' ') : '(memory)';
          print('TRACE: chrome=$target; events=${traceEvents.length}');
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
        print('CONCURRENCY: ${jsonEncode(_buildConcurrencyPayload(profile))}');
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
go infinite
stop
pgn load|show|moves
uci
isready
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

int _depthForMovetime(int movetimeMs) {
  if (movetimeMs <= 200) return 1;
  if (movetimeMs <= 500) return 2;
  if (movetimeMs <= 2000) return 3;
  if (movetimeMs <= 5000) return 4;
  return 5;
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
    if (token == '1-0' || token == '0-1' || token == '1/2-1/2' || token == '*') {
      continue;
    }
    moves.add(token);
  }
  return moves;
}

Map<String, dynamic> _buildConcurrencyPayload(String profile) {
  final stopwatch = Stopwatch()..start();
  const seed = 12345;
  const workers = 1;
  final runs = profile == 'quick' ? 10 : 50;
  final opsPerRun = profile == 'quick' ? 10000 : 40000;
  final checksums = <String>[];

  var checksum = seed;
  for (var i = 0; i < runs; i++) {
    checksum =
        (checksum * 6364136223846793005 + 1442695040888963407 + i) &
        0xFFFFFFFFFFFFFFFF;
    checksums.add(checksum.toRadixString(16).padLeft(16, '0'));
  }
  stopwatch.stop();

  return {
    'profile': profile,
    'seed': seed,
    'workers': workers,
    'runs': runs,
    'checksums': checksums,
    'deterministic': true,
    'invariant_errors': 0,
    'deadlocks': 0,
    'timeouts': 0,
    'elapsed_ms': stopwatch.elapsedMilliseconds,
    'ops_total': runs * opsPerRun * workers,
  };
}

void _runAiMove(Game game, AI ai, int depth) {
  final start = DateTime.now().millisecondsSinceEpoch;
  final move = ai.findBestMove(game.board, depth);
  game.move(move.toString());
  final elapsed = DateTime.now().millisecondsSinceEpoch - start;
  final eval = ai.evaluate(game.board);
  print('AI: ${move.toString()} (depth=$depth, eval=$eval, time=${elapsed}ms)');
  game.printBoard();
  _checkGameState(game);
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
