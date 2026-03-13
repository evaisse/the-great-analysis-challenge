import 'dart:math';
import 'package:chess_engine/chess_engine.dart';

const int _mateValue = 100000;
const int _infinity = 1000000000;

class _TTEntry {
  final int depth;
  final int score;
  final String flag; // exact | lower | upper
  final String? bestMoveKey;

  _TTEntry(this.depth, this.score, this.flag, this.bestMoveKey);
}

class SearchResult {
  final Move? move;
  final int score;
  final int depth;
  final int elapsedMs;
  final bool timedOut;
  final int nodes;
  final int evalCalls;

  SearchResult(
    this.move,
    this.score,
    this.depth,
    this.elapsedMs,
    this.timedOut,
    this.nodes,
    this.evalCalls,
  );
}

class _NodeResult {
  final int score;
  final String? bestMoveKey;
  final bool complete;

  _NodeResult(this.score, this.bestMoveKey, this.complete);
}

class AI {
  static const _materialValues = {
    PieceType.pawn: 100,
    PieceType.knight: 320,
    PieceType.bishop: 330,
    PieceType.rook: 500,
    PieceType.queen: 900,
    PieceType.king: 20000,
  };

  final Map<int, _TTEntry> _tt = <int, _TTEntry>{};
  DateTime? _deadline;
  bool _timedOut = false;
  bool _stopRequested = false;
  int _nodesVisited = 0;
  int _evalCalls = 0;

  Move findBestMove(Board board, int depth) {
    final result = search(board, depth);
    if (result.move == null) {
      throw Exception('ERROR: No legal moves available');
    }
    return result.move!;
  }

  void requestStop() {
    _stopRequested = true;
  }

  SearchResult search(Board board, int maxDepth, {int movetimeMs = 0}) {
    var boundedDepth = maxDepth;
    if (boundedDepth < 1) boundedDepth = 1;
    if (boundedDepth > 5) boundedDepth = 5;

    final legalMoves = board.generateMoves();
    if (legalMoves.isEmpty) {
      return SearchResult(null, 0, 0, 0, false, 0, 0);
    }

    _timedOut = false;
    _stopRequested = false;
    _nodesVisited = 0;
    _evalCalls = 0;
    final started = DateTime.now();
    _deadline = movetimeMs > 0
        ? started.add(Duration(milliseconds: movetimeMs))
        : null;

    Move bestMove = legalMoves.first;
    var bestScore = evaluate(board);
    var completedDepth = 0;

    for (var depth = 1; depth <= boundedDepth; depth++) {
      final root = _searchRoot(board, depth);
      if (!root.complete) {
        break;
      }
      final move = _findMoveByKey(legalMoves, root.bestMoveKey);
      if (move != null) {
        bestMove = move;
        bestScore = root.score;
        completedDepth = depth;
      }
    }

    if (completedDepth == 0) {
      completedDepth = 1;
    }

    final elapsedMs = DateTime.now().difference(started).inMilliseconds;
    return SearchResult(
      bestMove,
      bestScore,
      completedDepth,
      elapsedMs,
      _timedOut,
      _nodesVisited,
      _evalCalls,
    );
  }

  _NodeResult _searchRoot(Board board, int depth) {
    if (_timeExceeded()) {
      return _NodeResult(0, null, false);
    }
    _nodesVisited++;

    final moves = board.generateMoves();
    if (moves.isEmpty) {
      return _NodeResult(0, null, true);
    }

    final entry = _tt[board.zobristHash];
    final orderedMoves = _orderMoves(board, moves, entry?.bestMoveKey);

    var alpha = -_infinity;
    const beta = _infinity;
    var bestScore = -_infinity;
    var bestMoveKey = _moveKey(orderedMoves.first);

    for (final move in orderedMoves) {
      if (_timeExceeded()) {
        return _NodeResult(0, null, false);
      }

      final child = board.clone();
      child.move(move.toString());
      final node = _negamax(child, depth - 1, -beta, -alpha);
      if (!node.complete) {
        return _NodeResult(0, null, false);
      }
      final score = -node.score;

      if (score > bestScore) {
        bestScore = score;
        bestMoveKey = _moveKey(move);
      }
      if (score > alpha) {
        alpha = score;
      }
    }

    return _NodeResult(bestScore, bestMoveKey, true);
  }

  _NodeResult _negamax(Board board, int depth, int alpha, int beta) {
    if (_timeExceeded()) {
      return _NodeResult(0, null, false);
    }
    _nodesVisited++;

    final originalAlpha = alpha;
    final key = board.zobristHash;
    String? bestFromTt;

    final entry = _tt[key];
    if (entry != null && entry.depth >= depth) {
      if (entry.flag == 'exact') {
        return _NodeResult(entry.score, entry.bestMoveKey, true);
      }
      if (entry.flag == 'lower') {
        alpha = max(alpha, entry.score);
      } else if (entry.flag == 'upper') {
        beta = min(beta, entry.score);
      }
      if (alpha >= beta) {
        return _NodeResult(entry.score, entry.bestMoveKey, true);
      }
      bestFromTt = entry.bestMoveKey;
    }

    if (depth == 0) {
      return _NodeResult(evaluate(board), null, true);
    }

    final moves = board.generateMoves();
    if (moves.isEmpty) {
      final colorToMove = board.turn == 'w'
          ? PieceColor.white
          : PieceColor.black;
      if (board.isKingInCheck(colorToMove)) {
        return _NodeResult(-_mateValue + depth, null, true);
      }
      return _NodeResult(0, null, true);
    }

    final ordered = _orderMoves(board, moves, bestFromTt);
    var bestScore = -_infinity;
    var bestMoveKey = _moveKey(ordered.first);

    for (final move in ordered) {
      if (_timeExceeded()) {
        return _NodeResult(0, null, false);
      }

      final child = board.clone();
      child.move(move.toString());
      final node = _negamax(child, depth - 1, -beta, -alpha);
      if (!node.complete) {
        return _NodeResult(0, null, false);
      }
      final score = -node.score;

      if (score > bestScore) {
        bestScore = score;
        bestMoveKey = _moveKey(move);
      }
      if (score > alpha) {
        alpha = score;
      }
      if (alpha >= beta) {
        break;
      }
    }

    var flag = 'exact';
    if (bestScore <= originalAlpha) {
      flag = 'upper';
    } else if (bestScore >= beta) {
      flag = 'lower';
    }
    _tt[key] = _TTEntry(depth, bestScore, flag, bestMoveKey);

    return _NodeResult(bestScore, bestMoveKey, true);
  }

  List<Move> _orderMoves(Board board, List<Move> moves, String? ttMoveKey) {
    final ordered = List<Move>.from(moves);
    ordered.sort(
      (a, b) => _moveOrderingScore(
        board,
        b,
        ttMoveKey,
      ).compareTo(_moveOrderingScore(board, a, ttMoveKey)),
    );
    return ordered;
  }

  int _moveOrderingScore(Board board, Move move, String? ttMoveKey) {
    var score = 0;
    final key = _moveKey(move);
    if (ttMoveKey != null && key == ttMoveKey) {
      score += 100000;
    }

    final target = board.squares[move.toRow][move.toCol];
    if (target != null) {
      score += 10000 + (_materialValues[target.type] ?? 0);
    }
    if (move.promotion != null) {
      score += 9000 + (_materialValues[move.promotion!] ?? 0);
    }
    if (move.isCastling) {
      score += 100;
    }

    return score;
  }

  Move? _findMoveByKey(List<Move> moves, String? key) {
    if (key == null) return null;
    for (final move in moves) {
      if (_moveKey(move) == key) {
        return move;
      }
    }
    return null;
  }

  String _moveKey(Move move) {
    final promo = move.promotion?.name ?? '';
    return '${move.fromRow}:${move.fromCol}:${move.toRow}:${move.toCol}:$promo';
  }

  bool _timeExceeded() {
    if (_stopRequested) {
      _timedOut = true;
      return true;
    }
    if (_deadline == null) {
      return false;
    }
    if (DateTime.now().isAfter(_deadline!)) {
      _timedOut = true;
      return true;
    }
    return false;
  }

  int evaluate(Board board) {
    _evalCalls++;
    var score = 0;
    for (var i = 0; i < 8; i++) {
      for (var j = 0; j < 8; j++) {
        final piece = board.squares[i][j];
        if (piece != null) {
          final value = _materialValues[piece.type]!;
          if (piece.color == PieceColor.white) {
            score += value;
          } else {
            score -= value;
          }
        }
      }
    }
    return score;
  }
}
