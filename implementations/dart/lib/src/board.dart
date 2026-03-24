import 'package:chess_engine/chess_engine.dart';
import 'attack_tables.dart';
import 'zobrist.dart';

class CastlingConfig {
  final int whiteKingCol;
  final int whiteKingsideRookCol;
  final int whiteQueensideRookCol;
  final int blackKingCol;
  final int blackKingsideRookCol;
  final int blackQueensideRookCol;

  const CastlingConfig({
    this.whiteKingCol = 4,
    this.whiteKingsideRookCol = 7,
    this.whiteQueensideRookCol = 0,
    this.blackKingCol = 4,
    this.blackKingsideRookCol = 7,
    this.blackQueensideRookCol = 0,
  });

  bool get isClassical =>
      whiteKingCol == 4 &&
      whiteKingsideRookCol == 7 &&
      whiteQueensideRookCol == 0 &&
      blackKingCol == 4 &&
      blackKingsideRookCol == 7 &&
      blackQueensideRookCol == 0;
}

class IrreversibleState {
  final String castlingRights;
  final CastlingConfig castlingConfig;
  final bool chess960Mode;
  final ({int row, int col})? enPassantTarget;
  final int halfmoveClock;
  final int zobristHash;

  IrreversibleState(
    this.castlingRights,
    this.castlingConfig,
    this.chess960Mode,
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
  late CastlingConfig _castlingConfig;
  late bool _chess960Mode;
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
    this._castlingConfig,
    this._chess960Mode,
    this._halfmoveClock,
    this._fullmoveNumber,
    this.zobristHash,
    this.positionHistory,
    this.irreversibleHistory,
  );

  Board() {
    reset();
  }

  void reset() {
    squares = List.generate(8, (_) => List.filled(8, null));

    const backRank = [
      PieceType.rook,
      PieceType.knight,
      PieceType.bishop,
      PieceType.queen,
      PieceType.king,
      PieceType.bishop,
      PieceType.knight,
      PieceType.rook,
    ];
    for (int col = 0; col < 8; col++) {
      squares[0][col] = Piece(backRank[col], PieceColor.black);
      squares[1][col] = Piece(PieceType.pawn, PieceColor.black);
      squares[6][col] = Piece(PieceType.pawn, PieceColor.white);
      squares[7][col] = Piece(backRank[col], PieceColor.white);
    }

    turn = 'w';
    _castlingRights = 'KQkq';
    _castlingConfig = const CastlingConfig();
    _chess960Mode = false;
    _enPassantTarget = null;
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

    turn = parts[1];
    _castlingRights = '';
    _castlingConfig = const CastlingConfig();
    _chess960Mode = false;
    _initializeCastlingConfigFromBoard();
    _parseCastlingRights(parts[2]);
    if (parts.length > 3 && parts[3] != '-') {
      _enPassantTarget = _parseSquare(parts[3]);
    } else {
      _enPassantTarget = null;
    }
    _halfmoveClock = parts.length > 4 ? int.tryParse(parts[4]) ?? 0 : 0;
    _fullmoveNumber = parts.length > 5 ? int.tryParse(parts[5]) ?? 1 : 1;
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

  String display() => toString();

  void move(String moveStr) {
    final from = _parseSquare(moveStr.substring(0, 2));
    final to = _parseSquare(moveStr.substring(2, 4));
    PieceType? promotion;
    if (moveStr.length == 5) {
      promotion = Piece.charToType(moveStr.substring(4, 5).toLowerCase());
    }

    final piece = squares[from.row][from.col]!;
    final targetPiece = squares[to.row][to.col];
    final isCastling =
        piece.type == PieceType.king &&
        from.row == to.row &&
        (to.col == 2 || to.col == 6);

    irreversibleHistory.add(
      IrreversibleState(
        _castlingRights,
        _castlingConfig,
        _chess960Mode,
        _enPassantTarget,
        _halfmoveClock,
        zobristHash,
      ),
    );
    positionHistory.add(zobristHash);

    int hash = zobristHash;
    final zobrist = Zobrist.instance;

    hash ^=
        zobrist.pieces[zobrist.getPieceIndex(piece)][from.row * 8 + from.col];

    bool isCapture = targetPiece != null && !isCastling;
    Piece? capturedPiece = targetPiece;
    if (piece.type == PieceType.pawn &&
        to.row == _enPassantTarget?.row &&
        to.col == _enPassantTarget?.col) {
      capturedPiece = squares[from.row][to.col];
      hash ^= zobrist
          .pieces[zobrist.getPieceIndex(capturedPiece!)][from.row * 8 + to.col];
      squares[from.row][to.col] = null;
      isCapture = true;
    } else if (isCapture) {
      hash ^= zobrist
          .pieces[zobrist.getPieceIndex(targetPiece)][to.row * 8 + to.col];
    }

    squares[from.row][from.col] = null;
    final finalPiece = promotion != null
        ? Piece(promotion, piece.color)
        : piece;
    hash ^=
        zobrist.pieces[zobrist.getPieceIndex(finalPiece)][to.row * 8 + to.col];
    squares[to.row][to.col] = finalPiece;

    if (isCastling) {
      final details = _getCastleDetails(piece.color, to.col == 6);
      final rook = squares[details.rookStart.row][details.rookStart.col]!;
      hash ^=
          zobrist.pieces[zobrist.getPieceIndex(
            rook,
          )][details.rookStart.row * 8 + details.rookStart.col];
      hash ^=
          zobrist.pieces[zobrist.getPieceIndex(
            rook,
          )][details.rookTarget.row * 8 + details.rookTarget.col];
      if (!_sameSquare(details.rookStart, from) &&
          !_sameSquare(details.rookStart, to)) {
        squares[details.rookStart.row][details.rookStart.col] = null;
      }
      squares[details.rookTarget.row][details.rookTarget.col] = rook;
    }

    const rightsChars = 'KQkq';
    for (int i = 0; i < 4; i++) {
      if (_castlingRights.contains(rightsChars[i])) {
        hash ^= zobrist.castling[i];
      }
    }

    if (piece.type == PieceType.king) {
      if (piece.color == PieceColor.white) {
        _removeCastlingRight(PieceColor.white, true);
        _removeCastlingRight(PieceColor.white, false);
      } else {
        _removeCastlingRight(PieceColor.black, true);
        _removeCastlingRight(PieceColor.black, false);
      }
    } else if (piece.type == PieceType.rook) {
      if (from.row == 7 && from.col == _castlingConfig.whiteQueensideRookCol) {
        _removeCastlingRight(PieceColor.white, false);
      }
      if (from.row == 7 && from.col == _castlingConfig.whiteKingsideRookCol) {
        _removeCastlingRight(PieceColor.white, true);
      }
      if (from.row == 0 && from.col == _castlingConfig.blackQueensideRookCol) {
        _removeCastlingRight(PieceColor.black, false);
      }
      if (from.row == 0 && from.col == _castlingConfig.blackKingsideRookCol) {
        _removeCastlingRight(PieceColor.black, true);
      }
    }

    if (to.row == 7 && to.col == _castlingConfig.whiteQueensideRookCol) {
      _removeCastlingRight(PieceColor.white, false);
    }
    if (to.row == 7 && to.col == _castlingConfig.whiteKingsideRookCol) {
      _removeCastlingRight(PieceColor.white, true);
    }
    if (to.row == 0 && to.col == _castlingConfig.blackQueensideRookCol) {
      _removeCastlingRight(PieceColor.black, false);
    }
    if (to.row == 0 && to.col == _castlingConfig.blackKingsideRookCol) {
      _removeCastlingRight(PieceColor.black, true);
    }

    for (int i = 0; i < 4; i++) {
      if (_castlingRights.contains(rightsChars[i])) {
        hash ^= zobrist.castling[i];
      }
    }

    if (_enPassantTarget != null) {
      hash ^= zobrist.enPassant[_enPassantTarget!.col];
    }

    if (piece.type == PieceType.pawn && (to.row - from.row).abs() == 2) {
      _enPassantTarget = (row: (from.row + to.row) ~/ 2, col: from.col);
      hash ^= zobrist.enPassant[_enPassantTarget!.col];
    } else {
      _enPassantTarget = null;
    }

    hash ^= zobrist.sideToMove;

    if (piece.type == PieceType.pawn || isCapture) {
      _halfmoveClock = 0;
    } else {
      _halfmoveClock += 1;
    }

    if (turn == 'b') {
      _fullmoveNumber += 1;
    }
    turn = turn == 'w' ? 'b' : 'w';

    zobristHash = hash;
  }

  void makeMove(Move move) {
    this.move(move.toString());
  }

  bool undoMove(Move move) {
    if (irreversibleHistory.isEmpty) {
      return false;
    }

    final old = irreversibleHistory.removeLast();
    positionHistory.removeLast();

    final from = (row: move.fromRow, col: move.fromCol);
    final to = (row: move.toRow, col: move.toCol);

    final movedPiece = squares[to.row][to.col]!;
    final originalPiece = move.promotion != null
        ? Piece(PieceType.pawn, movedPiece.color)
        : movedPiece;
    final castleDetails = move.isCastling
        ? _getCastleDetails(movedPiece.color, to.col == 6)
        : null;
    final castleRook = castleDetails == null
        ? null
        : squares[castleDetails.rookTarget.row][castleDetails.rookTarget.col];

    squares[from.row][from.col] = originalPiece;
    squares[to.row][to.col] = move.capturedPiece;

    if (move.isEnPassant) {
      final capturedPawnRow = from.row;
      squares[capturedPawnRow][to.col] = move.capturedPiece;
      squares[to.row][to.col] = null;
    }

    if (move.isCastling) {
      final details = castleDetails!;
      if (!_sameSquare(details.rookTarget, from)) {
        squares[details.rookTarget.row][details.rookTarget.col] = null;
      }
      squares[details.rookStart.row][details.rookStart.col] = castleRook;
    }

    _castlingRights = old.castlingRights;
    _castlingConfig = old.castlingConfig;
    _chess960Mode = old.chess960Mode;
    _enPassantTarget = old.enPassantTarget;
    _halfmoveClock = old.halfmoveClock;
    zobristHash = old.zobristHash;

    if (turn == 'w') {
      _fullmoveNumber -= 1;
    }
    turn = turn == 'w' ? 'b' : 'w';

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
      _castlingConfig,
      _chess960Mode,
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
    buffer.write(' $turn ${_currentCastlingRightsFen()} ');
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

      if (row == startRow && squares[row + 2 * direction][col] == null) {
        moves.add(Move(row, col, row + 2 * direction, col));
      }
    }

    for (int dcol = -1; dcol <= 1; dcol += 2) {
      if (col + dcol >= 0 &&
          col + dcol < 8 &&
          row + direction >= 0 &&
          row + direction < 8) {
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
          moves.add(
            Move(row, col, row + direction, col + dcol)..isEnPassant = true,
          );
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
    for (final square in knightAttacks(row, col)) {
      final dest = squares[square.row][square.col];
      if (dest == null || dest.color != color) {
        moves.add(Move(row, col, square.row, square.col));
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
      for (final square in rayAttacks(row, col, dir[0], dir[1])) {
        final dest = squares[square.row][square.col];
        if (dest == null) {
          moves.add(Move(row, col, square.row, square.col));
        } else {
          if (dest.color != color) {
            moves.add(Move(row, col, square.row, square.col));
          }
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
    for (final square in kingAttacks(row, col)) {
      final dest = squares[square.row][square.col];
      if (dest == null || dest.color != color) {
        moves.add(Move(row, col, square.row, square.col));
      }
    }

    if (!isKingInCheck(color)) {
      for (final kingside in [true, false]) {
        if (!_hasCastlingRight(color, kingside)) {
          continue;
        }

        final details = _getCastleDetails(color, kingside);
        if (!_sameSquare(details.kingStart, (row: row, col: col))) {
          continue;
        }

        final rook = squares[details.rookStart.row][details.rookStart.col];
        if (rook == null ||
            rook.color != color ||
            rook.type != PieceType.rook) {
          continue;
        }

        final blockerSquares = <({int row, int col})>[];
        final seen = <String>{};
        for (final square in [
          ..._linePath(details.kingStart, details.kingTarget),
          ..._linePath(details.rookStart, details.rookTarget),
        ]) {
          final key = '${square.row}:${square.col}';
          if (seen.add(key)) {
            blockerSquares.add(square);
          }
        }
        if (blockerSquares.any(
          (square) =>
              !_sameSquare(square, details.kingStart) &&
              !_sameSquare(square, details.rookStart) &&
              squares[square.row][square.col] != null,
        )) {
          continue;
        }

        final attackSquares = <({int row, int col})>[
          details.kingStart,
          ..._linePath(details.kingStart, details.kingTarget),
        ];
        final attacker = color == PieceColor.white
            ? PieceColor.black
            : PieceColor.white;
        final attackedSeen = <String>{};
        if (attackSquares.any((square) {
          final key = '${square.row}:${square.col}';
          if (!attackedSeen.add(key)) {
            return false;
          }
          return isSquareAttacked(square.row, square.col, attacker);
        })) {
          continue;
        }

        moves.add(
          Move(row, col, details.kingTarget.row, details.kingTarget.col)
            ..isCastling = true,
        );
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
    final direction = attackerColor == PieceColor.white ? 1 : -1;
    final pawnRow = row + direction;
    if (pawnRow >= 0 && pawnRow < 8) {
      for (int dcol in [-1, 1]) {
        final pawnCol = col + dcol;
        if (pawnCol >= 0 && pawnCol < 8) {
          final piece = squares[pawnRow][pawnCol];
          if (piece != null &&
              piece.color == attackerColor &&
              piece.type == PieceType.pawn) {
            return true;
          }
        }
      }
    }

    for (final square in knightAttacks(row, col)) {
      final piece = squares[square.row][square.col];
      if (piece != null &&
          piece.color == attackerColor &&
          piece.type == PieceType.knight) {
        return true;
      }
    }

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
        for (final square in rayAttacks(row, col, dir[0], dir[1])) {
          final piece = squares[square.row][square.col];
          if (piece != null) {
            if (piece.color == attackerColor &&
                (piece.type == pieceType || piece.type == PieceType.queen)) {
              return true;
            }
            break;
          }
        }
      }
    }

    for (final square in kingAttacks(row, col)) {
      final piece = squares[square.row][square.col];
      if (piece != null &&
          piece.color == attackerColor &&
          piece.type == PieceType.king) {
        return true;
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
    if (kingRow == -1) {
      return false;
    }
    return isSquareAttacked(
      kingRow,
      kingCol,
      kingColor == PieceColor.white ? PieceColor.black : PieceColor.white,
    );
  }

  void _initializeCastlingConfigFromBoard() {
    final whiteKingCol =
        _findHomeRankPiece(PieceColor.white, PieceType.king) ?? 4;
    final blackKingCol =
        _findHomeRankPiece(PieceColor.black, PieceType.king) ?? 4;
    _castlingConfig = CastlingConfig(
      whiteKingCol: whiteKingCol,
      blackKingCol: blackKingCol,
    );
    _chess960Mode = false;
  }

  void configureChess960() {
    final whiteKingCol = _findHomeRankPiece(PieceColor.white, PieceType.king);
    final blackKingCol = _findHomeRankPiece(PieceColor.black, PieceType.king);
    if (whiteKingCol == null || blackKingCol == null) {
      _castlingConfig = const CastlingConfig();
      _chess960Mode = false;
      return;
    }

    final whiteRooks = <int>[];
    final blackRooks = <int>[];
    for (var col = 0; col < 8; col++) {
      final whitePiece = squares[7][col];
      if (whitePiece?.type == PieceType.rook &&
          whitePiece?.color == PieceColor.white) {
        whiteRooks.add(col);
      }
      final blackPiece = squares[0][col];
      if (blackPiece?.type == PieceType.rook &&
          blackPiece?.color == PieceColor.black) {
        blackRooks.add(col);
      }
    }

    if (whiteRooks.isEmpty || blackRooks.isEmpty) {
      _castlingConfig = const CastlingConfig();
      _chess960Mode = false;
      return;
    }

    _castlingConfig = CastlingConfig(
      whiteKingCol: whiteKingCol,
      whiteKingsideRookCol: _selectRookCol(whiteRooks, whiteKingCol, true, 7),
      whiteQueensideRookCol: _selectRookCol(whiteRooks, whiteKingCol, false, 0),
      blackKingCol: blackKingCol,
      blackKingsideRookCol: _selectRookCol(blackRooks, blackKingCol, true, 7),
      blackQueensideRookCol: _selectRookCol(blackRooks, blackKingCol, false, 0),
    );
    _chess960Mode = !_castlingConfig.isClassical;
  }

  void _parseCastlingRights(String castling) {
    _castlingRights = '';
    if (castling == '-' || castling.isEmpty) {
      return;
    }

    for (final char in castling.split('')) {
      if (char == 'K' || char == 'Q' || char == 'k' || char == 'q') {
        _castlingRights += char;
      } else if (char.codeUnitAt(0) >= 'A'.codeUnitAt(0) &&
          char.codeUnitAt(0) <= 'H'.codeUnitAt(0)) {
        final rookCol = char.codeUnitAt(0) - 'A'.codeUnitAt(0);
        _chess960Mode = true;
        if (rookCol > _castlingConfig.whiteKingCol) {
          _castlingConfig = CastlingConfig(
            whiteKingCol: _castlingConfig.whiteKingCol,
            whiteKingsideRookCol: rookCol,
            whiteQueensideRookCol: _castlingConfig.whiteQueensideRookCol,
            blackKingCol: _castlingConfig.blackKingCol,
            blackKingsideRookCol: _castlingConfig.blackKingsideRookCol,
            blackQueensideRookCol: _castlingConfig.blackQueensideRookCol,
          );
        } else {
          _castlingConfig = CastlingConfig(
            whiteKingCol: _castlingConfig.whiteKingCol,
            whiteKingsideRookCol: _castlingConfig.whiteKingsideRookCol,
            whiteQueensideRookCol: rookCol,
            blackKingCol: _castlingConfig.blackKingCol,
            blackKingsideRookCol: _castlingConfig.blackKingsideRookCol,
            blackQueensideRookCol: _castlingConfig.blackQueensideRookCol,
          );
        }
        _castlingRights += char;
      } else if (char.codeUnitAt(0) >= 'a'.codeUnitAt(0) &&
          char.codeUnitAt(0) <= 'h'.codeUnitAt(0)) {
        final rookCol = char.codeUnitAt(0) - 'a'.codeUnitAt(0);
        _chess960Mode = true;
        if (rookCol > _castlingConfig.blackKingCol) {
          _castlingConfig = CastlingConfig(
            whiteKingCol: _castlingConfig.whiteKingCol,
            whiteKingsideRookCol: _castlingConfig.whiteKingsideRookCol,
            whiteQueensideRookCol: _castlingConfig.whiteQueensideRookCol,
            blackKingCol: _castlingConfig.blackKingCol,
            blackKingsideRookCol: rookCol,
            blackQueensideRookCol: _castlingConfig.blackQueensideRookCol,
          );
        } else {
          _castlingConfig = CastlingConfig(
            whiteKingCol: _castlingConfig.whiteKingCol,
            whiteKingsideRookCol: _castlingConfig.whiteKingsideRookCol,
            whiteQueensideRookCol: _castlingConfig.whiteQueensideRookCol,
            blackKingCol: _castlingConfig.blackKingCol,
            blackKingsideRookCol: _castlingConfig.blackKingsideRookCol,
            blackQueensideRookCol: rookCol,
          );
        }
        _castlingRights += char;
      }
    }
  }

  String _currentCastlingRightsFen() {
    if (_chess960Mode) {
      final rights = <String>[];
      if (_hasCastlingRight(PieceColor.white, false)) {
        rights.add(
          String.fromCharCode(
            'A'.codeUnitAt(0) + _castlingConfig.whiteQueensideRookCol,
          ),
        );
      }
      if (_hasCastlingRight(PieceColor.white, true)) {
        rights.add(
          String.fromCharCode(
            'A'.codeUnitAt(0) + _castlingConfig.whiteKingsideRookCol,
          ),
        );
      }
      if (_hasCastlingRight(PieceColor.black, false)) {
        rights.add(
          String.fromCharCode(
            'a'.codeUnitAt(0) + _castlingConfig.blackQueensideRookCol,
          ),
        );
      }
      if (_hasCastlingRight(PieceColor.black, true)) {
        rights.add(
          String.fromCharCode(
            'a'.codeUnitAt(0) + _castlingConfig.blackKingsideRookCol,
          ),
        );
      }
      return rights.isEmpty ? '-' : rights.join();
    }

    return (_castlingRights.isEmpty || _castlingRights == '-')
        ? '-'
        : _castlingRights;
  }

  String _castlingRightSymbol(PieceColor color, bool kingside) {
    if (!_chess960Mode) {
      if (color == PieceColor.white) {
        return kingside ? 'K' : 'Q';
      }
      return kingside ? 'k' : 'q';
    }

    if (color == PieceColor.white) {
      return String.fromCharCode(
        'A'.codeUnitAt(0) +
            (kingside
                ? _castlingConfig.whiteKingsideRookCol
                : _castlingConfig.whiteQueensideRookCol),
      );
    }
    return String.fromCharCode(
      'a'.codeUnitAt(0) +
          (kingside
              ? _castlingConfig.blackKingsideRookCol
              : _castlingConfig.blackQueensideRookCol),
    );
  }

  bool _hasCastlingRight(PieceColor color, bool kingside) {
    return _castlingRights.contains(_castlingRightSymbol(color, kingside));
  }

  void _removeCastlingRight(PieceColor color, bool kingside) {
    _castlingRights = _castlingRights.replaceAll(
      _castlingRightSymbol(color, kingside),
      '',
    );
  }

  ({
    ({int row, int col}) kingStart,
    ({int row, int col}) rookStart,
    ({int row, int col}) kingTarget,
    ({int row, int col}) rookTarget,
  })
  _getCastleDetails(PieceColor color, bool kingside) {
    final row = color == PieceColor.white ? 7 : 0;
    return (
      kingStart: (
        row: row,
        col: color == PieceColor.white
            ? _castlingConfig.whiteKingCol
            : _castlingConfig.blackKingCol,
      ),
      rookStart: (
        row: row,
        col: color == PieceColor.white
            ? (kingside
                  ? _castlingConfig.whiteKingsideRookCol
                  : _castlingConfig.whiteQueensideRookCol)
            : (kingside
                  ? _castlingConfig.blackKingsideRookCol
                  : _castlingConfig.blackQueensideRookCol),
      ),
      kingTarget: (row: row, col: kingside ? 6 : 2),
      rookTarget: (row: row, col: kingside ? 5 : 3),
    );
  }

  List<({int row, int col})> _linePath(
    ({int row, int col}) start,
    ({int row, int col}) target,
  ) {
    if (_sameSquare(start, target)) {
      return const [];
    }
    final rowStep = target.row == start.row
        ? 0
        : (target.row > start.row ? 1 : -1);
    final colStep = target.col == start.col
        ? 0
        : (target.col > start.col ? 1 : -1);
    var row = start.row + rowStep;
    var col = start.col + colStep;
    final path = <({int row, int col})>[];
    while (row != target.row || col != target.col) {
      path.add((row: row, col: col));
      row += rowStep;
      col += colStep;
    }
    path.add(target);
    return path;
  }

  int? _findHomeRankPiece(PieceColor color, PieceType type) {
    final row = color == PieceColor.white ? 7 : 0;
    for (var col = 0; col < 8; col++) {
      final piece = squares[row][col];
      if (piece?.color == color && piece?.type == type) {
        return col;
      }
    }
    return null;
  }

  int _selectRookCol(
    List<int> rookCols,
    int kingCol,
    bool kingside,
    int fallback,
  ) {
    final candidates = rookCols
        .where((col) => kingside ? col > kingCol : col < kingCol)
        .toList();
    if (candidates.isEmpty) {
      return fallback;
    }
    candidates.sort();
    return kingside ? candidates.last : candidates.first;
  }

  bool _sameSquare(({int row, int col}) a, ({int row, int col}) b) {
    return a.row == b.row && a.col == b.col;
  }
}
