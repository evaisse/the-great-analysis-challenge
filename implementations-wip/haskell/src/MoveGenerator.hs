module MoveGenerator where

import Types
import Board
import Data.List (find)
import Data.Maybe (mapMaybe)

-- Parse move from string (e.g., "e2e4", "e7e8Q")
parseMove :: String -> Maybe Move
parseMove moveStr =
  case moveStr of
    [fc, fr, tc, tr] -> do
      from <- squareFromString [fc, fr]
      to <- squareFromString [tc, tr]
      return $ Move from to Nothing
    [fc, fr, tc, tr, p] -> do
      from <- squareFromString [fc, fr]
      to <- squareFromString [tc, tr]
      promotion <- parsePromotion p
      return $ Move from to (Just promotion)
    _ -> Nothing

parsePromotion :: Char -> Maybe PieceType
parsePromotion 'Q' = Just Queen
parsePromotion 'R' = Just Rook
parsePromotion 'B' = Just Bishop
parsePromotion 'N' = Just Knight
parsePromotion 'q' = Just Queen
parsePromotion 'r' = Just Rook
parsePromotion 'b' = Just Bishop
parsePromotion 'n' = Just Knight
parsePromotion _ = Nothing

-- Format move as string
formatMove :: Move -> String
formatMove (Move from to Nothing) = show from ++ show to
formatMove (Move from to (Just promotion)) = show from ++ show to ++ [promotionChar promotion]

promotionChar :: PieceType -> Char
promotionChar Queen = 'Q'
promotionChar Rook = 'R'
promotionChar Bishop = 'B'
promotionChar Knight = 'N'
promotionChar _ = 'Q'  -- Default to Queen

-- Generate all legal moves for current player
generateAllLegalMoves :: GameState -> [Move]
generateAllLegalMoves = generateLegalMoves

-- Find the best move using minimax (simplified version for move generation)
findBestMove :: GameState -> Int -> Move
findBestMove gs depth =
  case generateAllLegalMoves gs of
    [] -> error "No legal moves available"
    moves -> 
      let evaluatedMoves = [(move, evaluateMove gs move depth) | move <- moves]
          bestMove = if currentPlayer gs == White
                    then maximumBy (\(_, a) (_, b) -> compare a b) evaluatedMoves
                    else minimumBy (\(_, a) (_, b) -> compare a b) evaluatedMoves
      in fst bestMove

-- Simple move evaluation (placeholder for full AI)
evaluateMove :: GameState -> Move -> Int -> Int
evaluateMove gs move depth =
  let newState = makeMove gs move
  in if depth <= 0
     then evaluatePosition newState
     else evaluatePosition newState  -- Simplified - full minimax in AI module

-- Basic position evaluation
evaluatePosition :: GameState -> Int
evaluatePosition gs =
  if isCheckmate gs
    then if currentPlayer gs == White then -100000 else 100000
  else if isStalemate gs
    then 0
  else materialBalance gs + positionalBonus gs

materialBalance :: GameState -> Int
materialBalance gs = sum [pieceValue piece | 
  col <- [0..7], row <- [0..7],
  Just piece <- [getPiece gs (Square col row)]]

pieceValue :: Piece -> Int
pieceValue (Piece color ptype) =
  let value = case ptype of
        Pawn -> 100
        Knight -> 320
        Bishop -> 330
        Rook -> 500
        Queen -> 900
        King -> 20000
  in if color == White then value else -value

positionalBonus :: GameState -> Int
positionalBonus gs = centerControlBonus gs + pawnAdvancementBonus gs

centerControlBonus :: GameState -> Int
centerControlBonus gs =
  let centerSquares = [Square 3 3, Square 3 4, Square 4 3, Square 4 4]
      bonus square = case getPiece gs square of
        Just (Piece White _) -> 10
        Just (Piece Black _) -> -10
        Nothing -> 0
  in sum (map bonus centerSquares)

pawnAdvancementBonus :: GameState -> Int
pawnAdvancementBonus gs = sum [pawnBonus col row piece |
  col <- [0..7], row <- [0..7],
  Just piece@(Piece _ Pawn) <- [getPiece gs (Square col row)]]
  where
    pawnBonus col row (Piece White Pawn) = row * 5
    pawnBonus col row (Piece Black Pawn) = (7 - row) * 5
    pawnBonus _ _ _ = 0

-- Utility functions for comparison
maximumBy :: (a -> a -> Ordering) -> [a] -> a
maximumBy _ [] = error "maximumBy: empty list"
maximumBy cmp (x:xs) = foldl (\acc y -> if cmp acc y == LT then y else acc) x xs

minimumBy :: (a -> a -> Ordering) -> [a] -> a
minimumBy _ [] = error "minimumBy: empty list"
minimumBy cmp (x:xs) = foldl (\acc y -> if cmp acc y == GT then y else acc) x xs