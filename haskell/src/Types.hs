module Types where

import Data.Array

-- Basic types
data Color = White | Black deriving (Eq, Show)
data PieceType = Pawn | Knight | Bishop | Rook | Queen | King deriving (Eq, Show)
data Piece = Piece Color PieceType deriving (Eq, Show)

-- Squares and coordinates
data Square = Square Int Int deriving (Eq, Ord)
type Board = Array (Int, Int) (Maybe Piece)

-- Moves
data Move = Move
  { fromSquare :: Square
  , toSquare :: Square
  , promotion :: Maybe PieceType
  } deriving (Eq, Show)

-- Game state
data GameState = GameState
  { board :: Board
  , currentPlayer :: Color
  , canCastleKS :: (Bool, Bool)  -- (White, Black) kingside
  , canCastleQS :: (Bool, Bool)  -- (White, Black) queenside
  , enPassantTarget :: Maybe Square
  , halfMoveClock :: Int
  , fullMoveNumber :: Int
  } deriving (Show)

-- Helper functions
instance Show Square where
  show (Square col row) = [toEnum (col + fromEnum 'a'), toEnum (row + fromEnum '1')]

squareFromString :: String -> Maybe Square
squareFromString [c, r]
  | c >= 'a' && c <= 'h' && r >= '1' && r <= '8' =
    Just $ Square (fromEnum c - fromEnum 'a') (fromEnum r - fromEnum '1')
squareFromString _ = Nothing

opponentColor :: Color -> Color
opponentColor White = Black
opponentColor Black = White

pieceChar :: Piece -> Char
pieceChar (Piece White Pawn) = 'P'
pieceChar (Piece White Knight) = 'N'
pieceChar (Piece White Bishop) = 'B'
pieceChar (Piece White Rook) = 'R'
pieceChar (Piece White Queen) = 'Q'
pieceChar (Piece White King) = 'K'
pieceChar (Piece Black Pawn) = 'p'
pieceChar (Piece Black Knight) = 'n'
pieceChar (Piece Black Bishop) = 'b'
pieceChar (Piece Black Rook) = 'r'
pieceChar (Piece Black Queen) = 'q'
pieceChar (Piece Black King) = 'k'

charToPiece :: Char -> Maybe Piece
charToPiece 'P' = Just $ Piece White Pawn
charToPiece 'N' = Just $ Piece White Knight
charToPiece 'B' = Just $ Piece White Bishop
charToPiece 'R' = Just $ Piece White Rook
charToPiece 'Q' = Just $ Piece White Queen
charToPiece 'K' = Just $ Piece White King
charToPiece 'p' = Just $ Piece Black Pawn
charToPiece 'n' = Just $ Piece Black Knight
charToPiece 'b' = Just $ Piece Black Bishop
charToPiece 'r' = Just $ Piece Black Rook
charToPiece 'q' = Just $ Piece Black Queen
charToPiece 'k' = Just $ Piece Black King
charToPiece _ = Nothing

emptyBoard :: Board
emptyBoard = array ((0,0), (7,7)) [((i,j), Nothing) | i <- [0..7], j <- [0..7]]

initialGameState :: GameState
initialGameState = GameState
  { board = initialBoard
  , currentPlayer = White
  , canCastleKS = (True, True)
  , canCastleQS = (True, True)
  , enPassantTarget = Nothing
  , halfMoveClock = 0
  , fullMoveNumber = 1
  }

initialBoard :: Board
initialBoard = array ((0,0), (7,7)) $ concat
  [ -- Black pieces
    [((i, 7), Just (Piece Black piece)) | (i, piece) <- 
      [(0,Rook), (1,Knight), (2,Bishop), (3,Queen), (4,King), (5,Bishop), (6,Knight), (7,Rook)]]
  , [((i, 6), Just (Piece Black Pawn)) | i <- [0..7]]
  -- Empty squares
  , [((i, j), Nothing) | i <- [0..7], j <- [2..5]]
  -- White pieces  
  , [((i, 1), Just (Piece White Pawn)) | i <- [0..7]]
  , [((i, 0), Just (Piece White piece)) | (i, piece) <- 
      [(0,Rook), (1,Knight), (2,Bishop), (3,Queen), (4,King), (5,Bishop), (6,Knight), (7,Rook)]]
  ]