/// Type-safe game state using sealed classes.
/// Encodes whose turn it is at the type level.

import 'piece.dart';

/// Base sealed class for game state.
/// Ensures exhaustive pattern matching.
sealed class GameState {
  const GameState();
  
  /// Get the color whose turn it is.
  Color get activeColor;
  
  /// Get the opposite state.
  GameState get nextState;
}

/// White to move state.
final class WhiteToMove extends GameState {
  const WhiteToMove();
  
  @override
  Color get activeColor => white;
  
  @override
  GameState get nextState => const BlackToMove();
  
  @override
  bool operator ==(Object other) => other is WhiteToMove;
  
  @override
  int get hashCode => 0;
  
  @override
  String toString() => 'WhiteToMove';
}

/// Black to move state.
final class BlackToMove extends GameState {
  const BlackToMove();
  
  @override
  Color get activeColor => black;
  
  @override
  GameState get nextState => const WhiteToMove();
  
  @override
  bool operator ==(Object other) => other is BlackToMove;
  
  @override
  int get hashCode => 1;
  
  @override
  String toString() => 'BlackToMove';
}

/// Singleton state instances.
const whiteToMove = WhiteToMove();
const blackToMove = BlackToMove();

/// Parse game state from color symbol.
GameState gameStateFromColor(String symbol) {
  return symbol == 'w' ? whiteToMove : blackToMove;
}

/// Parse game state from Color.
GameState gameStateFromColorType(Color color) {
  return color is White ? whiteToMove : blackToMove;
}
