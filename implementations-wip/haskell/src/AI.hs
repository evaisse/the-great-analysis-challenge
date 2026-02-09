module AI where

import Types
import Board
import qualified MoveGenerator as MG
import Data.List (maximumBy, minimumBy)
import Data.Maybe (fromMaybe)

-- AI move selection with minimax and alpha-beta pruning
findBestMoveAI :: GameState -> Int -> (Move, Int, Int)  -- (move, evaluation, nodes)
findBestMoveAI gs depth =
  case MG.generateAllLegalMoves gs of
    [] -> error "No legal moves available"
    moves ->
      let isMaximizing = currentPlayer gs == White
          (bestMove, bestEval, nodes) = alphaBetaRoot moves gs depth isMaximizing (-100000) 100000 0
      in (bestMove, bestEval, nodes)

-- Alpha-beta search from root
alphaBetaRoot :: [Move] -> GameState -> Int -> Bool -> Int -> Int -> Int -> (Move, Int, Int)
alphaBetaRoot [] _ _ _ _ _ nodes = error "No moves to evaluate"
alphaBetaRoot (firstMove:otherMoves) gs depth isMaximizing alpha beta nodes =
  let newState = makeMove gs firstMove
      (eval, nodeCount) = alphaBeta newState (depth - 1) (not isMaximizing) alpha beta
      totalNodes = nodes + nodeCount + 1
  in searchBest firstMove eval totalNodes otherMoves gs depth isMaximizing alpha beta

searchBest :: Move -> Int -> Int -> [Move] -> GameState -> Int -> Bool -> Int -> Int -> (Move, Int, Int)
searchBest bestMove bestEval totalNodes [] _ _ _ _ _ = (bestMove, bestEval, totalNodes)
searchBest bestMove bestEval totalNodes (move:otherMoves) gs depth isMaximizing alpha beta =
  let newState = makeMove gs move
      (eval, nodeCount) = alphaBeta newState (depth - 1) (not isMaximizing) alpha beta
      newTotalNodes = totalNodes + nodeCount + 1
      (newBest, newBestEval, newAlpha, newBeta) = 
        if isMaximizing
        then if eval > bestEval
             then (move, eval, max alpha eval, beta)
             else (bestMove, bestEval, alpha, beta)
        else if eval < bestEval
             then (move, eval, alpha, min beta eval)
             else (bestMove, bestEval, alpha, beta)
  in if newBeta <= newAlpha
     then (newBest, newBestEval, newTotalNodes)  -- Prune
     else searchBest newBest newBestEval newTotalNodes otherMoves gs depth isMaximizing newAlpha newBeta

-- Main minimax with alpha-beta pruning
alphaBeta :: GameState -> Int -> Bool -> Int -> Int -> (Int, Int)  -- (evaluation, nodes)
alphaBeta gs depth isMaximizing alpha beta
  | depth == 0 || isGameOver gs = (evaluatePositionAI gs, 1)
  | isMaximizing = maximizeAlphaBeta (MG.generateAllLegalMoves gs) gs depth alpha beta (-100000) 1
  | otherwise = minimizeAlphaBeta (MG.generateAllLegalMoves gs) gs depth alpha beta 100000 1

maximizeAlphaBeta :: [Move] -> GameState -> Int -> Int -> Int -> Int -> Int -> (Int, Int)
maximizeAlphaBeta [] _ _ _ _ maxEval nodes = (maxEval, nodes)
maximizeAlphaBeta (move:otherMoves) gs depth alpha beta maxEval nodes =
  let newState = makeMove gs move
      (eval, childNodes) = alphaBeta newState (depth - 1) False alpha beta
      newMaxEval = max maxEval eval
      newAlpha = max alpha eval
      newNodes = nodes + childNodes
  in if beta <= newAlpha
     then (newMaxEval, newNodes)  -- Beta cutoff
     else maximizeAlphaBeta otherMoves gs depth newAlpha beta newMaxEval newNodes

minimizeAlphaBeta :: [Move] -> GameState -> Int -> Int -> Int -> Int -> Int -> (Int, Int)
minimizeAlphaBeta [] _ _ _ _ minEval nodes = (minEval, nodes)
minimizeAlphaBeta (move:otherMoves) gs depth alpha beta minEval nodes =
  let newState = makeMove gs move
      (eval, childNodes) = alphaBeta newState (depth - 1) True alpha beta
      newMinEval = min minEval eval
      newBeta = min beta eval
      newNodes = nodes + childNodes
  in if newBeta <= alpha
     then (newMinEval, newNodes)  -- Alpha cutoff
     else minimizeAlphaBeta otherMoves gs depth alpha newBeta newMinEval newNodes

-- Enhanced position evaluation (using MoveGenerator functions)
evaluatePositionAI :: GameState -> Int
evaluatePositionAI gs
  | isCheckmate gs = if currentPlayer gs == White then -100000 else 100000
  | isStalemate gs = 0
  | otherwise = 
      MG.materialBalance gs + 
      MG.positionalBonus gs +
      kingSafetyBonus gs +
      mobilityBonus gs

kingSafetyBonus :: GameState -> Int
kingSafetyBonus gs =
  let whiteKingSafety = case findKing gs White of
        Just kingPos -> if isSquareExposed gs kingPos then -20 else 0
        Nothing -> 0
      blackKingSafety = case findKing gs Black of
        Just kingPos -> if isSquareExposed gs kingPos then 20 else 0
        Nothing -> 0
  in whiteKingSafety + blackKingSafety

mobilityBonus :: GameState -> Int
mobilityBonus gs =
  let whiteMobility = length (MG.generateAllLegalMoves gs)
      blackMobility = length (MG.generateAllLegalMoves (makeMove gs (Move (Square 0 0) (Square 0 0) Nothing)))  -- Simplified
  in if currentPlayer gs == White 
     then whiteMobility - blackMobility
     else blackMobility - whiteMobility

isSquareExposed :: GameState -> Square -> Bool
isSquareExposed gs square =
  let adjacentSquares = [Square (col + dc) (row + dr) | 
        Square col row <- [square],
        (dc, dr) <- [(-1,-1), (-1,0), (-1,1), (0,-1), (0,1), (1,-1), (1,0), (1,1)],
        col + dc >= 0 && col + dc <= 7 && row + dr >= 0 && row + dr <= 7]
      hasProtection = any (\sq -> case getPiece gs sq of
        Just (Piece color _) -> color == (case getPiece gs square of
          Just (Piece c _) -> c
          Nothing -> White)  -- Default
        Nothing -> False) adjacentSquares
  in not hasProtection

isGameOver :: GameState -> Bool
isGameOver gs = isCheckmate gs || isStalemate gs

-- Move ordering for better alpha-beta performance
orderMoves :: GameState -> [Move] -> [Move]
orderMoves gs moves = 
  let scoredMoves = [(move, scoreMoveForOrdering gs move) | move <- moves]
      sortedMoves = sortByScore scoredMoves
  in map fst sortedMoves

scoreMoveForOrdering :: GameState -> Move -> Int
scoreMoveForOrdering gs move@(Move from to _) =
  let captureScore = case getPiece gs to of
        Just (Piece _ capturedType) -> MG.pieceValue (Piece White capturedType)
        Nothing -> 0
      promotionScore = case promotion move of
        Just Queen -> 900
        Just Rook -> 500
        Just Bishop -> 330
        Just Knight -> 320
        Nothing -> 0
      checkScore = if wouldGiveCheck gs move then 50 else 0
  in captureScore + promotionScore + checkScore

pieceTypeValue :: PieceType -> Int
pieceTypeValue ptype = MG.pieceValue (Piece White ptype)

wouldGiveCheck :: GameState -> Move -> Bool
wouldGiveCheck gs move =
  let newState = makeMove gs move
  in isInCheck newState (opponentColor (currentPlayer gs))

sortByScore :: [(Move, Int)] -> [(Move, Int)]
sortByScore [] = []
sortByScore (x:xs) = 
  let smaller = sortByScore [a | a <- xs, snd a <= snd x]
      larger = sortByScore [a | a <- xs, snd a > snd x]
  in larger ++ [x] ++ smaller