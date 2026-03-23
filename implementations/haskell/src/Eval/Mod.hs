module Eval.Mod where

import AttackTables
import Types
import Board
import qualified MoveGenerator as MG
import Eval.Tables
import Eval.Tapered
import Eval.Mobility
import Eval.PawnStructure
import Eval.KingSafety
import Eval.Positional

evaluateSimplePosition :: GameState -> Int
evaluateSimplePosition = MG.evaluatePosition

evaluateRichPosition :: GameState -> Int
evaluateRichPosition gs
  | isCheckmate gs = if currentPlayer gs == White then -100000 else 100000
  | isStalemate gs = 0
  | otherwise = interpolateScore phase mgScore egScore
  where
    allSquares = [Square col row | col <- [0 .. 7], row <- [0 .. 7]]
    phase = computePhase gs
    mgScore = evaluateMaterialAndPst gs mgPst
      + evaluateMobility gs
      + evaluatePawnStructure gs
      + evaluateKingSafety gs
      + evaluatePositional gs
    egScore = evaluateMaterialAndPst gs egPst
      + (evaluateMobility gs * 3 `div` 4)
      + evaluatePawnStructure gs
      + (evaluateKingSafety gs `div` 2)
      + evaluatePositional gs
      + endgameKingBonus

    nonPawnPieces =
      length
        [ ()
        | square <- allSquares
        , Just (Piece _ ptype) <- [getPiece gs square]
        , ptype /= Pawn
        , ptype /= King
        ]

    queenCount =
      length
        [ ()
        | square <- allSquares
        , Just (Piece _ Queen) <- [getPiece gs square]
        ]

    endgameKingBonus =
      if nonPawnPieces <= 4 || (nonPawnPieces <= 6 && queenCount == 0)
        then case (findKing gs White, findKing gs Black) of
          (Just whiteKingSquare, Just blackKingSquare) -> 14 - manhattanDistance whiteKingSquare blackKingSquare
          _ -> 0
        else 0

evaluatePosition :: Bool -> GameState -> Int
evaluatePosition useRich gs = if useRich then evaluateRichPosition gs else evaluateSimplePosition gs
