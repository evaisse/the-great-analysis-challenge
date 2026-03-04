module Eval.Positional where

import Types
import Board

evaluatePositional :: GameState -> Int
evaluatePositional gs =
  positionalFor White - positionalFor Black
  where
    positionalFor color = bishopPair color + rookActivity color + knightOutposts color

    allSquares = [Square col row | col <- [0..7], row <- [0..7]]
    pieces color ptype = [sq | sq <- allSquares, getPiece gs sq == Just (Piece color ptype)]

    bishopPair color = if length (pieces color Bishop) >= 2 then 30 else 0

    rookActivity color = sum [rookBonus color sq | sq <- pieces color Rook]

    rookBonus color (Square file rank) =
      let ownPawn = any (\r -> getPiece gs (Square file r) == Just (Piece color Pawn)) [0..7]
          enemyPawn = any (\r -> getPiece gs (Square file r) == Just (Piece (opponentColor color) Pawn)) [0..7]
          fileBonus = if not ownPawn && not enemyPawn then 25 else if not ownPawn then 15 else 0
          seventh = if (color == White && rank == 6) || (color == Black && rank == 1) then 20 else 0
      in fileBonus + seventh

    knightOutposts color = 20 * length [sq | sq <- pieces color Knight, isOutpost color sq]

    isOutpost color (Square file rank) =
      let inEnemyHalf = if color == White then rank >= 4 else rank <= 3
      in inEnemyHalf && protectedByPawn color (Square file rank) && not (canBeChasedByEnemyPawn color (Square file rank))

    protectedByPawn White (Square file rank) = any hasWhitePawn [(file - 1, rank - 1), (file + 1, rank - 1)]
    protectedByPawn Black (Square file rank) = any hasBlackPawn [(file - 1, rank + 1), (file + 1, rank + 1)]

    canBeChasedByEnemyPawn White (Square file rank) = any hasBlackPawn [(file - 1, rank + 1), (file + 1, rank + 1)]
    canBeChasedByEnemyPawn Black (Square file rank) = any hasWhitePawn [(file - 1, rank - 1), (file + 1, rank - 1)]

    hasWhitePawn (c, r)
      | c < 0 || c > 7 || r < 0 || r > 7 = False
      | otherwise = getPiece gs (Square c r) == Just (Piece White Pawn)

    hasBlackPawn (c, r)
      | c < 0 || c > 7 || r < 0 || r > 7 = False
      | otherwise = getPiece gs (Square c r) == Just (Piece Black Pawn)
