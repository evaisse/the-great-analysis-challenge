module Eval.Tables where

import Types

phaseValue :: PieceType -> Int
phaseValue Pawn = 0
phaseValue Knight = 1
phaseValue Bishop = 1
phaseValue Rook = 2
phaseValue Queen = 4
phaseValue King = 0

totalPhase :: Int
totalPhase = 24

pieceBaseValue :: PieceType -> Int
pieceBaseValue Pawn = 100
pieceBaseValue Knight = 320
pieceBaseValue Bishop = 330
pieceBaseValue Rook = 500
pieceBaseValue Queen = 900
pieceBaseValue King = 20000

mobilityKnight :: [Int]
mobilityKnight = [-15, -5, 0, 5, 10, 15, 20, 22, 24]

mobilityBishop :: [Int]
mobilityBishop = [-20, -10, 0, 5, 10, 15, 18, 21, 24, 26, 28, 30, 32, 34]

mobilityRook :: [Int]
mobilityRook = [-15, -8, 0, 3, 6, 9, 12, 14, 16, 18, 20, 22, 24, 26, 28]

mobilityQueen :: [Int]
mobilityQueen = [-10, -5, 0, 2, 4, 6, 8, 10, 12, 13, 14, 15, 16, 17, 18, 19,
                 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31]

passedPawnBonusByRank :: [Int]
passedPawnBonusByRank = [0, 10, 20, 40, 60, 90, 120, 0]

mgPst :: PieceType -> [Int]
mgPst Pawn =
  [ 0,  0,  0,  0,  0,  0,  0,  0
  , 5, 10, 10,-20,-20, 10, 10,  5
  , 5, -5,-10,  0,  0,-10, -5,  5
  , 0,  0,  0, 20, 20,  0,  0,  0
  , 5,  5, 10, 25, 25, 10,  5,  5
  ,10, 10, 20, 30, 30, 20, 10, 10
  ,50, 50, 50, 50, 50, 50, 50, 50
  , 0,  0,  0,  0,  0,  0,  0,  0 ]
mgPst Knight =
  [-50,-40,-30,-30,-30,-30,-40,-50
  ,-40,-20,  0,  0,  0,  0,-20,-40
  ,-30,  0, 10, 15, 15, 10,  0,-30
  ,-30,  5, 15, 20, 20, 15,  5,-30
  ,-30,  0, 15, 20, 20, 15,  0,-30
  ,-30,  5, 10, 15, 15, 10,  5,-30
  ,-40,-20,  0,  5,  5,  0,-20,-40
  ,-50,-40,-30,-30,-30,-30,-40,-50 ]
mgPst Bishop =
  [-20,-10,-10,-10,-10,-10,-10,-20
  ,-10,  0,  0,  0,  0,  0,  0,-10
  ,-10,  0,  5, 10, 10,  5,  0,-10
  ,-10,  5,  5, 10, 10,  5,  5,-10
  ,-10,  0, 10, 10, 10, 10,  0,-10
  ,-10, 10, 10, 10, 10, 10, 10,-10
  ,-10,  5,  0,  0,  0,  0,  5,-10
  ,-20,-10,-10,-10,-10,-10,-10,-20 ]
mgPst Rook =
  [ 0,  0,  0,  5,  5,  0,  0,  0
  ,-5,  0,  0,  0,  0,  0,  0, -5
  ,-5,  0,  0,  0,  0,  0,  0, -5
  ,-5,  0,  0,  0,  0,  0,  0, -5
  ,-5,  0,  0,  0,  0,  0,  0, -5
  ,-5,  0,  0,  0,  0,  0,  0, -5
  , 5, 10, 10, 10, 10, 10, 10,  5
  , 0,  0,  0,  0,  0,  0,  0,  0 ]
mgPst Queen =
  [-20,-10,-10, -5, -5,-10,-10,-20
  ,-10,  0,  0,  0,  0,  0,  0,-10
  ,-10,  0,  5,  5,  5,  5,  0,-10
  , -5,  0,  5,  5,  5,  5,  0, -5
  ,  0,  0,  5,  5,  5,  5,  0, -5
  ,-10,  5,  5,  5,  5,  5,  0,-10
  ,-10,  0,  5,  0,  0,  0,  0,-10
  ,-20,-10,-10, -5, -5,-10,-10,-20 ]
mgPst King =
  [-30,-40,-40,-50,-50,-40,-40,-30
  ,-30,-40,-40,-50,-50,-40,-40,-30
  ,-30,-40,-40,-50,-50,-40,-40,-30
  ,-30,-40,-40,-50,-50,-40,-40,-30
  ,-20,-30,-30,-40,-40,-30,-30,-20
  ,-10,-20,-20,-20,-20,-20,-20,-10
  , 20, 20,  0,  0,  0,  0, 20, 20
  , 20, 30, 10,  0,  0, 10, 30, 20 ]

egPst :: PieceType -> [Int]
egPst Pawn = mgPst Pawn
egPst Knight = mgPst Knight
egPst Bishop = mgPst Bishop
egPst Rook = mgPst Rook
egPst Queen = mgPst Queen
egPst King =
  [-50,-30,-30,-30,-30,-30,-30,-50
  ,-30,-20,-10,-10,-10,-10,-20,-30
  ,-30,-10, 20, 30, 30, 20,-10,-30
  ,-30,-10, 30, 40, 40, 30,-10,-30
  ,-30,-10, 30, 40, 40, 30,-10,-30
  ,-30,-10, 20, 30, 30, 20,-10,-30
  ,-30,-30,  0,  0,  0,  0,-30,-30
  ,-50,-30,-30,-30,-30,-30,-30,-50 ]

clampedLookup :: [Int] -> Int -> Int
clampedLookup table idx = table !! max 0 (min (length table - 1) idx)
