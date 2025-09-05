module Main where

import Types
import Board
import FEN
import qualified MoveGenerator as MG
import AI
import Perft
import System.IO (stdout, hFlush)
import Data.Maybe (fromMaybe, isJust, fromJust)
import Control.Monad (when)
import qualified Control.Exception
import Data.Time (getCurrentTime, diffUTCTime)

-- Main game state
data ChessEngine = ChessEngine
  { gameState :: GameState
  , moveHistory :: [GameState]
  }

main :: IO ()
main = do
  let engine = ChessEngine initialGameState []
  putStrLn $ displayBoard (gameState engine)
  gameLoop engine

gameLoop :: ChessEngine -> IO ()
gameLoop engine = do
  putStr ""
  hFlush stdout
  result <- Control.Exception.try getLine :: IO (Either Control.Exception.IOException String)
  case result of
    Left _ -> return ()  -- EOF or any IO exception
    Right line -> do
      let command = words line
      newEngine <- processCommand engine command
      case newEngine of
        Nothing -> return ()  -- Quit
        Just engine' -> do
          when (isJust newEngine) $ do
            let gs = gameState engine'
            when (isCheckmate gs || isStalemate gs) $ do
              if isCheckmate gs
                then putStrLn $ "CHECKMATE: " ++ show (opponentColor (currentPlayer gs)) ++ " wins"
                else putStrLn "STALEMATE: Draw"
          gameLoop engine'

processCommand :: ChessEngine -> [String] -> IO (Maybe ChessEngine)
processCommand engine [] = return (Just engine)

processCommand engine ["quit"] = return Nothing

processCommand engine ["help"] = do
  putStrLn "Available commands:"
  putStrLn "  move <from><to>[promotion] - Make a move (e.g., move e2e4, move e7e8Q)"
  putStrLn "  undo                       - Undo the last move"
  putStrLn "  new                        - Start a new game"
  putStrLn "  ai <depth>                 - AI makes a move (depth 1-5)"
  putStrLn "  fen <string>               - Load position from FEN"
  putStrLn "  export                     - Export current position as FEN"
  putStrLn "  eval                       - Display position evaluation"
  putStrLn "  perft <depth>              - Performance test (move count)"
  putStrLn "  help                       - Display available commands"
  putStrLn "  quit                       - Exit the program"
  return (Just engine)

processCommand engine ["new"] = do
  let newEngine = ChessEngine initialGameState []
  putStrLn $ displayBoard (gameState newEngine)
  return (Just newEngine)

processCommand engine ["move", moveStr] = do
  case MG.parseMove moveStr of
    Nothing -> do
      putStrLn "ERROR: Invalid move format"
      return (Just engine)
    Just move -> do
      let gs = gameState engine
      if isValidMove gs move
        then do
          let newState = makeMove gs move
          let newEngine = ChessEngine newState (gs : moveHistory engine)
          putStrLn $ "OK: " ++ moveStr
          putStrLn $ displayBoard newState
          return (Just newEngine)
        else do
          let errorMsg = case getPiece gs (fromSquare move) of
                Nothing -> "No piece at source square"
                Just piece -> 
                  if pieceColor piece /= currentPlayer gs
                    then "Wrong color piece"
                    else if wouldBeInCheck gs move
                      then "King would be in check"
                      else "Illegal move"
          putStrLn $ "ERROR: " ++ errorMsg
          return (Just engine)

processCommand engine ["undo"] = do
  case moveHistory engine of
    [] -> do
      putStrLn "ERROR: No moves to undo"
      return (Just engine)
    (prevState:restHistory) -> do
      let newEngine = ChessEngine prevState restHistory
      putStrLn $ displayBoard prevState
      return (Just newEngine)

processCommand engine ["ai", depthStr] = do
  case reads depthStr of
    [(depth, "")] | depth >= 1 && depth <= 5 -> do
      let gs = gameState engine
      if null (MG.generateAllLegalMoves gs)
        then do
          putStrLn "ERROR: No legal moves available"
          return (Just engine)
        else do
          startTime <- getCurrentTime
          let (bestMove, evaluation, nodes) = findBestMoveAI gs depth
          endTime <- getCurrentTime
          let timeTaken = round $ 1000 * realToFrac (diffUTCTime endTime startTime)
          let newState = makeMove gs bestMove
          let newEngine = ChessEngine newState (gs : moveHistory engine)
          putStrLn $ "AI: " ++ MG.formatMove bestMove ++ 
                    " (depth=" ++ show depth ++ 
                    ", eval=" ++ show evaluation ++ 
                    ", time=" ++ show timeTaken ++ "ms)"
          putStrLn $ displayBoard newState
          return (Just newEngine)
    _ -> do
      putStrLn "ERROR: AI depth must be 1-5"
      return (Just engine)

processCommand engine ["fen", fenStr] = do
  case parseFEN fenStr of
    Nothing -> do
      putStrLn "ERROR: Invalid FEN string"
      return (Just engine)
    Just newState -> do
      let newEngine = ChessEngine newState []
      putStrLn $ displayBoard newState
      return (Just newEngine)

processCommand engine ["export"] = do
  let fenStr = exportFEN (gameState engine)
  putStrLn $ "FEN: " ++ fenStr
  return (Just engine)

processCommand engine ["eval"] = do
  let gs = gameState engine
  let evaluation = MG.evaluatePosition gs
  putStrLn $ "Evaluation: " ++ show evaluation ++ " (positive = White advantage)"
  return (Just engine)

processCommand engine ["perft", depthStr] = do
  case reads depthStr of
    [(depth, "")] | depth >= 1 && depth <= 6 -> do
      let gs = gameState engine
      startTime <- getCurrentTime
      let result = perft gs depth
      endTime <- getCurrentTime
      let timeTaken = round $ 1000 * realToFrac (diffUTCTime endTime startTime)
      putStrLn $ show result
      return (Just engine)
    _ -> do
      putStrLn "ERROR: Perft depth must be 1-6"
      return (Just engine)

processCommand engine command = do
  putStrLn "ERROR: Invalid command"
  return (Just engine)

-- Helper to check if move gives check
wouldGiveCheck :: GameState -> Move -> Bool
wouldGiveCheck gs move =
  let newState = makeMove gs move
  in isInCheck newState (opponentColor (currentPlayer gs))