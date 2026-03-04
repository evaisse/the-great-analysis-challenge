module Eval.PawnStructure where

import Types
import Board
import Eval.Tables
import Data.List (group, sort)

evaluatePawnStructure :: GameState -> Int
evaluatePawnStructure gs =
  scoreFor White - scoreFor Black
  where
    scoreFor color =
      doubledPenalty color + isolatedPenalty color + passedBonus color + chainBonus color + connectedBonus color
    pawns color = [sq | sq <- allSquares, getPiece gs sq == Just (Piece color Pawn)]
    allSquares = [Square col row | col <- [0..7], row <- [0..7]]

    doubledPenalty color =
      let files = sort [c | Square c _ <- pawns color]
          excess = sum [max 0 (length grp - 1) | grp <- group files]
      in excess * (-20)

    isolatedPenalty color =
      let ps = pawns color
      in (-15) * length [sq | sq@(Square c _) <- ps, not (hasPawnOnAdjacentFile ps c)]

    passedBonus color =
      sum [passedPawnValue color sq | sq <- pawns color, isPassedPawn color sq]

    chainBonus color =
      10 * length [sq | sq <- pawns color, isPawnDefendedByPawn color sq]

    connectedBonus color =
      5 * length [sq | sq <- pawns color, isConnectedPawn color sq]

    hasPawnOnAdjacentFile ps file = any (\(Square c _) -> abs (c - file) == 1) ps

    isPassedPawn color (Square col row) =
      let enemy = opponentColor color
          rows = if color == White then [row + 1 .. 7] else [0 .. row - 1]
          files = [max 0 (col - 1) .. min 7 (col + 1)]
      in not (any (\(c, r) -> getPiece gs (Square c r) == Just (Piece enemy Pawn)) [(c, r) | c <- files, r <- rows])

    passedPawnValue White (Square _ row) = clampedLookup passedPawnBonusByRank row
    passedPawnValue Black (Square _ row) = clampedLookup passedPawnBonusByRank (7 - row)

    isPawnDefendedByPawn White (Square col row) = any (hasPawnColor White) [(col - 1, row - 1), (col + 1, row - 1)]
    isPawnDefendedByPawn Black (Square col row) = any (hasPawnColor Black) [(col - 1, row + 1), (col + 1, row + 1)]

    isConnectedPawn color (Square col row) =
      any hasPawn [(col - 1, row), (col + 1, row)]
      where
        hasPawn (c, r)
          | c < 0 || c > 7 || r < 0 || r > 7 = False
          | otherwise = getPiece gs (Square c r) == Just (Piece color Pawn)

    hasPawnColor color (c, r)
      | c < 0 || c > 7 || r < 0 || r > 7 = False
      | otherwise = getPiece gs (Square c r) == Just (Piece color Pawn)
