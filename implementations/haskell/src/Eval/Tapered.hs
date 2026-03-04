module Eval.Tapered where

import Types
import Board
import Eval.Tables

computePhase :: GameState -> Int
computePhase gs =
  min totalPhase $ sum [phaseValue ptype | sq <- allSquares, Just (Piece _ ptype) <- [getPiece gs sq]]
  where
    allSquares = [Square col row | col <- [0..7], row <- [0..7]]

evaluateMaterialAndPst :: GameState -> (PieceType -> [Int]) -> Int
evaluateMaterialAndPst gs pst =
  sum [pieceScore sq piece | sq <- allSquares, Just piece <- [getPiece gs sq]]
  where
    allSquares = [Square col row | col <- [0..7], row <- [0..7]]
    pieceScore sq (Piece color ptype) =
      let base = pieceBaseValue ptype
          pstValue = squareTableValue (pst ptype) color sq
          total = base + pstValue
      in if color == White then total else -total

squareTableValue :: [Int] -> Color -> Square -> Int
squareTableValue table color (Square col row) =
  let idx = if color == White then row * 8 + col else (7 - row) * 8 + col
  in table !! idx

interpolateScore :: Int -> Int -> Int -> Int
interpolateScore phase mgScore egScore = (mgScore * scaled + egScore * (256 - scaled)) `div` 256
  where
    scaled = (phase * 256) `div` totalPhase
