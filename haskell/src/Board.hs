module Board where

import Types
import Data.Array
import Data.Maybe (isJust, isNothing, fromJust)

-- Board display
displayBoard :: GameState -> String
displayBoard gs = unlines $ 
  ["  a b c d e f g h"] ++
  [show (8-r) ++ " " ++ [displaySquare (board gs ! (c,7-r)) | c <- [0..7]] ++ " " ++ show (8-r) | r <- [0..7]] ++
  ["  a b c d e f g h"] ++
  [""] ++
  [show (currentPlayer gs) ++ " to move"]

displaySquare :: Maybe Piece -> Char
displaySquare Nothing = '.'
displaySquare (Just piece) = pieceChar piece

-- Move validation
isValidMove :: GameState -> Move -> Bool
isValidMove gs move = 
  isLegalMove gs move && not (wouldBeInCheck gs move)

isLegalMove :: GameState -> Move -> Bool
isLegalMove gs (Move from to promotion) = 
  case getPiece gs from of
    Nothing -> False
    Just piece -> 
      pieceColor piece == currentPlayer gs &&
      isValidPieceMove gs piece from to &&
      (isNothing promotion || pieceType piece == Pawn)

getPiece :: GameState -> Square -> Maybe Piece
getPiece gs (Square col row) 
  | col >= 0 && col <= 7 && row >= 0 && row <= 7 = board gs ! (col, row)
  | otherwise = Nothing

pieceColor :: Piece -> Color
pieceColor (Piece color _) = color

pieceType :: Piece -> PieceType
pieceType (Piece _ ptype) = ptype

isValidPieceMove :: GameState -> Piece -> Square -> Square -> Bool
isValidPieceMove gs piece from to =
  case pieceType piece of
    Pawn -> isValidPawnMove gs piece from to
    Knight -> isValidKnightMove from to
    Bishop -> isValidBishopMove gs from to
    Rook -> isValidRookMove gs from to
    Queen -> isValidQueenMove gs from to
    King -> isValidKingMove gs piece from to

isValidPawnMove :: GameState -> Piece -> Square -> Square -> Bool
isValidPawnMove gs piece (Square fromCol fromRow) (Square toCol toRow) =
  let direction = if pieceColor piece == White then 1 else -1
      startRow = if pieceColor piece == White then 1 else 6
      oneStep = toRow == fromRow + direction
      twoStep = fromRow == startRow && toRow == fromRow + 2 * direction
      straight = fromCol == toCol
      diagonal = abs (fromCol - toCol) == 1
      capture = isJust (getPiece gs (Square toCol toRow)) || 
                enPassantTarget gs == Just (Square toCol toRow)
  in (oneStep && straight && isNothing (getPiece gs (Square toCol toRow))) ||
     (twoStep && straight && isNothing (getPiece gs (Square toCol toRow))) ||
     (oneStep && diagonal && capture)

isValidKnightMove :: Square -> Square -> Bool
isValidKnightMove (Square fromCol fromRow) (Square toCol toRow) =
  let deltaCol = abs (fromCol - toCol)
      deltaRow = abs (fromRow - toRow)
  in (deltaCol == 2 && deltaRow == 1) || (deltaCol == 1 && deltaRow == 2)

isValidBishopMove :: GameState -> Square -> Square -> Bool
isValidBishopMove gs from to = 
  isDiagonal from to && isPathClear gs from to

isValidRookMove :: GameState -> Square -> Square -> Bool
isValidRookMove gs from to = 
  isStraight from to && isPathClear gs from to

isValidQueenMove :: GameState -> Square -> Square -> Bool
isValidQueenMove gs from to = 
  (isDiagonal from to || isStraight from to) && isPathClear gs from to

isValidKingMove :: GameState -> Piece -> Square -> Square -> Bool
isValidKingMove gs piece from to =
  let distance = maxDistance from to
  in distance == 1 || isValidCastle gs piece from to

isDiagonal :: Square -> Square -> Bool
isDiagonal (Square fromCol fromRow) (Square toCol toRow) =
  abs (fromCol - toCol) == abs (fromRow - toRow) && fromCol /= toCol

isStraight :: Square -> Square -> Bool
isStraight (Square fromCol fromRow) (Square toCol toRow) =
  fromCol == toCol || fromRow == toRow

maxDistance :: Square -> Square -> Int
maxDistance (Square fromCol fromRow) (Square toCol toRow) =
  max (abs (fromCol - toCol)) (abs (fromRow - toRow))

isPathClear :: GameState -> Square -> Square -> Bool
isPathClear gs from to = all (isNothing . getPiece gs) (pathSquares from to)

pathSquares :: Square -> Square -> [Square]
pathSquares (Square fromCol fromRow) (Square toCol toRow) =
  let deltaCol = signum (toCol - fromCol)
      deltaRow = signum (toRow - fromRow)
      steps = max (abs (toCol - fromCol)) (abs (toRow - fromRow)) - 1
  in [Square (fromCol + i * deltaCol) (fromRow + i * deltaRow) | i <- [1..steps]]

isValidCastle :: GameState -> Piece -> Square -> Square -> Bool
isValidCastle gs piece (Square fromCol fromRow) (Square toCol toRow) =
  pieceType piece == King &&
  fromRow == toRow &&
  abs (fromCol - toCol) == 2 &&
  canCastle gs (pieceColor piece) (toCol > fromCol) &&
  isPathClear gs (Square fromCol fromRow) (Square toCol toRow) &&
  not (isInCheck gs (currentPlayer gs)) &&
  not (wouldPassThroughCheck gs (Square fromCol fromRow) (Square toCol toRow))

canCastle :: GameState -> Color -> Bool -> Bool
canCastle gs color kingside =
  let (whiteKS, blackKS) = canCastleKS gs
      (whiteQS, blackQS) = canCastleQS gs
  in case (color, kingside) of
       (White, True) -> whiteKS
       (White, False) -> whiteQS
       (Black, True) -> blackKS
       (Black, False) -> blackQS

wouldPassThroughCheck :: GameState -> Square -> Square -> Bool
wouldPassThroughCheck gs from@(Square fromCol fromRow) to@(Square toCol toRow) =
  let deltaCol = signum (toCol - fromCol)
      intermediateSquare = Square (fromCol + deltaCol) fromRow
      testMove = Move from intermediateSquare Nothing
  in wouldBeInCheck gs testMove

-- Check detection
isInCheck :: GameState -> Color -> Bool
isInCheck gs color =
  case findKing gs color of
    Nothing -> False
    Just kingSquare -> isSquareAttacked gs (opponentColor color) kingSquare

findKing :: GameState -> Color -> Maybe Square
findKing gs color = 
  case [Square col row | col <- [0..7], row <- [0..7], 
        getPiece gs (Square col row) == Just (Piece color King)] of
    [square] -> Just square
    _ -> Nothing

isSquareAttacked :: GameState -> Color -> Square -> Bool
isSquareAttacked gs attackerColor square =
  any (\attackerSquare -> 
    case getPiece gs attackerSquare of
      Just piece | pieceColor piece == attackerColor ->
        isValidPieceMove gs piece attackerSquare square
      _ -> False
  ) allSquares
  where allSquares = [Square col row | col <- [0..7], row <- [0..7]]

wouldBeInCheck :: GameState -> Move -> Bool
wouldBeInCheck gs move =
  isInCheck (makeMove gs move) (currentPlayer gs)

-- Make/undo moves
makeMove :: GameState -> Move -> GameState
makeMove gs (Move from to promotion) =
  let newBoard = updateBoard (board gs) from to promotion
      newPlayer = opponentColor (currentPlayer gs)
      newCastling = updateCastlingRights gs from to
      newEnPassant = calculateEnPassant gs from to
      newHalfMove = updateHalfMoveClock gs from to
      newFullMove = if currentPlayer gs == Black 
                   then fullMoveNumber gs + 1 
                   else fullMoveNumber gs
  in GameState newBoard newPlayer (fst newCastling) (snd newCastling) 
                newEnPassant newHalfMove newFullMove

updateBoard :: Board -> Square -> Square -> Maybe PieceType -> Board
updateBoard board from@(Square fromCol fromRow) to@(Square toCol toRow) promotion =
  let piece = board ! (fromCol, fromRow)
      promotedPiece = case (piece, promotion) of
        (Just (Piece color Pawn), Just newType) -> Just (Piece color newType)
        _ -> piece
      clearedFrom = board // [((fromCol, fromRow), Nothing)]
  in clearedFrom // [((toCol, toRow), promotedPiece)]

updateCastlingRights :: GameState -> Square -> Square -> ((Bool, Bool), (Bool, Bool))
updateCastlingRights gs from to =
  let (whiteKS, blackKS) = canCastleKS gs
      (whiteQS, blackQS) = canCastleQS gs
      -- Lose castling rights if king or rook moves
      newWhiteKS = whiteKS && from /= Square 4 0 && from /= Square 7 0 && to /= Square 7 0
      newWhiteQS = whiteQS && from /= Square 4 0 && from /= Square 0 0 && to /= Square 0 0
      newBlackKS = blackKS && from /= Square 4 7 && from /= Square 7 7 && to /= Square 7 7
      newBlackQS = blackQS && from /= Square 4 7 && from /= Square 0 7 && to /= Square 0 7
  in ((newWhiteKS, newBlackKS), (newWhiteQS, newBlackQS))

calculateEnPassant :: GameState -> Square -> Square -> Maybe Square
calculateEnPassant gs (Square fromCol fromRow) (Square toCol toRow) =
  case getPiece gs (Square fromCol fromRow) of
    Just (Piece _ Pawn) | abs (toRow - fromRow) == 2 ->
      Just (Square toCol ((fromRow + toRow) `div` 2))
    _ -> Nothing

updateHalfMoveClock :: GameState -> Square -> Square -> Int
updateHalfMoveClock gs from to =
  case getPiece gs from of
    Just (Piece _ Pawn) -> 0
    _ -> if isJust (getPiece gs to) then 0 else halfMoveClock gs + 1

-- Game end detection
isCheckmate :: GameState -> Bool
isCheckmate gs = isInCheck gs (currentPlayer gs) && null (generateLegalMoves gs)

isStalemate :: GameState -> Bool
isStalemate gs = not (isInCheck gs (currentPlayer gs)) && null (generateLegalMoves gs)

generateLegalMoves :: GameState -> [Move]
generateLegalMoves gs = filter (isValidMove gs) (generatePseudoLegalMoves gs)

generatePseudoLegalMoves :: GameState -> [Move]
generatePseudoLegalMoves gs =
  [Move from to promotion 
  | col <- [0..7], row <- [0..7]
  , let from = Square col row
  , Just piece <- [getPiece gs from]
  , pieceColor piece == currentPlayer gs
  , to <- generatePieceMoves gs piece from
  , promotion <- generatePromotions piece to
  ]

generatePieceMoves :: GameState -> Piece -> Square -> [Square]
generatePieceMoves gs piece from@(Square col row) =
  case pieceType piece of
    Pawn -> generatePawnMoves gs piece from
    Knight -> [Square (col + dc) (row + dr) | (dc, dr) <- knightDeltas, 
               isInBounds (col + dc) (row + dr), canMoveTo gs (Square (col + dc) (row + dr))]
    Bishop -> generateSlidingMoves gs from bishopDirections
    Rook -> generateSlidingMoves gs from rookDirections  
    Queen -> generateSlidingMoves gs from queenDirections
    King -> generateKingMoves gs piece from

generatePawnMoves :: GameState -> Piece -> Square -> [Square]
generatePawnMoves gs piece from@(Square col row) =
  let color = pieceColor piece
      direction = if color == White then 1 else -1
      oneStep = Square col (row + direction)
      twoStep = Square col (row + 2 * direction)
      leftCapture = Square (col - 1) (row + direction)
      rightCapture = Square (col + 1) (row + direction)
      moves = [oneStep | isInBounds col (row + direction), isNothing (getPiece gs oneStep)] ++
              [twoStep | row == (if color == White then 1 else 6), 
                        isInBounds col (row + 2 * direction), isNothing (getPiece gs twoStep)] ++
              [leftCapture | isInBounds (col - 1) (row + direction), canCapture gs leftCapture] ++
              [rightCapture | isInBounds (col + 1) (row + direction), canCapture gs rightCapture]
  in moves

generateSlidingMoves :: GameState -> Square -> [(Int, Int)] -> [Square]
generateSlidingMoves gs from directions =
  [to | direction <- directions, to <- generateRayMoves gs from direction]

generateRayMoves :: GameState -> Square -> (Int, Int) -> [Square]
generateRayMoves gs (Square col row) (dc, dr) =
  takeWhile (canMoveTo gs) $ 
  map (\i -> Square (col + i * dc) (row + i * dr)) [1..7]

generateKingMoves :: GameState -> Piece -> Square -> [Square]
generateKingMoves gs piece from@(Square col row) =
  let normalMoves = [Square (col + dc) (row + dr) | (dc, dr) <- kingDirections,
                     isInBounds (col + dc) (row + dr), canMoveTo gs (Square (col + dc) (row + dr))]
      castleMoves = [Square (col + 2) row | canCastle gs (pieceColor piece) True] ++
                   [Square (col - 2) row | canCastle gs (pieceColor piece) False]
  in normalMoves ++ castleMoves

generatePromotions :: Piece -> Square -> [Maybe PieceType]
generatePromotions (Piece color Pawn) (Square _ row) 
  | (color == White && row == 7) || (color == Black && row == 0) = 
    [Just Queen, Just Rook, Just Bishop, Just Knight]
generatePromotions _ _ = [Nothing]

canMoveTo :: GameState -> Square -> Bool
canMoveTo gs square =
  isInBounds (squareCol square) (squareRow square) &&
  case getPiece gs square of
    Nothing -> True
    Just piece -> pieceColor piece /= currentPlayer gs

canCapture :: GameState -> Square -> Bool
canCapture gs square =
  case getPiece gs square of
    Just piece -> pieceColor piece /= currentPlayer gs
    Nothing -> enPassantTarget gs == Just square

isInBounds :: Int -> Int -> Bool
isInBounds col row = col >= 0 && col <= 7 && row >= 0 && row <= 7

squareCol :: Square -> Int
squareCol (Square col _) = col

squareRow :: Square -> Int
squareRow (Square _ row) = row

-- Direction vectors
knightDeltas :: [(Int, Int)]
knightDeltas = [(2,1), (2,-1), (-2,1), (-2,-1), (1,2), (1,-2), (-1,2), (-1,-2)]

bishopDirections :: [(Int, Int)]
bishopDirections = [(1,1), (1,-1), (-1,1), (-1,-1)]

rookDirections :: [(Int, Int)]
rookDirections = [(0,1), (0,-1), (1,0), (-1,0)]

queenDirections :: [(Int, Int)]
queenDirections = bishopDirections ++ rookDirections

kingDirections :: [(Int, Int)]
kingDirections = queenDirections