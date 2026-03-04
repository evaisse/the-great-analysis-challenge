module Eval.Mobility where

import Types
import Board
import Eval.Tables

evaluateMobility :: GameState -> Int
evaluateMobility gs = sum [pieceMobilityBonus gs sq piece | sq <- allSquares, Just piece <- [getPiece gs sq]]
  where allSquares = [Square col row | col <- [0..7], row <- [0..7]]

pieceMobilityBonus :: GameState -> Square -> Piece -> Int
pieceMobilityBonus gs square piece@(Piece color ptype) =
  let count = length (generatePieceMoves gs{currentPlayer = color} piece square)
      value = case ptype of
        Knight -> clampedLookup mobilityKnight count
        Bishop -> clampedLookup mobilityBishop count
        Rook -> clampedLookup mobilityRook count
        Queen -> clampedLookup mobilityQueen count
        _ -> 0
  in if color == White then value else -value
