import 'package:test/test.dart';
import 'package:chess_engine/types/types.dart';

void main() {
  group('Color', () {
    test('white and black are distinct', () {
      expect(white, isNot(equals(black)));
      expect(black, isNot(equals(white)));
    });

    test('opposite color works', () {
      expect(white.opposite, equals(black));
      expect(black.opposite, equals(white));
    });

    test('color symbols are correct', () {
      expect(white.symbol, equals('w'));
      expect(black.symbol, equals('b'));
    });

    test('parseColor works', () {
      expect(parseColor('w'), equals(white));
      expect(parseColor('b'), equals(black));
    });

    test('parseColor rejects invalid input', () {
      expect(() => parseColor('x'), throwsArgumentError);
    });

    test('pattern matching is exhaustive', () {
      String describe(Color c) {
        return switch (c) {
          White() => 'white',
          Black() => 'black',
        };
      }

      expect(describe(white), equals('white'));
      expect(describe(black), equals('black'));
    });
  });

  group('PieceType', () {
    test('fromChar works for all pieces', () {
      expect(PieceType.fromChar('k'), equals(PieceType.king));
      expect(PieceType.fromChar('q'), equals(PieceType.queen));
      expect(PieceType.fromChar('r'), equals(PieceType.rook));
      expect(PieceType.fromChar('b'), equals(PieceType.bishop));
      expect(PieceType.fromChar('n'), equals(PieceType.knight));
      expect(PieceType.fromChar('p'), equals(PieceType.pawn));
    });

    test('fromChar is case-insensitive', () {
      expect(PieceType.fromChar('K'), equals(PieceType.king));
      expect(PieceType.fromChar('Q'), equals(PieceType.queen));
    });

    test('char property works', () {
      expect(PieceType.king.char, equals('k'));
      expect(PieceType.queen.char, equals('q'));
      expect(PieceType.rook.char, equals('r'));
      expect(PieceType.bishop.char, equals('b'));
      expect(PieceType.knight.char, equals('n'));
      expect(PieceType.pawn.char, equals('p'));
    });
  });

  group('Piece', () {
    test('creates piece correctly', () {
      final whiteKing = Piece(PieceType.king, white);
      expect(whiteKing.type, equals(PieceType.king));
      expect(whiteKing.color, equals(white));
      expect(whiteKing.isWhite, isTrue);
      expect(whiteKing.isBlack, isFalse);
    });

    test('fromChar creates correct pieces', () {
      final whiteKing = Piece.fromChar('K');
      expect(whiteKing.type, equals(PieceType.king));
      expect(whiteKing.color, equals(white));

      final blackKing = Piece.fromChar('k');
      expect(blackKing.type, equals(PieceType.king));
      expect(blackKing.color, equals(black));
    });

    test('toChar works correctly', () {
      final whiteKing = Piece(PieceType.king, white);
      expect(whiteKing.toChar(), equals('K'));

      final blackKing = Piece(PieceType.king, black);
      expect(blackKing.toChar(), equals('k'));
    });

    test('equality works', () {
      final k1 = Piece(PieceType.king, white);
      final k2 = Piece(PieceType.king, white);
      final k3 = Piece(PieceType.king, black);

      expect(k1, equals(k2));
      expect(k1, isNot(equals(k3)));
    });
  });
}
