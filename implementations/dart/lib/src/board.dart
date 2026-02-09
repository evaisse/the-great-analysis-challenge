import 'package:chess_engine/chess_engine.dart';
import 'zobrist.dart';

class IrreversibleState {
  final String castlingRights;
  final ({int row, int col})? enPassantTarget;
  final int halfmoveClock;
  final int zobristHash;

  IrreversibleState(
    this.castlingRights,
    this.enPassantTarget,
    this.halfmoveClock,
    this.zobristHash,
  );
}

class Board {
  late List<List<Piece?>> squares;
  late String turn;
  ({int row, int col})? _enPassantTarget;
  late String _castlingRights;
  late int _halfmoveClock;
  late int _fullmoveNumber;
  int zobristHash = 0;
  List<int> positionHistory = [];
  List<IrreversibleState> irreversibleHistory = [];

  Board._(
    this.squares,
    this.turn,
    this._enPassantTarget,
    this._castlingRights,
    this._halfmoveClock,
    this._fullmoveNumber,
    this.zobristHash,
    this.positionHistory,
    this.irreversibleHistory,
  );

  Board.empty() {
    squares = List.generate(8, (_) => List.filled(8, null));
    turn = 'w';
    _castlingRights = 'KQkq';
    _halfmoveClock = 0;
    _fullmoveNumber = 1;
    positionHistory = [];
    irreversibleHistory = [];
    zobristHash = Zobrist.instance.computeHash(this);
  }

  Board.fromFen(String fen) {
    squares = List.generate(8, (_) => List.filled(8, null));
    final parts = fen.split(' ');
    final piecePlacement = parts[0];
    turn = parts[1];
    _castlingRights = parts[2];
    if (parts.length > 3 && parts[3] != '-') {
      _enPassantTarget = _parseSquare(parts[3]);
    } else {
      _enPassantTarget = null;
    }
    _halfmoveClock = parts.length > 4 ? int.tryParse(parts[4]) ?? 0 : 0;
    _fullmoveNumber = parts.length > 5 ? int.tryParse(parts[5]) ?? 1 : 1;

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
    positionHistory = [];
    irreversibleHistory = [];
    zobristHash = Zobrist.instance.computeHash(this);
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
    final targetPiece = squares[to.row][to.col];
    
    // Save irreversible state
    irreversibleHistory.add(IrreversibleState(_castlingRights, _enPassantTarget, _halfmoveClock, zobristHash));
    positionHistory.add(zobristHash);

    int hash = zobristHash;
    final zobrist = Zobrist.instance;

    // 1. Remove piece from source
    hash ^= zobrist.pieces[zobrist.getPieceIndex(piece)][from.row * 8 + from.col];

    // 2. Handle capture
    bool isCapture = targetPiece != null;
    Piece? capturedPiece = targetPiece;
    if (piece.type == PieceType.pawn &&
        to.row == _enPassantTarget?.row &&
        to.col == _enPassantTarget?.col) {
      capturedPiece = squares[from.row][to.col];
      hash ^= zobrist.pieces[zobrist.getPieceIndex(capturedPiece!)][from.row * 8 + to.col];
      squares[from.row][to.col] = null;
      isCapture = true;
    } else if (isCapture) {
      hash ^= zobrist.pieces[zobrist.getPieceIndex(targetPiece!)][to.row * 8 + to.col];
    }

    // 3. Handle castling rook
<<<<<<< Updated upstream
    String? castlingMove;
    if (piece.type == PieceType.king && (from.col - to.col).abs() == 2) {
      if (to.col == 6) {
        castlingMove = 'K';
=======
    if (piece.type == PieceType.king && (from.col - to.col).abs() == 2) {
      if (to.col == 6) {
>>>>>>> Stashed changes
        final rook = squares[from.row][7]!;
        hash ^= zobrist.pieces[zobrist.getPieceIndex(rook)][from.row * 8 + 7];
        hash ^= zobrist.pieces[zobrist.getPieceIndex(rook)][from.row * 8 + 5];
        squares[from.row][7] = null;
        squares[from.row][5] = rook;
      } else {
<<<<<<< Updated upstream
        castlingMove = 'Q';
=======
>>>>>>> Stashed changes
        final rook = squares[from.row][0]!;
        hash ^= zobrist.pieces[zobrist.getPieceIndex(rook)][from.row * 8 + 0];
        hash ^= zobrist.pieces[zobrist.getPieceIndex(rook)][from.row * 8 + 3];
        squares[from.row][0] = null;
        squares[from.row][3] = rook;
      }
    }

    squares[from.row][from.col] = null;

    final finalPiece = promotion != null ? Piece(promotion, piece.color) : piece;
    hash ^= zobrist.pieces[zobrist.getPieceIndex(finalPiece)][to.row * 8 + to.col];
    squares[to.row][to.col] = finalPiece;

    // 4. Update castling rights in hash
    const rightsChars = 'KQkq';
    for (int i = 0; i < 4; i++) {
      if (_castlingRights.contains(rightsChars[i])) hash ^= zobrist.castling[i];
    }

<<<<<<< Updated upstream
    // Update rights logic
    if (piece.type == PieceType.king) {
      if (piece.color == PieceColor.white) {
        _castlingRights = _castlingRights.replaceAll('K', '').replaceAll('Q', '');
      } else {
        _castlingRights = _castlingRights.replaceAll('k', '').replaceAll('q', '');
=======
    if (piece.type == PieceType.king) {
      if (piece.color == PieceColor.white) {
        _castlingRights =
            _castlingRights.replaceAll('K', '').replaceAll('Q', '');
      } else {
        _castlingRights =
            _castlingRights.replaceAll('k', '').replaceAll('q', '');
>>>>>>> Stashed changes
      }
    } else if (piece.type == PieceType.rook) {
      if (from.row == 7 && from.col == 0) _castlingRights = _castlingRights.replaceAll('Q', '');
      if (from.row == 7 && from.col == 7) _castlingRights = _castlingRights.replaceAll('K', '');
      if (from.row == 0 && from.col == 0) _castlingRights = _castlingRights.replaceAll('q', '');
      if (from.row == 0 && from.col == 7) _castlingRights = _castlingRights.replaceAll('k', '');
    }
<<<<<<< Updated upstream
    // Also if rook is captured
=======
>>>>>>> Stashed changes
    if (to.row == 7 && to.col == 0) _castlingRights = _castlingRights.replaceAll('Q', '');
    if (to.row == 7 && to.col == 7) _castlingRights = _castlingRights.replaceAll('K', '');
    if (to.row == 0 && to.col == 0) _castlingRights = _castlingRights.replaceAll('q', '');
    if (to.row == 0 && to.col == 7) _castlingRights = _castlingRights.replaceAll('k', '');

    for (int i = 0; i < 4; i++) {
      if (_castlingRights.contains(rightsChars[i])) hash ^= zobrist.castling[i];
    }

    // 5. Update en passant target in hash
    if (_enPassantTarget != null) {
      hash ^= zobrist.enPassant[_enPassantTarget!.col];
    }

    if (piece.type == PieceType.pawn && (to.row - from.row).abs() == 2) {
      _enPassantTarget = (row: (from.row + to.row) ~/ 2, col: from.col);
      hash ^= zobrist.enPassant[_enPassantTarget!.col];
    } else {
      _enPassantTarget = null;
    }

    // 6. Update side to move
    hash ^= zobrist.sideToMove;
    
<<<<<<< Updated upstream
    if (isPawnMove || isCapture) {
=======
    if (piece.type == PieceType.pawn || isCapture) {
>>>>>>> Stashed changes
      _halfmoveClock = 0;
    } else {
      _halfmoveClock += 1;
    }

    if (turn == 'b') {
      _fullmoveNumber += 1;
<<<<<<< Updated upstream
    }
    turn = turn == 'w' ? 'b' : 'w';

    zobristHash = hash;
  }

  bool undoMove(Move move) {
    if (irreversibleHistory.isEmpty) return false;
    
    final old = irreversibleHistory.removeLast();
    positionHistory.removeLast();

    final from = (row: move.fromRow, col: move.fromCol);
    final to = (row: move.toRow, col: move.toCol);
    
    final movedPiece = squares[to.row][to.col]!;
    final originalPiece = move.promotion != null ? Piece(PieceType.pawn, movedPiece.color) : movedPiece;

    // Restore pieces
    squares[from.row][from.col] = originalPiece;
    squares[to.row][to.col] = move.capturedPiece;

    if (move.isEnPassant) {
      final capturedPawnRow = from.row;
      squares[capturedPawnRow][to.col] = move.capturedPiece;
      squares[to.row][to.col] = null;
    }

    // Handle castling rook
    if (move.isCastling) {
      if (to.col == 6) {
        final rook = squares[from.row][5]!;
        squares[from.row][5] = null;
        squares[from.row][7] = rook;
      } else {
        final rook = squares[from.row][3]!;
        squares[from.row][3] = null;
        squares[from.row][0] = rook;
      }
    }

    // Restore state
    _castlingRights = old.castlingRights;
    _enPassantTarget = old.enPassantTarget;
    _halfmoveClock = old.halfmoveClock;
    zobristHash = old.zobristHash;
    
    if (turn == 'w') {
      _fullmoveNumber -= 1;
    }
    turn = turn == 'w' ? 'b' : 'w';

=======
    }
    turn = turn == 'w' ? 'b' : 'w';

    zobristHash = hash;
  }

  bool undoMove(Move move) {
    if (irreversibleHistory.isEmpty) return false;
    
    final old = irreversibleHistory.removeLast();
    positionHistory.removeLast();

    final from = (row: move.fromRow, col: move.fromCol);
    final to = (row: move.toRow, col: move.toCol);
    
    final movedPiece = squares[to.row][to.col]!;
    final originalPiece = move.promotion != null ? Piece(PieceType.pawn, movedPiece.color) : movedPiece;

    // Restore pieces
    squares[from.row][from.col] = originalPiece;
    squares[to.row][to.col] = move.capturedPiece;

    if (move.isEnPassant) {
      final capturedPawnRow = from.row;
      squares[capturedPawnRow][to.col] = move.capturedPiece;
      squares[to.row][to.col] = null;
    }

    // Handle castling rook
    if (move.isCastling) {
      if (to.col == 6) {
        final rook = squares[from.row][5]!;
        squares[from.row][5] = null;
        squares[from.row][7] = rook;
      } else {
        final rook = squares[from.row][3]!;
        squares[from.row][3] = null;
        squares[from.row][0] = rook;
      }
    }

    // Restore state
    _castlingRights = old.castlingRights;
    _enPassantTarget = old.enPassantTarget;
    _halfmoveClock = old.halfmoveClock;
    zobristHash = old.zobristHash;
    
    if (turn == 'w') {
      _fullmoveNumber -= 1;
    }
    turn = turn == 'w' ? 'b' : 'w';

>>>>>>> Stashed changes
    return true;
  }

  ({int row, int col}) _parseSquare(String square) {
    final col = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final row = 8 - int.parse(square.substring(1));
    return (row: row, col: col);
  }

  String get_castlingRights_internal() => _castlingRights;
  ({int row, int col})? get_enPassantTarget_internal() => _enPassantTarget;
  int get_halfmoveClock_val() => _halfmoveClock;

  Board clone() {
    final newSquares = List.generate(8, (i) => List.of(squares[i]));
    return Board._(
      newSquares,
      turn,
      _enPassantTarget,
      _castlingRights,
      _halfmoveClock,
      _fullmoveNumber,
      zobristHash,
      List.of(positionHistory),
      List.of(irreversibleHistory),
    );
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
    final castling = (_castlingRights.isEmpty || _castlingRights == '-')
        ? '-'
        : _castlingRights;
    buffer.write(' $turn $castling ');
    if (_enPassantTarget != null) {
      buffer.write(
        '${String.fromCharCode('a'.codeUnitAt(0) + _enPassantTarget!.col)}${8 - _enPassantTarget!.row}',
      );
    } else {
      buffer.write('-');
    }
    buffer.write(' $_halfmoveClock $_fullmoveNumber');
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
      // Use internal move method that takes Move object or string
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
            moves.add(Move(row, col, row + direction, col + dcol)..isEnPassant = true);
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
        moves.add(Move(7, 4, 7, 6)..isCastling = true);
      }
      if (_castlingRights.contains('Q') &&
          squares[7][1] == null &&
          squares[7][2] == null &&
          squares[7][3] == null) {
        moves.add(Move(7, 4, 7, 2)..isCastling = true);
      }
    } else {
      if (_castlingRights.contains('k') &&
          squares[0][5] == null &&
          squares[0][6] == null) {
        moves.add(Move(0, 4, 0, 6)..isCastling = true);
      }
      if (_castlingRights.contains('q') &&
          squares[0][1] == null &&
          squares[0][2] == null &&
          squares[0][3] == null) {
        moves.add(Move(0, 4, 0, 2)..isCastling = true);
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