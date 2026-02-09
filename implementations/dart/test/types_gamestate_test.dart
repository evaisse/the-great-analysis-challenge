import 'package:test/test.dart';
import 'package:chess_engine/types/types.dart';

void main() {
  group('GameState', () {
    test('WhiteToMove has correct properties', () {
      expect(whiteToMove.activeColor, equals(white));
      expect(whiteToMove.nextState, equals(blackToMove));
    });

    test('BlackToMove has correct properties', () {
      expect(blackToMove.activeColor, equals(black));
      expect(blackToMove.nextState, equals(whiteToMove));
    });

    test('states alternate correctly', () {
      var state = whiteToMove;
      expect(state, equals(whiteToMove));
      
      state = state.nextState;
      expect(state, equals(blackToMove));
      
      state = state.nextState;
      expect(state, equals(whiteToMove));
    });

    test('gameStateFromColor works', () {
      expect(gameStateFromColor('w'), equals(whiteToMove));
      expect(gameStateFromColor('b'), equals(blackToMove));
    });

    test('gameStateFromColorType works', () {
      expect(gameStateFromColorType(white), equals(whiteToMove));
      expect(gameStateFromColorType(black), equals(blackToMove));
    });

    test('pattern matching is exhaustive', () {
      String describe(GameState state) {
        return switch (state) {
          WhiteToMove() => 'White to move',
          BlackToMove() => 'Black to move',
        };
      }

      expect(describe(whiteToMove), equals('White to move'));
      expect(describe(blackToMove), equals('Black to move'));
    });
  });
}
