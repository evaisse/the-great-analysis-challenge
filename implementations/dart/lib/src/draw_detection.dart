import 'board.dart';
import 'dart:math';

class DrawDetection {
  static bool isDrawByRepetition(Board board) {
    final currentHash = board.zobristHash;
    int count = 1;
    
    final history = board.positionHistory;
    final halfmoveClock = board.get_halfmoveClock_val();
    
    final startIdx = max(0, history.length - halfmoveClock);
    
    for (int i = history.length - 1; i >= startIdx; i--) {
      if (history[i] == currentHash) {
        count++;
        if (count >= 3) {
          return true;
        }
      }
    }
    
    return false;
  }

  static bool isDrawByFiftyMoves(Board board) {
    return board.get_halfmoveClock_val() >= 100;
  }

  static bool isDraw(Board board) {
    return isDrawByRepetition(board) || isDrawByFiftyMoves(board);
  }
}
