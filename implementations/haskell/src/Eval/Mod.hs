module Eval.Mod where

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

evaluatePosition :: Bool -> GameState -> Int
evaluatePosition useRich gs = if useRich then evaluateRichPosition gs else evaluateSimplePosition gs
