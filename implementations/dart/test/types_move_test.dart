import 'package:test/test.dart';
import 'package:chess_engine/types/types.dart';

void main() {
  group('MoveValidation', () {
    test('Legal and Unchecked are distinct', () {
      expect(legal, isNot(equals(unchecked)));
    });
  });

  group('Move<Unchecked>', () {
    test('parses move correctly', () {
      final move = Move<Unchecked>.parse('e2e4');
      expect(move.from.toAlgebraic(), equals('e2'));
      expect(move.to.toAlgebraic(), equals('e4'));
      expect(move.promotion, isNull);
    });

    test('parses move with promotion', () {
      final move = Move<Unchecked>.parse('e7e8q');
      expect(move.from.toAlgebraic(), equals('e7'));
      expect(move.to.toAlgebraic(), equals('e8'));
      expect(move.promotion, equals(PieceType.queen));
    });

    test('rejects invalid move strings', () {
      expect(() => Move<Unchecked>.parse('e2'), throwsArgumentError);
      expect(() => Move<Unchecked>.parse('xyz'), throwsArgumentError);
    });

    test('has correct legacy getters', () {
      final move = Move<Unchecked>.parse('e2e4');
      expect(move.fromRow, equals(6));  // e2 internal row
      expect(move.fromCol, equals(4));  // e2 col
      expect(move.toRow, equals(4));    // e4 internal row
      expect(move.toCol, equals(4));    // e4 col
    });

    test('toAlgebraic works', () {
      final move = Move<Unchecked>.parse('e2e4');
      expect(move.toAlgebraic(), equals('e2e4'));
    });

    test('toAlgebraic includes promotion', () {
      final move = Move<Unchecked>.parse('e7e8q');
      expect(move.toAlgebraic(), equals('e7e8q'));
    });
  });

  group('Move<Legal>', () {
    test('can be created from Unchecked', () {
      final unchecked = Move<Unchecked>.parse('e2e4');
      final legal = unchecked.promoteToLegal();
      
      expect(legal.from, equals(unchecked.from));
      expect(legal.to, equals(unchecked.to));
      expect(legal.promotion, equals(unchecked.promotion));
    });

    test('can convert back to Unchecked', () {
      final legal = Move<Legal>(
        Square.fromAlgebraic('e2'),
        Square.fromAlgebraic('e4'),
      );
      final unchecked = legal.toUnchecked();
      
      expect(unchecked.from, equals(legal.from));
      expect(unchecked.to, equals(legal.to));
    });
  });

  group('Move construction', () {
    test('can create from Square objects', () {
      final from = Square.fromAlgebraic('e2');
      final to = Square.fromAlgebraic('e4');
      final move = Move<Unchecked>(from, to);
      
      expect(move.from, equals(from));
      expect(move.to, equals(to));
    });

    test('can create from coords (legacy)', () {
      final move = Move<Unchecked>.fromCoords(6, 4, 4, 4);
      expect(move.fromRow, equals(6));
      expect(move.fromCol, equals(4));
      expect(move.toRow, equals(4));
      expect(move.toCol, equals(4));
    });

    test('equality works', () {
      final m1 = Move<Unchecked>.parse('e2e4');
      final m2 = Move<Unchecked>.parse('e2e4');
      final m3 = Move<Unchecked>.parse('d2d4');
      
      expect(m1, equals(m2));
      expect(m1, isNot(equals(m3)));
    });
  });
}
