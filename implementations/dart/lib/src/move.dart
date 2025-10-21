import 'package:chess_engine/chess_engine.dart';

class Move {
  final int fromRow;
  final int fromCol;
  final int toRow;
  final int toCol;
  final PieceType? promotion;

  Move(this.fromRow, this.fromCol, this.toRow, this.toCol, {this.promotion});

  @override
  String toString() {
    return '${_colToChar(fromCol)}${8 - fromRow}${_colToChar(toCol)}${8 - toRow}${promotion != null ? _typeToChar(promotion!) : ''}';
  }

  static String _colToChar(int col) {
    return String.fromCharCode('a'.codeUnitAt(0) + col);
  }

  static String _typeToChar(PieceType type) {
    switch (type) {
      case PieceType.queen:
        return 'q';
      case PieceType.rook:
        return 'r';
      case PieceType.bishop:
        return 'b';
      case PieceType.knight:
        return 'n';
      default:
        return '';
    }
  }
}
