module Perft where

import Types
import Board
import MoveGenerator

-- Performance test - count leaf nodes at given depth
perft :: GameState -> Int -> Int
perft gs 0 = 1
perft gs depth = sum [perft (makeMove gs move) (depth - 1) | move <- generateAllLegalMoves gs]

-- Divide perft - shows move breakdown at root
perftDivide :: GameState -> Int -> [(String, Int)]
perftDivide gs depth = 
  [(formatMove move, perft (makeMove gs move) (depth - 1)) | move <- generateAllLegalMoves gs]

-- Perft with debugging information
perftDebug :: GameState -> Int -> IO Int
perftDebug gs depth = do
  let moves = generateAllLegalMoves gs
  putStrLn $ "Depth " ++ show depth ++ ", moves: " ++ show (length moves)
  if depth == 0
    then return 1
    else do
      results <- mapM (\move -> do
        let newState = makeMove gs move
        result <- perftDebug newState (depth - 1)
        putStrLn $ formatMove move ++ ": " ++ show result
        return result) moves
      return (sum results)

-- Bulk perft testing with known results
runPerftTests :: GameState -> IO ()
runPerftTests gs = do
  putStrLn "Running perft tests from starting position:"
  mapM_ runTest [(1, 20), (2, 400), (3, 8902), (4, 197281)]
  where
    runTest (depth, expected) = do
      let result = perft gs depth
      let status = if result == expected then "PASS" else "FAIL"
      putStrLn $ "Perft(" ++ show depth ++ "): " ++ show result ++ 
                " (expected " ++ show expected ++ ") " ++ status

-- Perft from specific positions
testPositions :: [(String, String, [(Int, Int)])]
testPositions = 
  [ ("Starting position", 
     "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
     [(1, 20), (2, 400), (3, 8902), (4, 197281), (5, 4865609)])
  , ("Kiwipete position",
     "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
     [(1, 6), (2, 264), (3, 9467), (4, 422333)])
  , ("Position 3",
     "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1",
     [(1, 14), (2, 191), (3, 2812), (4, 43238)])
  , ("Position 4", 
     "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1",
     [(1, 26), (2, 568), (3, 13744), (4, 314346)])
  , ("Position 5",
     "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8",
     [(1, 44), (2, 1486), (3, 62379)])
  , ("Position 6",
     "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10",
     [(1, 46), (2, 2079), (3, 89890)])
  ]