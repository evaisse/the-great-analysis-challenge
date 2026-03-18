module Board where

import Types
import Data.Array
import Data.List (intercalate)
import Data.Maybe (isJust, isNothing)

-- Board display
displayBoard :: GameState -> String
displayBoard gs =
  unlines $
    ["  a b c d e f g h"]
      ++ [show (8 - r) ++ " " ++ rowText (7 - r) ++ " " ++ show (8 - r) | r <- [0 .. 7]]
      ++ ["  a b c d e f g h", "", show (currentPlayer gs) ++ " to move"]
  where
    rowText row =
      intercalate " " [[displaySquare (board gs ! (col, row))] | col <- [0 .. 7]]

displaySquare :: Maybe Piece -> Char
displaySquare Nothing = '.'
displaySquare (Just piece) = pieceChar piece

getPiece :: GameState -> Square -> Maybe Piece
getPiece gs (Square col row)
  | col >= 0 && col <= 7 && row >= 0 && row <= 7 = board gs ! (col, row)
  | otherwise = Nothing

pieceColor :: Piece -> Color
pieceColor (Piece color _) = color

pieceType :: Piece -> PieceType
pieceType (Piece _ ptype) = ptype

-- Move validation
isValidMove :: GameState -> Move -> Bool
isValidMove gs move = isLegalMove gs move && not (wouldBeInCheck gs move)

isLegalMove :: GameState -> Move -> Bool
isLegalMove gs (Move from to promotion) =
  from /= to
    && case getPiece gs from of
      Nothing -> False
      Just piece ->
        pieceColor piece == currentPlayer gs
          && destinationAvailable gs piece to
          && promotionAllowed piece to promotion
          && isValidPieceMove gs piece from to

destinationAvailable :: GameState -> Piece -> Square -> Bool
destinationAvailable gs movingPiece square =
  case getPiece gs square of
    Nothing -> True
    Just target -> pieceColor target /= pieceColor movingPiece

promotionAllowed :: Piece -> Square -> Maybe PieceType -> Bool
promotionAllowed piece (Square _ toRow) promotion =
  case pieceType piece of
    Pawn ->
      case promotion of
        Nothing -> True
        Just promoted ->
          promoted `elem` [Queen, Rook, Bishop, Knight]
            && ((pieceColor piece == White && toRow == 7) || (pieceColor piece == Black && toRow == 0))
    _ -> isNothing promotion

isValidPieceMove :: GameState -> Piece -> Square -> Square -> Bool
isValidPieceMove gs piece from to =
  case pieceType piece of
    Pawn -> isValidPawnMove gs piece from to
    Knight -> isValidKnightMove from to
    Bishop -> isDiagonal from to && isPathClear gs from to
    Rook -> isStraight from to && isPathClear gs from to
    Queen -> (isDiagonal from to || isStraight from to) && isPathClear gs from to
    King -> isValidKingMove gs piece from to

isValidPawnMove :: GameState -> Piece -> Square -> Square -> Bool
isValidPawnMove gs piece (Square fromCol fromRow) (Square toCol toRow) =
  let direction = if pieceColor piece == White then 1 else -1
      startRow = if pieceColor piece == White then 1 else 6
      oneStepSquare = Square fromCol (fromRow + direction)
      oneStep = toCol == fromCol && toRow == fromRow + direction && isNothing (getPiece gs oneStepSquare)
      twoStep =
        toCol == fromCol
          && fromRow == startRow
          && toRow == fromRow + 2 * direction
          && isNothing (getPiece gs oneStepSquare)
          && isNothing (getPiece gs (Square toCol toRow))
      diagonalCapture =
        abs (toCol - fromCol) == 1
          && toRow == fromRow + direction
          && (case getPiece gs (Square toCol toRow) of
                Just target -> pieceColor target /= pieceColor piece
                Nothing -> enPassantTarget gs == Just (Square toCol toRow))
  in oneStep || twoStep || diagonalCapture

isValidKnightMove :: Square -> Square -> Bool
isValidKnightMove (Square fromCol fromRow) (Square toCol toRow) =
  let deltaCol = abs (fromCol - toCol)
      deltaRow = abs (fromRow - toRow)
  in (deltaCol == 2 && deltaRow == 1) || (deltaCol == 1 && deltaRow == 2)

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
  in [Square (fromCol + i * deltaCol) (fromRow + i * deltaRow) | i <- [1 .. steps]]

isValidCastle :: GameState -> Piece -> Square -> Square -> Bool
isValidCastle gs piece from@(Square fromCol fromRow) to@(Square toCol toRow) =
  pieceType piece == King
    && fromRow == toRow
    && abs (toCol - fromCol) == 2
    && canCastle gs (pieceColor piece) kingside
    && rookPresent
    && all (isNothing . getPiece gs) betweenSquares
    && all (not . isSquareAttacked gs (opponentColor (pieceColor piece))) kingSquares
  where
    kingside = toCol > fromCol
    rookSquare = if kingside then Square 7 fromRow else Square 0 fromRow
    rookPresent = getPiece gs rookSquare == Just (Piece (pieceColor piece) Rook)
    betweenSquares =
      if kingside
        then [Square 5 fromRow, Square 6 fromRow]
        else [Square 3 fromRow, Square 2 fromRow, Square 1 fromRow]
    kingSquares =
      if kingside
        then [from, Square 5 fromRow, to]
        else [from, Square 3 fromRow, to]

canCastle :: GameState -> Color -> Bool -> Bool
canCastle gs color kingside =
  let (whiteKS, blackKS) = canCastleKS gs
      (whiteQS, blackQS) = canCastleQS gs
  in case (color, kingside) of
       (White, True) -> whiteKS
       (White, False) -> whiteQS
       (Black, True) -> blackKS
       (Black, False) -> blackQS

-- Check detection
isInCheck :: GameState -> Color -> Bool
isInCheck gs color =
  case findKing gs color of
    Nothing -> False
    Just kingSquare -> isSquareAttacked gs (opponentColor color) kingSquare

findKing :: GameState -> Color -> Maybe Square
findKing gs color =
  case [Square col row | col <- [0 .. 7], row <- [0 .. 7], getPiece gs (Square col row) == Just (Piece color King)] of
    square : _ -> Just square
    [] -> Nothing

isSquareAttacked :: GameState -> Color -> Square -> Bool
isSquareAttacked gs attackerColor target =
  any attacksFrom [Square col row | col <- [0 .. 7], row <- [0 .. 7]]
  where
    attacksFrom square =
      case getPiece gs square of
        Just piece | pieceColor piece == attackerColor -> pieceAttacksSquare gs piece square target
        _ -> False

pieceAttacksSquare :: GameState -> Piece -> Square -> Square -> Bool
pieceAttacksSquare gs piece from@(Square fromCol fromRow) to@(Square toCol toRow) =
  case pieceType piece of
    Pawn ->
      let direction = if pieceColor piece == White then 1 else -1
      in toRow == fromRow + direction && abs (toCol - fromCol) == 1
    Knight -> isValidKnightMove from to
    Bishop -> isDiagonal from to && isPathClear gs from to
    Rook -> isStraight from to && isPathClear gs from to
    Queen -> (isDiagonal from to || isStraight from to) && isPathClear gs from to
    King -> maxDistance from to == 1

wouldBeInCheck :: GameState -> Move -> Bool
wouldBeInCheck gs move = isInCheck (makeMove gs move) (currentPlayer gs)

-- Make/undo moves
makeMove :: GameState -> Move -> GameState
makeMove gs move =
  case getPiece gs (fromSquare move) of
    Nothing -> gs
    Just movingPiece ->
      let newBoard = updateBoard gs move movingPiece
          newPlayer = opponentColor (currentPlayer gs)
          newCastling = updateCastlingRights gs move movingPiece
          newEnPassant = calculateEnPassant gs move movingPiece
          newHalfMove = updateHalfMoveClock gs move movingPiece
          newFullMove =
            if currentPlayer gs == Black
              then fullMoveNumber gs + 1
              else fullMoveNumber gs
      in GameState newBoard newPlayer (fst newCastling) (snd newCastling) newEnPassant newHalfMove newFullMove

updateBoard :: GameState -> Move -> Piece -> Board
updateBoard gs move movingPiece =
  boardAfterCastle
  where
    from@(Square fromCol fromRow) = fromSquare move
    to@(Square toCol toRow) = toSquare move
    originalBoard = board gs
    boardWithoutFrom = originalBoard // [((fromCol, fromRow), Nothing)]
    boardAfterEnPassant =
      if pieceType movingPiece == Pawn && fromCol /= toCol && isNothing (getPiece gs to)
        then boardWithoutFrom // [((toCol, fromRow), Nothing)]
        else boardWithoutFrom
    promotedPiece =
      case (pieceType movingPiece, promotion move, toRow) of
        (Pawn, Just promoted, _) -> Piece (pieceColor movingPiece) promoted
        (Pawn, Nothing, 7) | pieceColor movingPiece == White -> Piece White Queen
        (Pawn, Nothing, 0) | pieceColor movingPiece == Black -> Piece Black Queen
        _ -> movingPiece
    boardAfterMove = boardAfterEnPassant // [((toCol, toRow), Just promotedPiece)]
    boardAfterCastle =
      if pieceType movingPiece == King && abs (toCol - fromCol) == 2
        then
          if toCol > fromCol
            then boardAfterMove // [((7, fromRow), Nothing), ((5, fromRow), Just (Piece (pieceColor movingPiece) Rook))]
            else boardAfterMove // [((0, fromRow), Nothing), ((3, fromRow), Just (Piece (pieceColor movingPiece) Rook))]
        else boardAfterMove

updateCastlingRights :: GameState -> Move -> Piece -> ((Bool, Bool), (Bool, Bool))
updateCastlingRights gs move movingPiece =
  let from = fromSquare move
      to = toSquare move
      (whiteKS, blackKS) = canCastleKS gs
      (whiteQS, blackQS) = canCastleQS gs
      capturedRookWhiteKS = to == Square 7 0
      capturedRookWhiteQS = to == Square 0 0
      capturedRookBlackKS = to == Square 7 7
      capturedRookBlackQS = to == Square 0 7
      moveKillsWhiteKS = from == Square 4 0 || from == Square 7 0
      moveKillsWhiteQS = from == Square 4 0 || from == Square 0 0
      moveKillsBlackKS = from == Square 4 7 || from == Square 7 7
      moveKillsBlackQS = from == Square 4 7 || from == Square 0 7
      newWhiteKS =
        whiteKS
          && not capturedRookWhiteKS
          && not (pieceColor movingPiece == White && moveKillsWhiteKS)
      newWhiteQS =
        whiteQS
          && not capturedRookWhiteQS
          && not (pieceColor movingPiece == White && moveKillsWhiteQS)
      newBlackKS =
        blackKS
          && not capturedRookBlackKS
          && not (pieceColor movingPiece == Black && moveKillsBlackKS)
      newBlackQS =
        blackQS
          && not capturedRookBlackQS
          && not (pieceColor movingPiece == Black && moveKillsBlackQS)
  in ((newWhiteKS, newBlackKS), (newWhiteQS, newBlackQS))

calculateEnPassant :: GameState -> Move -> Piece -> Maybe Square
calculateEnPassant _ (Move (Square fromCol fromRow) (Square toCol toRow) _) movingPiece =
  case pieceType movingPiece of
    Pawn | abs (toRow - fromRow) == 2 -> Just (Square toCol ((fromRow + toRow) `div` 2))
    _ -> Nothing

updateHalfMoveClock :: GameState -> Move -> Piece -> Int
updateHalfMoveClock gs move movingPiece =
  if pieceType movingPiece == Pawn || isCapture gs move
    then 0
    else halfMoveClock gs + 1

isCapture :: GameState -> Move -> Bool
isCapture gs (Move (Square fromCol fromRow) to _) =
  case getPiece gs (Square fromCol fromRow) of
    Just movingPiece ->
      isJust (getPiece gs to)
        || (pieceType movingPiece == Pawn && fromCol /= squareCol to && isNothing (getPiece gs to))
    Nothing -> False

-- Game end detection
isCheckmate :: GameState -> Bool
isCheckmate gs = isInCheck gs (currentPlayer gs) && null (generateLegalMoves gs)

isStalemate :: GameState -> Bool
isStalemate gs = not (isInCheck gs (currentPlayer gs)) && null (generateLegalMoves gs)

generateLegalMoves :: GameState -> [Move]
generateLegalMoves gs = filter (isValidMove gs) (generatePseudoLegalMoves gs)

generatePseudoLegalMoves :: GameState -> [Move]
generatePseudoLegalMoves gs =
  [ Move from to promotionChoice
  | col <- [0 .. 7]
  , row <- [0 .. 7]
  , let from = Square col row
  , Just piece <- [getPiece gs from]
  , pieceColor piece == currentPlayer gs
  , to <- generatePieceMoves gs piece from
  , promotionChoice <- generatePromotions piece to
  ]

generatePieceMoves :: GameState -> Piece -> Square -> [Square]
generatePieceMoves gs piece from@(Square col row) =
  case pieceType piece of
    Pawn -> generatePawnMoves gs piece from
    Knight ->
      [ Square (col + dc) (row + dr)
      | (dc, dr) <- knightDeltas
      , isInBounds (col + dc) (row + dr)
      , canMoveTo gs (Square (col + dc) (row + dr))
      ]
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
      oneStepMoves =
        [oneStep | isInBounds col (row + direction), isNothing (getPiece gs oneStep)]
      twoStepMoves =
        [ twoStep
        | row == (if color == White then 1 else 6)
        , isInBounds col (row + 2 * direction)
        , isNothing (getPiece gs oneStep)
        , isNothing (getPiece gs twoStep)
        ]
      captureMoves =
        [target | target <- [leftCapture, rightCapture], isInBounds (squareCol target) (squareRow target), canCapture gs target]
  in oneStepMoves ++ twoStepMoves ++ captureMoves

generateSlidingMoves :: GameState -> Square -> [(Int, Int)] -> [Square]
generateSlidingMoves gs from directions =
  [to | direction <- directions, to <- generateRayMoves gs from direction]

generateRayMoves :: GameState -> Square -> (Int, Int) -> [Square]
generateRayMoves gs (Square col row) (dc, dr) = go 1
  where
    go step =
      let square = Square (col + step * dc) (row + step * dr)
      in if not (isInBounds (squareCol square) (squareRow square))
           then []
           else case getPiece gs square of
             Nothing -> square : go (step + 1)
             Just piece ->
               if pieceColor piece /= currentPlayer gs
                 then [square]
                 else []

generateKingMoves :: GameState -> Piece -> Square -> [Square]
generateKingMoves gs piece from@(Square col row) =
  let normalMoves =
        [ Square (col + dc) (row + dr)
        | (dc, dr) <- kingDirections
        , isInBounds (col + dc) (row + dr)
        , canMoveTo gs (Square (col + dc) (row + dr))
        ]
      kingside = Square (col + 2) row
      queenside = Square (col - 2) row
      castleMoves =
        [ kingside | isValidCastle gs piece from kingside ]
          ++ [ queenside | isValidCastle gs piece from queenside ]
  in normalMoves ++ castleMoves

generatePromotions :: Piece -> Square -> [Maybe PieceType]
generatePromotions (Piece color Pawn) (Square _ row)
  | (color == White && row == 7) || (color == Black && row == 0) =
      [Just Queen, Just Rook, Just Bishop, Just Knight]
generatePromotions _ _ = [Nothing]

canMoveTo :: GameState -> Square -> Bool
canMoveTo gs square =
  isInBounds (squareCol square) (squareRow square)
    && case getPiece gs square of
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
knightDeltas = [(2, 1), (2, -1), (-2, 1), (-2, -1), (1, 2), (1, -2), (-1, 2), (-1, -2)]

bishopDirections :: [(Int, Int)]
bishopDirections = [(1, 1), (1, -1), (-1, 1), (-1, -1)]

rookDirections :: [(Int, Int)]
rookDirections = [(0, 1), (0, -1), (1, 0), (-1, 0)]

queenDirections :: [(Int, Int)]
queenDirections = bishopDirections ++ rookDirections

kingDirections :: [(Int, Int)]
kingDirections = queenDirections
