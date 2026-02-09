import 'package:test/test.dart';
import 'package:chess_engine/types/types.dart';

void main() {
  group('CastlingRights', () {
    test('all rights are set', () {
      expect(CastlingRights.all.whiteKingside, isTrue);
      expect(CastlingRights.all.whiteQueenside, isTrue);
      expect(CastlingRights.all.blackKingside, isTrue);
      expect(CastlingRights.all.blackQueenside, isTrue);
    });

    test('no rights are set', () {
      expect(CastlingRights.none.whiteKingside, isFalse);
      expect(CastlingRights.none.whiteQueenside, isFalse);
      expect(CastlingRights.none.blackKingside, isFalse);
      expect(CastlingRights.none.blackQueenside, isFalse);
    });

    test('fromFen parses all rights', () {
      final rights = CastlingRights.fromFen('KQkq');
      expect(rights.whiteKingside, isTrue);
      expect(rights.whiteQueenside, isTrue);
      expect(rights.blackKingside, isTrue);
      expect(rights.blackQueenside, isTrue);
    });

    test('fromFen parses partial rights', () {
      final rights = CastlingRights.fromFen('Kq');
      expect(rights.whiteKingside, isTrue);
      expect(rights.whiteQueenside, isFalse);
      expect(rights.blackKingside, isFalse);
      expect(rights.blackQueenside, isTrue);
    });

    test('fromFen parses no rights', () {
      final rights = CastlingRights.fromFen('-');
      expect(rights.whiteKingside, isFalse);
      expect(rights.whiteQueenside, isFalse);
      expect(rights.blackKingside, isFalse);
      expect(rights.blackQueenside, isFalse);
    });

    test('toFen works for all rights', () {
      expect(CastlingRights.all.toFen(), equals('KQkq'));
    });

    test('toFen works for no rights', () {
      expect(CastlingRights.none.toFen(), equals('-'));
    });

    test('toFen works for partial rights', () {
      final rights = CastlingRights(
        whiteKingside: true,
        whiteQueenside: false,
        blackKingside: false,
        blackQueenside: true,
      );
      expect(rights.toFen(), equals('Kq'));
    });

    test('canCastleKingside works', () {
      final rights = CastlingRights.fromFen('Kq');
      expect(rights.canCastleKingside(white), isTrue);
      expect(rights.canCastleKingside(black), isFalse);
    });

    test('canCastleQueenside works', () {
      final rights = CastlingRights.fromFen('Qk');
      expect(rights.canCastleQueenside(white), isTrue);
      expect(rights.canCastleQueenside(black), isFalse);
    });

    test('removeKingside works', () {
      var rights = CastlingRights.all;
      rights = rights.removeKingside(white);
      expect(rights.whiteKingside, isFalse);
      expect(rights.whiteQueenside, isTrue);
      expect(rights.blackKingside, isTrue);
      expect(rights.blackQueenside, isTrue);
    });

    test('removeQueenside works', () {
      var rights = CastlingRights.all;
      rights = rights.removeQueenside(black);
      expect(rights.whiteKingside, isTrue);
      expect(rights.whiteQueenside, isTrue);
      expect(rights.blackKingside, isTrue);
      expect(rights.blackQueenside, isFalse);
    });

    test('removeAll works', () {
      var rights = CastlingRights.all;
      rights = rights.removeAll(white);
      expect(rights.whiteKingside, isFalse);
      expect(rights.whiteQueenside, isFalse);
      expect(rights.blackKingside, isTrue);
      expect(rights.blackQueenside, isTrue);
    });

    test('equality works', () {
      final r1 = CastlingRights.fromFen('KQkq');
      final r2 = CastlingRights.fromFen('KQkq');
      final r3 = CastlingRights.fromFen('Kq');
      
      expect(r1, equals(r2));
      expect(r1, isNot(equals(r3)));
    });
  });
}
