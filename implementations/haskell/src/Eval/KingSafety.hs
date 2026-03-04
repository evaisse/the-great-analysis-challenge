module Eval.KingSafety where

import Types
import Board

evaluateKingSafety :: GameState -> Int
evaluateKingSafety gs =
  kingScore White - kingScore Black
  where
    kingScore color =
      case findKing gs color of
        Nothing -> 0
        Just ksq -> shieldBonus color ksq - openFilePenalty color ksq - attackerWeight * attackerCount color ksq

    attackerWeight = 12

    shieldBonus White (Square file rank) =
      12 * length [() | f <- [file - 1 .. file + 1], f >= 0, f <= 7, getPiece gs (Square f (rank + 1)) == Just (Piece White Pawn)]
    shieldBonus Black (Square file rank) =
      12 * length [() | f <- [file - 1 .. file + 1], f >= 0, f <= 7, getPiece gs (Square f (rank - 1)) == Just (Piece Black Pawn)]

    openFilePenalty color (Square file _) =
      let ownPawn = any (\r -> getPiece gs (Square file r) == Just (Piece color Pawn)) [0..7]
          enemyPawn = any (\r -> getPiece gs (Square file r) == Just (Piece (opponentColor color) Pawn)) [0..7]
      in if not ownPawn && not enemyPawn then 30 else if not ownPawn then 15 else 0

    attackerCount color ksq =
      let enemy = opponentColor color
      in length [sq | sq <- kingZone ksq, isSquareAttacked gs enemy sq]

    kingZone (Square file rank) =
      [Square f r | f <- [file - 1 .. file + 1], r <- [rank - 1 .. rank + 1], f >= 0, f <= 7, r >= 0, r <= 7]
