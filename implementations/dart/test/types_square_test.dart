import 'package:test/test.dart';
import 'package:chess_engine/types/types.dart';

void main() {
  group('Square', () {
    test('creates valid square from index', () {
      final square = Square(0);
      expect(square.value, equals(0));
      expect(square.rank, equals(0));
      expect(square.file, equals(0));
    });

    test('creates valid square from algebraic notation', () {
      final e4 = Square.fromAlgebraic('e4');
      expect(e4.toAlgebraic(), equals('e4'));
      expect(e4.rank, equals(3));  // 0-based rank
      expect(e4.file, equals(4));  // 0-based file
    });

    test('creates square from row/col', () {
      final square = Square.fromRowCol(4, 4);  // e4 in internal coords
      expect(square.toAlgebraic(), equals('e4'));
    });

    test('rejects invalid square index', () {
      expect(() => Square(64), throwsArgumentError);
      expect(() => Square(-1), throwsArgumentError);
    });

    test('rejects invalid algebraic notation', () {
      expect(() => Square.fromAlgebraic('z9'), throwsArgumentError);
      expect(() => Square.fromAlgebraic('a0'), throwsArgumentError);
      expect(() => Square.fromAlgebraic('a9'), throwsArgumentError);
    });

    test('rejects invalid row/col', () {
      expect(() => Square.fromRowCol(-1, 0), throwsArgumentError);
      expect(() => Square.fromRowCol(0, 8), throwsArgumentError);
      expect(() => Square.fromRowCol(8, 0), throwsArgumentError);
    });

    test('offset works within bounds', () {
      final e4 = Square.fromAlgebraic('e4');
      final e5 = e4.offset(-1, 0);
      expect(e5, isNotNull);
      expect(e5!.toAlgebraic(), equals('e5'));
    });

    test('offset returns null when out of bounds', () {
      final a1 = Square.fromAlgebraic('a1');
      expect(a1.offset(1, 0), isNull);  // Below board
      expect(a1.offset(0, -1), isNull);  // Left of board
    });

    test('calculates distance correctly', () {
      final e4 = Square.fromAlgebraic('e4');
      final e5 = Square.fromAlgebraic('e5');
      expect(e4.distance(e5), equals(1));
      
      final a1 = Square.fromAlgebraic('a1');
      final h8 = Square.fromAlgebraic('h8');
      expect(a1.distance(h8), equals(14));  // Manhattan distance
    });

    test('calculates king distance correctly', () {
      final e4 = Square.fromAlgebraic('e4');
      final e5 = Square.fromAlgebraic('e5');
      expect(e4.kingDistance(e5), equals(1));
      
      final a1 = Square.fromAlgebraic('a1');
      final h8 = Square.fromAlgebraic('h8');
      expect(a1.kingDistance(h8), equals(7));  // Chebyshev distance
    });

    test('converts corner squares correctly', () {
      expect(Square.fromAlgebraic('a1').toAlgebraic(), equals('a1'));
      expect(Square.fromAlgebraic('a8').toAlgebraic(), equals('a8'));
      expect(Square.fromAlgebraic('h1').toAlgebraic(), equals('h1'));
      expect(Square.fromAlgebraic('h8').toAlgebraic(), equals('h8'));
    });
  });

  group('Rank and File', () {
    test('creates valid rank', () {
      final rank = Rank(1);
      expect(rank.value, equals(1));
      expect(rank.index, equals(0));
    });

    test('rejects invalid rank', () {
      expect(() => Rank(0), throwsArgumentError);
      expect(() => Rank(9), throwsArgumentError);
    });

    test('creates valid file', () {
      final file = File(0);
      expect(file.value, equals(0));
      expect(file.char, equals('a'));
    });

    test('creates file from char', () {
      final fileE = File.fromChar('e');
      expect(fileE.value, equals(4));
      expect(fileE.char, equals('e'));
    });

    test('rejects invalid file', () {
      expect(() => File(-1), throwsArgumentError);
      expect(() => File(8), throwsArgumentError);
    });
  });
}
