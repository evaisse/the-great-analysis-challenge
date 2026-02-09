module FEN where

import Types
import Data.Array
import Data.Maybe (fromMaybe)
import Data.Char (isDigit, digitToInt)
import Data.List (intercalate)

-- Parse FEN string into GameState
parseFEN :: String -> Maybe GameState
parseFEN fen = 
  case words fen of
    [pieces, turn, castling, enPassant, halfMove, fullMove] -> do
      board <- parsePieces pieces
      player <- parsePlayer turn
      (ks, qs) <- parseCastling castling
      ep <- parseEnPassant enPassant
      hm <- parseHalfMove halfMove
      fm <- parseFullMove fullMove
      return GameState
        { board = board
        , currentPlayer = player
        , canCastleKS = ks
        , canCastleQS = qs
        , enPassantTarget = ep
        , halfMoveClock = hm
        , fullMoveNumber = fm
        }
    _ -> Nothing

parsePieces :: String -> Maybe Board
parsePieces pieces = do
  rows <- parseRows (splitBy '/' pieces)
  if length rows == 8
    then Just $ array ((0,0), (7,7)) $ concat 
           [zip [(col, 7-row) | col <- [0..7]] (rows !! row) | row <- [0..7]]
    else Nothing

parseRows :: [String] -> Maybe [[Maybe Piece]]
parseRows = mapM parseRow

parseRow :: String -> Maybe [Maybe Piece]
parseRow [] = Just []
parseRow (c:cs)
  | isDigit c = do
      rest <- parseRow cs
      let emptySquares = replicate (digitToInt c) Nothing
      return (emptySquares ++ rest)
  | otherwise = do
      piece <- charToPiece c
      rest <- parseRow cs
      return (Just piece : rest)

parsePlayer :: String -> Maybe Color
parsePlayer "w" = Just White
parsePlayer "b" = Just Black
parsePlayer _ = Nothing

parseCastling :: String -> Maybe ((Bool, Bool), (Bool, Bool))
parseCastling "-" = Just ((False, False), (False, False))
parseCastling castling = 
  let whiteKS = 'K' `elem` castling
      whiteQS = 'Q' `elem` castling  
      blackKS = 'k' `elem` castling
      blackQS = 'q' `elem` castling
  in Just ((whiteKS, blackKS), (whiteQS, blackQS))

parseEnPassant :: String -> Maybe (Maybe Square)
parseEnPassant "-" = Just Nothing
parseEnPassant s = case squareFromString s of
  Just square -> Just (Just square)
  Nothing -> Nothing

parseHalfMove :: String -> Maybe Int
parseHalfMove s = case reads s of
  [(n, "")] -> Just n
  _ -> Nothing

parseFullMove :: String -> Maybe Int
parseFullMove s = case reads s of
  [(n, "")] -> Just n
  _ -> Nothing

-- Export GameState to FEN string
exportFEN :: GameState -> String
exportFEN gs = unwords
  [ exportPieces (board gs)
  , exportPlayer (currentPlayer gs)
  , exportCastling (canCastleKS gs) (canCastleQS gs)
  , exportEnPassant (enPassantTarget gs)
  , show (halfMoveClock gs)
  , show (fullMoveNumber gs)
  ]

exportPieces :: Board -> String
exportPieces board = 
  intercalate "/" $ map exportRow [7,6..0]
  where 
    exportRow row = compressRow [board ! (col, row) | col <- [0..7]]

exportRow :: [Maybe Piece] -> String  
exportRow = compressRow

compressRow :: [Maybe Piece] -> String
compressRow [] = ""
compressRow pieces = 
  let (empties, rest) = span (== Nothing) pieces
      emptyCount = length empties
  in (if emptyCount > 0 then show emptyCount else "") ++
     case rest of
       [] -> ""
       (Just piece : rest') -> pieceChar piece : compressRow rest'
       (Nothing : _) -> error "This should not happen"

exportPlayer :: Color -> String
exportPlayer White = "w"
exportPlayer Black = "b"

exportCastling :: (Bool, Bool) -> (Bool, Bool) -> String
exportCastling (whiteKS, blackKS) (whiteQS, blackQS) =
  let rights = (if whiteKS then "K" else "") ++
               (if whiteQS then "Q" else "") ++
               (if blackKS then "k" else "") ++
               (if blackQS then "q" else "")
  in if null rights then "-" else rights

exportEnPassant :: Maybe Square -> String
exportEnPassant Nothing = "-"
exportEnPassant (Just square) = show square

-- Utility functions
splitBy :: Eq a => a -> [a] -> [[a]]
splitBy _ [] = []
splitBy delimiter str = 
  let (before, remainder) = span (/= delimiter) str
  in before : case remainder of
    [] -> []
    (_:after) -> splitBy delimiter after

-- Standard starting position FEN
startingFEN :: String
startingFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"