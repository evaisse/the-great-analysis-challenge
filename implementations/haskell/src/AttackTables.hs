module AttackTables where

import Data.Array (Array, (!), listArray)
import Types

type Delta = (Int, Int)

knightDeltas :: [Delta]
knightDeltas = [(2, 1), (2, -1), (-2, 1), (-2, -1), (1, 2), (1, -2), (-1, 2), (-1, -2)]

kingDeltas :: [Delta]
kingDeltas =
  [ (1, 1)
  , (1, -1)
  , (-1, 1)
  , (-1, -1)
  , (0, 1)
  , (0, -1)
  , (1, 0)
  , (-1, 0)
  ]

bishopDeltas :: [Delta]
bishopDeltas = [(1, 1), (1, -1), (-1, 1), (-1, -1)]

rookDeltas :: [Delta]
rookDeltas = [(0, 1), (0, -1), (1, 0), (-1, 0)]

queenDeltas :: [Delta]
queenDeltas = bishopDeltas ++ rookDeltas

isInBounds :: Int -> Int -> Bool
isInBounds col row = col >= 0 && col <= 7 && row >= 0 && row <= 7

squareIndex :: Square -> Int
squareIndex (Square col row) = row * 8 + col

indexSquare :: Int -> Square
indexSquare index = Square (index `mod` 8) (index `div` 8)

buildAttackTable :: [Delta] -> Array Int [Square]
buildAttackTable deltas =
  listArray (0, 63)
    [ [ Square (col + dc) (row + dr)
      | (dc, dr) <- deltas
      , isInBounds (col + dc) (row + dr)
      ]
    | row <- [0 .. 7]
    , col <- [0 .. 7]
    ]

buildRay :: Square -> Delta -> [Square]
buildRay (Square col row) (dc, dr) = go (col + dc) (row + dr)
  where
    go nextCol nextRow
      | isInBounds nextCol nextRow = Square nextCol nextRow : go (nextCol + dc) (nextRow + dr)
      | otherwise = []

buildRayTable :: [Delta] -> Array Int [[Square]]
buildRayTable deltas =
  listArray (0, 63)
    [ [buildRay (Square col row) delta | delta <- deltas]
    | row <- [0 .. 7]
    , col <- [0 .. 7]
    ]

buildDistanceTable :: (Int -> Int -> Int) -> Array (Int, Int) Int
buildDistanceTable metric =
  listArray ((0, 0), (63, 63))
    [ metric (abs (fromCol - toCol)) (abs (fromRow - toRow))
    | fromIdx <- [0 .. 63]
    , toIdx <- [0 .. 63]
    , let Square fromCol fromRow = indexSquare fromIdx
    , let Square toCol toRow = indexSquare toIdx
    ]

knightAttackTable :: Array Int [Square]
knightAttackTable = buildAttackTable knightDeltas

kingAttackTable :: Array Int [Square]
kingAttackTable = buildAttackTable kingDeltas

bishopRayTable :: Array Int [[Square]]
bishopRayTable = buildRayTable bishopDeltas

rookRayTable :: Array Int [[Square]]
rookRayTable = buildRayTable rookDeltas

queenRayTable :: Array Int [[Square]]
queenRayTable = buildRayTable queenDeltas

chebyshevDistanceTable :: Array (Int, Int) Int
chebyshevDistanceTable = buildDistanceTable max

manhattanDistanceTable :: Array (Int, Int) Int
manhattanDistanceTable = buildDistanceTable (+)

knightAttacks :: Square -> [Square]
knightAttacks square = knightAttackTable ! squareIndex square

kingAttacks :: Square -> [Square]
kingAttacks square = kingAttackTable ! squareIndex square

bishopRays :: Square -> [[Square]]
bishopRays square = bishopRayTable ! squareIndex square

rookRays :: Square -> [[Square]]
rookRays square = rookRayTable ! squareIndex square

queenRays :: Square -> [[Square]]
queenRays square = queenRayTable ! squareIndex square

chebyshevDistance :: Square -> Square -> Int
chebyshevDistance from to = chebyshevDistanceTable ! (squareIndex from, squareIndex to)

manhattanDistance :: Square -> Square -> Int
manhattanDistance from to = manhattanDistanceTable ! (squareIndex from, squareIndex to)
