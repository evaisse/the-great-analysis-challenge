import 'package:test/test.dart';
import 'package:chess_engine/chess_engine.dart';

void main() {
  test('new game starts at initial position', () {
    final game = Game();
    expect(
      game.board.toFen(),
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    );
  });
}
