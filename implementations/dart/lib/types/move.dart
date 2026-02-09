/// Type-safe move representation with Legal/Unchecked states.

import 'square.dart';
import 'piece.dart';

/// Base sealed class for move validation state.
sealed class MoveValidation {
  const MoveValidation();
}

/// Legal move - has been validated by the chess engine.
final class Legal extends MoveValidation {
  const Legal();
  
  @override
  bool operator ==(Object other) => other is Legal;
  
  @override
  int get hashCode => 0;
}

/// Unchecked move - parsed from input but not yet validated.
final class Unchecked extends MoveValidation {
  const Unchecked();
  
  @override
  bool operator ==(Object other) => other is Unchecked;
  
  @override
  int get hashCode => 1;
}

/// Singleton validation instances.
const legal = Legal();
const unchecked = Unchecked();

/// Type-safe move with validation state.
/// Move<Legal> can only be created after validation.
/// Move<Unchecked> is created when parsing user input.
class Move<V extends MoveValidation> {
  final Square from;
  final Square to;
  final PieceType? promotion;
  
  const Move(this.from, this.to, {this.promotion});
  
  /// Legacy constructor for backward compatibility (row/col based).
  Move.fromCoords(int fromRow, int fromCol, int toRow, int toCol, {this.promotion})
      : from = Square.fromRowCol(fromRow, fromCol),
        to = Square.fromRowCol(toRow, toCol);
  
  /// Parse move from algebraic notation (e.g., "e2e4" or "e7e8q").
  /// Returns Move<Unchecked> since it hasn't been validated yet.
  factory Move.parse(String moveStr) {
    if (moveStr.length < 4) {
      throw ArgumentError('Move string too short: $moveStr');
    }
    final from = Square.fromAlgebraic(moveStr.substring(0, 2));
    final to = Square.fromAlgebraic(moveStr.substring(2, 4));
    PieceType? promotion;
    if (moveStr.length == 5) {
      promotion = PieceType.fromChar(moveStr.substring(4));
    }
    return Move<Unchecked>(from, to, promotion: promotion);
  }
  
  /// Promote an unchecked move to a legal move.
  /// This should only be called after validation.
  Move<Legal> promoteToLegal() {
    return Move<Legal>(from, to, promotion: promotion);
  }
  
  /// Convert back to unchecked (useful for testing).
  Move<Unchecked> toUnchecked() {
    return Move<Unchecked>(from, to, promotion: promotion);
  }
  
  /// Convert to algebraic notation string.
  String toAlgebraic() {
    final promotionStr = promotion != null ? promotion!.char : '';
    return '${from.toAlgebraic()}${to.toAlgebraic()}$promotionStr';
  }
  
  /// Legacy compatibility: get from row.
  int get fromRow => from.row;
  
  /// Legacy compatibility: get from col.
  int get fromCol => from.col;
  
  /// Legacy compatibility: get to row.
  int get toRow => to.row;
  
  /// Legacy compatibility: get to col.
  int get toCol => to.col;
  
  @override
  bool operator ==(Object other) {
    return other is Move && from == other.from && to == other.to && promotion == other.promotion;
  }
  
  @override
  int get hashCode => Object.hash(from, to, promotion);
  
  @override
  String toString() => toAlgebraic();
}

