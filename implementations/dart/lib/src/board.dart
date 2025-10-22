import 'package:chess_engine/chess_engine.dart';

class Board {
  late List<List<Piece?>> squares;
  late String turn;
  ({int row, int col})? _enPassantTarget;
  String _castlingRights;

  Board._(this.squares, this.turn, this._enPassantTarget, this._castlingRights);

  Board.empty() {
    squares = List.generate(8, (_) => List.filled(8, null));
    turn = 'w';
    _castlingRights = 'KQkq';
  }

  Board.fromFen(String fen) {
    squares = List.generate(8, (_) => List.filled(8, null));
    final parts = fen.split(' ');
    final piecePlacement = parts[0];
    turn = parts[1];
    _castlingRights = parts[2];
    // TODO: parse castling rights
    if (parts[3] != '-') {
      _enPassantTarget = _parseSquare(parts[3]);
    } else {
      _enPassantTarget = null;
    }

    int row = 0;
    int col = 0;
    for (final char in piecePlacement.split('')) {
      if (char == '/') {
        row++;
        col = 0;
      } else if (int.tryParse(char) != null) {
        col += int.parse(char);
      } else {
        squares[row][col] = Piece.fromChar(char);
        col++;
      }
    }
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('  a b c d e f g h');
    for (int i = 0; i < 8; i++) {
      buffer.write('${8 - i} ');
      for (int j = 0; j < 8; j++) {
        final piece = squares[i][j];
        buffer.write('${piece?.toChar() ?? '.'} ');
      }
      buffer.writeln('${8 - i}');
    }
    buffer.writeln('  a b c d e f g h');
    buffer.writeln('');
    buffer.writeln('${turn == 'w' ? 'White' : 'Black'} to move');
    return buffer.toString();
  }

  void move(String moveStr) {
    final from = _parseSquare(moveStr.substring(0, 2));
    final to = _parseSquare(moveStr.substring(2, 4));
    PieceType? promotion;
    if (moveStr.length == 5) {
      promotion = Piece.charToType(moveStr.substring(4, 5).toLowerCase());
    }

    final piece = squares[from.row][from.col]!;

    // Handle castling
    if (piece.type == PieceType.king && (from.col - to.col).abs() == 2) {
      if (to.col == 6) {
        // Kingside
        final rook = squares[from.row][7];
        squares[from.row][7] = null;
        squares[from.row][5] = rook;
      } else {
        // Queenside
        final rook = squares[from.row][0];
        squares[from.row][0] = null;
        squares[from.row][3] = rook;
      }
    }

    squares[from.row][from.col] = null;

    // En passant capture
    if (piece.type == PieceType.pawn &&
        to.row == _enPassantTarget?.row &&
        to.col == _enPassantTarget?.col) {
      squares[from.row][to.col] = null;
    }

    if (promotion != null) {
      squares[to.row][to.col] = Piece(promotion, piece.color);
    } else {
      squares[to.row][to.col] = piece;
    }

    // Set en passant target
    if (piece.type == PieceType.pawn && (to.row - from.row).abs() == 2) {
      _enPassantTarget = (row: (from.row + to.row) ~/ 2, col: from.col);
    } else {
      _enPassantTarget = null;
    }

    // Update castling rights
    if (piece.type == PieceType.king) {
      if (piece.color == PieceColor.white) {
        _castlingRights =
            _castlingRights.replaceAll('K', '').replaceAll('Q', '');
      } else {
        _castlingRights =
            _castlingRights.replaceAll('k', '').replaceAll('q', '');
      }
    } else if (piece.type == PieceType.rook) {
      if (from.row == 7 && from.col == 0 && piece.color == PieceColor.white) {
        _castlingRights = _castlingRights.replaceAll('Q', '');
      } else if (from.row == 7 &&
          from.col == 7 &&
          piece.color == PieceColor.white) {
        _castlingRights = _castlingRights.replaceAll('K', '');
      } else if (from.row == 0 &&
          from.col == 0 &&
          piece.color == PieceColor.black) {
        _castlingRights = _castlingRights.replaceAll('q', '');
      } else if (from.row == 0 &&
          from.col == 7 &&
          piece.color == PieceColor.black) {
        _castlingRights = _castlingRights.replaceAll('k', '');
      }
    }

    turn = turn == 'w' ? 'b' : 'w';
  }

  ({int row, int col}) _parseSquare(String square) {
    final col = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final row = 8 - int.parse(square.substring(1));
    return (row: row, col: col);
  }

  Board clone() {
    final newSquares = List.generate(8, (i) => List.of(squares[i]));
    return Board._(newSquares, turn, _enPassantTarget, _castlingRights);
  }

  String toFen() {
    final buffer = StringBuffer();
    for (int i = 0; i < 8; i++) {
      int empty = 0;
      for (int j = 0; j < 8; j++) {
        final piece = squares[i][j];
        if (piece == null) {
          empty++;
        } else {
          if (empty > 0) {
            buffer.write(empty);
            empty = 0;
          }
          buffer.write(piece.toChar());
        }
      }
      if (empty > 0) {
        buffer.write(empty);
      }
      if (i < 7) {
        buffer.write('/');
      }
    }
    buffer.write(' $turn $_castlingRights ');
    if (_enPassantTarget != null) {
      buffer.write(
        '${String.fromCharCode('a'.codeUnitAt(0) + _enPassantTarget!.col)}${8 - _enPassantTarget!.row}',
      );
    } else {
      buffer.write('-');
    }
    buffer.write(' 0 1');
    return buffer.toString();
  }

  List<Move> generateMoves() {
    final pseudoLegalMoves = <Move>[];
    final playerColor = turn == 'w' ? PieceColor.white : PieceColor.black;

    for (int i = 0; i < 8; i++) {
      for (int j = 0; j < 8; j++) {
        final piece = squares[i][j];
        if (piece != null && piece.color == playerColor) {
          if (piece.type == PieceType.pawn) {
            _generatePawnMoves(i, j, playerColor, pseudoLegalMoves);
          } else if (piece.type == PieceType.knight) {
            _generateKnightMoves(i, j, playerColor, pseudoLegalMoves);
          } else if (piece.type == PieceType.bishop) {
            _generateSlidingMoves(i, j, playerColor, pseudoLegalMoves, [
              [-1, -1],
              [-1, 1],
              [1, -1],
              [1, 1],
            ]);
          } else if (piece.type == PieceType.rook) {
            _generateSlidingMoves(i, j, playerColor, pseudoLegalMoves, [
              [-1, 0],
              [1, 0],
              [0, -1],
              [0, 1],
            ]);
          } else if (piece.type == PieceType.queen) {
            _generateSlidingMoves(i, j, playerColor, pseudoLegalMoves, [
              [-1, -1],
              [-1, 1],
              [1, -1],
              [1, 1],
              [-1, 0],
              [1, 0],
              [0, -1],
              [0, 1],
            ]);
          } else if (piece.type == PieceType.king) {
            _generateKingMoves(i, j, playerColor, pseudoLegalMoves);
          }
        }
      }
    }

    final legalMoves = <Move>[];
    for (final move in pseudoLegalMoves) {
      final newBoard = clone();
      newBoard.move(move.toString());
      if (!newBoard.isKingInCheck(playerColor)) {
        legalMoves.add(move);
      }
    }

    return legalMoves;
  }

  void _generatePawnMoves(
    int row,
    int col,
    PieceColor color,
    List<Move> moves,
  ) {
    final direction = color == PieceColor.white ? -1 : 1;
    final startRow = color == PieceColor.white ? 6 : 1;
    final promotionRow = color == PieceColor.white ? 0 : 7;

    // Single move
    if (row + direction >= 0 &&
        row + direction < 8 &&
        squares[row + direction][col] == null) {
      if (row + direction == promotionRow) {
        moves.add(
          Move(row, col, row + direction, col, promotion: PieceType.queen),
        );
        moves.add(
          Move(row, col, row + direction, col, promotion: PieceType.rook),
        );
        moves.add(
          Move(row, col, row + direction, col, promotion: PieceType.bishop),
        );
        moves.add(
          Move(row, col, row + direction, col, promotion: PieceType.knight),
        );
      } else {
        moves.add(Move(row, col, row + direction, col));
      }

      // Double move
      if (row == startRow && squares[row + 2 * direction][col] == null) {
        moves.add(Move(row, col, row + 2 * direction, col));
      }
    }

    // Captures
    for (int dcol = -1; dcol <= 1; dcol += 2) {
      if (col + dcol >= 0 && col + dcol < 8) {
        if (row + direction >= 0 && row + direction < 8) {
          final dest = squares[row + direction][col + dcol];
          if (dest != null && dest.color != color) {
            if (row + direction == promotionRow) {
              moves.add(
                Move(
                  row,
                  col,
                  row + direction,
                  col + dcol,
                  promotion: PieceType.queen,
                ),
              );
              moves.add(
                Move(
                  row,
                  col,
                  row + direction,
                  col + dcol,
                  promotion: PieceType.rook,
                ),
              );
              moves.add(
                Move(
                  row,
                  col,
                  row + direction,
                  col + dcol,
                  promotion: PieceType.bishop,
                ),
              );
              moves.add(
                Move(
                  row,
                  col,
                  row + direction,
                  col + dcol,
                  promotion: PieceType.knight,
                ),
              );
            } else {
              moves.add(Move(row, col, row + direction, col + dcol));
            }
          } else if (_enPassantTarget != null &&
              _enPassantTarget!.row == row + direction &&
              _enPassantTarget!.col == col + dcol) {
            moves.add(Move(row, col, row + direction, col + dcol));
          }
        }
      }
    }
  }

  void _generateKnightMoves(
    int row,
    int col,
    PieceColor color,
    List<Move> moves,
  ) {
    final offsets = [
      [-2, -1],
      [-2, 1],
      [-1, -2],
      [-1, 2],
      [1, -2],
      [1, 2],
      [2, -1],
      [2, 1],
    ];
    for (final offset in offsets) {
      final newRow = row + offset[0];
      final newCol = col + offset[1];
      if (newRow >= 0 && newRow < 8 && newCol >= 0 && newCol < 8) {
        final dest = squares[newRow][newCol];
        if (dest == null || dest.color != color) {
          moves.add(Move(row, col, newRow, newCol));
        }
      }
    }
  }

  void _generateSlidingMoves(
    int row,
    int col,
    PieceColor color,
    List<Move> moves,
    List<List<int>> directions,
  ) {
    for (final dir in directions) {
      for (int i = 1; i < 8; i++) {
        final newRow = row + i * dir[0];
        final newCol = col + i * dir[1];
        if (newRow >= 0 && newRow < 8 && newCol >= 0 && newCol < 8) {
          final dest = squares[newRow][newCol];
          if (dest == null) {
            moves.add(Move(row, col, newRow, newCol));
          } else {
            if (dest.color != color) {
              moves.add(Move(row, col, newRow, newCol));
            }
            break;
          }
        } else {
          break;
        }
      }
    }
  }

  void _generateKingMoves(
    int row,
    int col,
    PieceColor color,
    List<Move> moves,
  ) {
    final offsets = [
      [-1, -1],
      [-1, 0],
      [-1, 1],
      [0, -1],
      [0, 1],
      [1, -1],
      [1, 0],
      [1, 1],
    ];
    for (final offset in offsets) {
      final newRow = row + offset[0];
      final newCol = col + offset[1];
      if (newRow >= 0 && newRow < 8 && newCol >= 0 && newCol < 8) {
        final dest = squares[newRow][newCol];
        if (dest == null || dest.color != color) {
          moves.add(Move(row, col, newRow, newCol));
        }
      }
    }

    // Castling
    if (color == PieceColor.white) {
      if (_castlingRights.contains('K') &&
          squares[7][5] == null &&
          squares[7][6] == null) {
        moves.add(Move(7, 4, 7, 6));
      }
      if (_castlingRights.contains('Q') &&
          squares[7][1] == null &&
          squares[7][2] == null &&
          squares[7][3] == null) {
        moves.add(Move(7, 4, 7, 2));
      }
    } else {
      if (_castlingRights.contains('k') &&
          squares[0][5] == null &&
          squares[0][6] == null) {
        moves.add(Move(0, 4, 0, 6));
      }
      if (_castlingRights.contains('q') &&
          squares[0][1] == null &&
          squares[0][2] == null &&
          squares[0][3] == null) {
        moves.add(Move(0, 4, 0, 2));
      }
    }
  }

  int perft(int depth) {
    if (depth == 0) {
      return 1;
    }

    int nodes = 0;
    final moves = generateMoves();
    for (final move in moves) {
      final newBoard = clone();
      newBoard.move(move.toString());
      nodes += newBoard.perft(depth - 1);
    }
    return nodes;
  }

  bool isSquareAttacked(int row, int col, PieceColor attackerColor) {
    // Check for pawn attacks
    final direction = attackerColor == PieceColor.white ? -1 : 1;
    if (row + direction >= 0 && row + direction < 8) {
      if (col - 1 >= 0) {
        final piece = squares[row + direction][col - 1];
        if (piece != null &&
            piece.color == attackerColor &&
            piece.type == PieceType.pawn) {
          return true;
        }
      }
      if (col + 1 < 8) {
        final piece = squares[row + direction][col + 1];
        if (piece != null &&
            piece.color == attackerColor &&
            piece.type == PieceType.pawn) {
          return true;
        }
      }
    }

    // Check for knight attacks
    final knightOffsets = [
      [-2, -1],
      [-2, 1],
      [-1, -2],
      [-1, 2],
      [1, -2],
      [1, 2],
      [2, -1],
      [2, 1],
    ];
    for (final offset in knightOffsets) {
      final newRow = row + offset[0];
      final newCol = col + offset[1];
      if (newRow >= 0 && newRow < 8 && newCol >= 0 && newCol < 8) {
        final piece = squares[newRow][newCol];
        if (piece != null &&
            piece.color == attackerColor &&
            piece.type == PieceType.knight) {
          return true;
        }
      }
    }

    // Check for sliding attacks (rooks, bishops, queens)
    final slidingDirections = {
      PieceType.rook: [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1],
      ],
      PieceType.bishop: [
        [-1, -1],
        [-1, 1],
        [1, -1],
        [1, 1],
      ],
      PieceType.queen: [
        [-1, -1],
        [-1, 1],
        [1, -1],
        [1, 1],
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1],
      ],
    };

    for (final pieceType in slidingDirections.keys) {
      for (final dir in slidingDirections[pieceType]!) {
        for (int i = 1; i < 8; i++) {
          final newRow = row + i * dir[0];
          final newCol = col + i * dir[1];
          if (newRow >= 0 && newRow < 8 && newCol >= 0 && newCol < 8) {
            final piece = squares[newRow][newCol];
            if (piece != null) {
              if (piece.color == attackerColor &&
                  (piece.type == pieceType || piece.type == PieceType.queen)) {
                return true;
              }
              break;
            }
          } else {
            break;
          }
        }
      }
    }

    // Check for king attacks
    final kingOffsets = [
      [-1, -1],
      [-1, 0],
      [-1, 1],
      [0, -1],
      [0, 1],
      [1, -1],
      [1, 0],
      [1, 1],
    ];
    for (final offset in kingOffsets) {
      final newRow = row + offset[0];
      final newCol = col + offset[1];
      if (newRow >= 0 && newRow < 8 && newCol >= 0 && newCol < 8) {
        final piece = squares[newRow][newCol];
        if (piece != null &&
            piece.color == attackerColor &&
            piece.type == PieceType.king) {
          return true;
        }
      }
    }

    return false;
  }

  bool isKingInCheck(PieceColor kingColor) {
    int kingRow = -1;
    int kingCol = -1;
    for (int i = 0; i < 8; i++) {
      for (int j = 0; j < 8; j++) {
        final piece = squares[i][j];
        if (piece != null &&
            piece.type == PieceType.king &&
            piece.color == kingColor) {
          kingRow = i;
          kingCol = j;
          break;
        }
      }
    }
    return isSquareAttacked(
      kingRow,
      kingCol,
      kingColor == PieceColor.white ? PieceColor.black : PieceColor.white,
    );
  }
}
