import 'dart:io';
import 'package:chess_engine/chess_engine.dart';

void main() {
  final game = Game();
  final ai = AI();
  while (true) {
    final line = stdin.readLineSync();
    if (line == null) {
      break;
    }
    final parts = line.split(' ');
    final command = parts[0];
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
        final move = ai.findBestMove(game.board, depth);
        game.move(move.toString());
        game.printBoard();
        _checkGameState(game);
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
          'Hash: ${game.board.zobristHash.toUnsigned(64).toRadixString(16).padLeft(16, '0')}',
        );
        break;
      case 'draws':
        final repetition = DrawDetection.isDrawByRepetition(game.board);
        final fiftyMoves = DrawDetection.isDrawByFiftyMoves(game.board);
        print(
          'Repetition: $repetition, 50-move rule: $fiftyMoves, 50-move clock: ${game.board.get_halfmoveClock_val()}',
        );
        break;
      case 'history':
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
