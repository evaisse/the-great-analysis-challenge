module MoveGenerator exposing (..)

import Types exposing (..)
import Utils exposing (..)
import Board exposing (..)

knightMoves : List (Int, Int)
knightMoves =
    [(-2, -1), (-2, 1), (-1, -2), (-1, 2), (1, -2), (1, 2), (2, -1), (2, 1)]

kingMoves : List (Int, Int)
kingMoves =
    [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]

bishopDirections : List (Int, Int)
bishopDirections =
    [(-1, -1), (-1, 1), (1, -1), (1, 1)]

rookDirections : List (Int, Int)
rookDirections =
    [(-1, 0), (0, -1), (0, 1), (1, 0)]

queenDirections : List (Int, Int)
queenDirections =
    bishopDirections ++ rookDirections

generateSlidingMoves : GameState -> Square -> List (Int, Int) -> List Move
generateSlidingMoves state from directions =
    case getPiece state from of
        Nothing ->
            []
        Just piece ->
            let
                pos = squareToPosition from
                
                generateInDirection : (Int, Int) -> List Move
                generateInDirection (dr, dc) =
                    let
                        helper row col acc =
                            if isValidSquare row col then
                                let
                                    to = positionToSquare row col
                                in
                                case getPiece state to of
                                    Nothing ->
                                        let
                                            move =
                                                { from = from
                                                , to = to
                                                , piece = piece.pieceType
                                                , captured = Nothing
                                                , promotion = Nothing
                                                , castling = Nothing
                                                , enPassant = False
                                                }
                                        in
                                        helper (row + dr) (col + dc) (move :: acc)
                                    Just targetPiece ->
                                        if targetPiece.color /= piece.color then
                                            let
                                                move =
                                                    { from = from
                                                    , to = to
                                                    , piece = piece.pieceType
                                                    , captured = Just targetPiece.pieceType
                                                    , promotion = Nothing
                                                    , castling = Nothing
                                                    , enPassant = False
                                                    }
                                            in
                                            move :: acc
                                        else
                                            acc
                            else
                                acc
                    in
                    helper (pos.row + dr) (pos.col + dc) []
            in
            List.concatMap generateInDirection directions

generatePawnMoves : GameState -> Square -> List Move
generatePawnMoves state from =
    case getPiece state from of
        Nothing ->
            []
        Just piece ->
            let
                pos = squareToPosition from
                direction = if piece.color == White then 1 else -1
                startRow = if piece.color == White then 1 else 6
                promotionRow = if piece.color == White then 7 else 0
                
                frontRow = pos.row + direction
                frontSquare = positionToSquare frontRow pos.col
                
                forwardMoves =
                    if isValidSquare frontRow pos.col && getPiece state frontSquare == Nothing then
                        let
                            isPromotion = frontRow == promotionRow
                            basicMove =
                                { from = from
                                , to = frontSquare
                                , piece = Pawn
                                , captured = Nothing
                                , promotion = Nothing
                                , castling = Nothing
                                , enPassant = False
                                }
                        in
                        if isPromotion then
                            [ Queen, Rook, Bishop, Knight ]
                                |> List.map (\promo ->
                                    { basicMove | promotion = Just promo }
                                )
                        else
                            let
                                moves = [ basicMove ]
                            in
                            if pos.row == startRow then
                                let
                                    doubleRow = pos.row + direction * 2
                                    doubleSquare = positionToSquare doubleRow pos.col
                                in
                                if getPiece state doubleSquare == Nothing then
                                    { from = from
                                    , to = doubleSquare
                                    , piece = Pawn
                                    , captured = Nothing
                                    , promotion = Nothing
                                    , castling = Nothing
                                    , enPassant = False
                                    } :: moves
                                else
                                    moves
                            else
                                moves
                    else
                        []
                
                captureMoves =
                    [-1, 1]
                        |> List.concatMap (\colDelta ->
                            let
                                captureCol = pos.col + colDelta
                            in
                            if isValidSquare frontRow captureCol then
                                let
                                    captureSquare = positionToSquare frontRow captureCol
                                    isPromotion = frontRow == promotionRow
                                in
                                case getPiece state captureSquare of
                                    Just targetPiece ->
                                        if targetPiece.color /= piece.color then
                                            if isPromotion then
                                                [ Queen, Rook, Bishop, Knight ]
                                                    |> List.map (\promo ->
                                                        { from = from
                                                        , to = captureSquare
                                                        , piece = Pawn
                                                        , captured = Just targetPiece.pieceType
                                                        , promotion = Just promo
                                                        , castling = Nothing
                                                        , enPassant = False
                                                        }
                                                    )
                                            else
                                                [ { from = from
                                                  , to = captureSquare
                                                  , piece = Pawn
                                                  , captured = Just targetPiece.pieceType
                                                  , promotion = Nothing
                                                  , castling = Nothing
                                                  , enPassant = False
                                                  }
                                                ]
                                        else
                                            []
                                    Nothing ->
                                        case state.enPassantTarget of
                                            Just epSquare ->
                                                if epSquare == captureSquare then
                                                    [ { from = from
                                                      , to = captureSquare
                                                      , piece = Pawn
                                                      , captured = Just Pawn
                                                      , promotion = Nothing
                                                      , castling = Nothing
                                                      , enPassant = True
                                                      }
                                                    ]
                                                else
                                                    []
                                            Nothing ->
                                                []
                            else
                                []
                        )
            in
            forwardMoves ++ captureMoves

generateKnightMoves : GameState -> Square -> List Move
generateKnightMoves state from =
    case getPiece state from of
        Nothing ->
            []
        Just piece ->
            let
                pos = squareToPosition from
            in
            knightMoves
                |> List.filterMap (\(dr, dc) ->
                    let
                        newRow = pos.row + dr
                        newCol = pos.col + dc
                    in
                    if isValidSquare newRow newCol then
                        let
                            to = positionToSquare newRow newCol
                        in
                        case getPiece state to of
                            Nothing ->
                                Just
                                    { from = from
                                    , to = to
                                    , piece = Knight
                                    , captured = Nothing
                                    , promotion = Nothing
                                    , castling = Nothing
                                    , enPassant = False
                                    }
                            Just targetPiece ->
                                if targetPiece.color /= piece.color then
                                    Just
                                        { from = from
                                        , to = to
                                        , piece = Knight
                                        , captured = Just targetPiece.pieceType
                                        , promotion = Nothing
                                        , castling = Nothing
                                        , enPassant = False
                                        }
                                else
                                    Nothing
                    else
                        Nothing
                )

generateKingMoves : GameState -> Square -> List Move
generateKingMoves state from =
    case getPiece state from of
        Nothing ->
            []
        Just piece ->
            let
                pos = squareToPosition from
                
                regularMoves =
                    kingMoves
                        |> List.filterMap (\(dr, dc) ->
                            let
                                newRow = pos.row + dr
                                newCol = pos.col + dc
                            in
                            if isValidSquare newRow newCol then
                                let
                                    to = positionToSquare newRow newCol
                                in
                                case getPiece state to of
                                    Nothing ->
                                        Just
                                            { from = from
                                            , to = to
                                            , piece = King
                                            , captured = Nothing
                                            , promotion = Nothing
                                            , castling = Nothing
                                            , enPassant = False
                                            }
                                    Just targetPiece ->
                                        if targetPiece.color /= piece.color then
                                            Just
                                                { from = from
                                                , to = to
                                                , piece = King
                                                , captured = Just targetPiece.pieceType
                                                , promotion = Nothing
                                                , castling = Nothing
                                                , enPassant = False
                                                }
                                        else
                                            Nothing
                            else
                                Nothing
                        )
                
                castlingMoves =
                    if piece.color == White && from == 4 then
                        let
                            kingsideCastle =
                                if state.castlingRights.whiteKingside &&
                                   getPiece state 5 == Nothing &&
                                   getPiece state 6 == Nothing &&
                                   getPiece state 7 /= Nothing then
                                    [ { from = from
                                      , to = 6
                                      , piece = King
                                      , captured = Nothing
                                      , promotion = Nothing
                                      , castling = Just "K"
                                      , enPassant = False
                                      }
                                    ]
                                else
                                    []
                            
                            queensideCastle =
                                if state.castlingRights.whiteQueenside &&
                                   getPiece state 3 == Nothing &&
                                   getPiece state 2 == Nothing &&
                                   getPiece state 1 == Nothing &&
                                   getPiece state 0 /= Nothing then
                                    [ { from = from
                                      , to = 2
                                      , piece = King
                                      , captured = Nothing
                                      , promotion = Nothing
                                      , castling = Just "Q"
                                      , enPassant = False
                                      }
                                    ]
                                else
                                    []
                        in
                        kingsideCastle ++ queensideCastle
                    else if piece.color == Black && from == 60 then
                        let
                            kingsideCastle =
                                if state.castlingRights.blackKingside &&
                                   getPiece state 61 == Nothing &&
                                   getPiece state 62 == Nothing &&
                                   getPiece state 63 /= Nothing then
                                    [ { from = from
                                      , to = 62
                                      , piece = King
                                      , captured = Nothing
                                      , promotion = Nothing
                                      , castling = Just "k"
                                      , enPassant = False
                                      }
                                    ]
                                else
                                    []
                            
                            queensideCastle =
                                if state.castlingRights.blackQueenside &&
                                   getPiece state 59 == Nothing &&
                                   getPiece state 58 == Nothing &&
                                   getPiece state 57 == Nothing &&
                                   getPiece state 56 /= Nothing then
                                    [ { from = from
                                      , to = 58
                                      , piece = King
                                      , captured = Nothing
                                      , promotion = Nothing
                                      , castling = Just "q"
                                      , enPassant = False
                                      }
                                    ]
                                else
                                    []
                        in
                        kingsideCastle ++ queensideCastle
                    else
                        []
            in
            regularMoves ++ castlingMoves

generatePieceMoves : GameState -> Square -> List Move
generatePieceMoves state from =
    case getPiece state from of
        Nothing ->
            []
        Just piece ->
            case piece.pieceType of
                Pawn ->
                    generatePawnMoves state from
                Knight ->
                    generateKnightMoves state from
                Bishop ->
                    generateSlidingMoves state from bishopDirections
                Rook ->
                    generateSlidingMoves state from rookDirections
                Queen ->
                    generateSlidingMoves state from queenDirections
                King ->
                    generateKingMoves state from

generateAllMoves : GameState -> List Move
generateAllMoves state =
    List.range 0 63
        |> List.concatMap (\square ->
            case getPiece state square of
                Just piece ->
                    if piece.color == state.turn then
                        generatePieceMoves state square
                    else
                        []
                Nothing ->
                    []
        )

isSquareAttacked : GameState -> Square -> Color -> Bool
isSquareAttacked state targetSquare byColor =
    let
        tempState = { state | turn = byColor }
        moves = generateAllMoves tempState
    in
    List.any (\move -> move.to == targetSquare) moves

isKingInCheck : GameState -> Color -> Bool
isKingInCheck state color =
    case findKing state color of
        Nothing ->
            False
        Just kingSquare ->
            isSquareAttacked state kingSquare (oppositeColor color)

makeMove : GameState -> Move -> GameState
makeMove state move =
    let
        piece = getPiece state move.from |> Maybe.withDefault { pieceType = Pawn, color = White }
        
        -- Handle en passant capture
        boardAfterEnPassant =
            if move.enPassant then
                let
                    captureRow = if piece.color == White then move.to - 8 else move.to + 8
                in
                setPiece state captureRow Nothing
            else
                state
        
        -- Handle castling
        boardAfterCastling =
            case move.castling of
                Just "K" ->
                    boardAfterEnPassant
                        |> setPiece 7 Nothing
                        |> setPiece 5 (Just { pieceType = Rook, color = White })
                Just "Q" ->
                    boardAfterEnPassant
                        |> setPiece 0 Nothing
                        |> setPiece 3 (Just { pieceType = Rook, color = White })
                Just "k" ->
                    boardAfterEnPassant
                        |> setPiece 63 Nothing
                        |> setPiece 61 (Just { pieceType = Rook, color = Black })
                Just "q" ->
                    boardAfterEnPassant
                        |> setPiece 56 Nothing
                        |> setPiece 59 (Just { pieceType = Rook, color = Black })
                _ ->
                    boardAfterEnPassant
        
        -- Handle promotion
        finalPiece =
            case move.promotion of
                Just promotionType ->
                    { piece | pieceType = promotionType }
                Nothing ->
                    piece
        
        -- Move piece
        boardAfterMove =
            boardAfterCastling
                |> setPiece move.from Nothing
                |> setPiece move.to (Just finalPiece)
        
        -- Update castling rights
        newCastlingRights =
            let
                rights = state.castlingRights
            in
            if piece.pieceType == King then
                if piece.color == White then
                    { rights | whiteKingside = False, whiteQueenside = False }
                else
                    { rights | blackKingside = False, blackQueenside = False }
            else if piece.pieceType == Rook then
                if move.from == 0 then
                    { rights | whiteQueenside = False }
                else if move.from == 7 then
                    { rights | whiteKingside = False }
                else if move.from == 56 then
                    { rights | blackQueenside = False }
                else if move.from == 63 then
                    { rights | blackKingside = False }
                else
                    rights
            else
                rights
        
        -- Update en passant target
        newEnPassantTarget =
            if piece.pieceType == Pawn && abs (move.to - move.from) == 16 then
                Just ((move.from + move.to) // 2)
            else
                Nothing
        
        -- Update clocks
        newHalfmoveClock =
            if piece.pieceType == Pawn || move.captured /= Nothing then
                0
            else
                state.halfmoveClock + 1
        
        newFullmoveNumber =
            if state.turn == Black then
                state.fullmoveNumber + 1
            else
                state.fullmoveNumber
    in
    { boardAfterMove
        | turn = oppositeColor state.turn
        , castlingRights = newCastlingRights
        , enPassantTarget = newEnPassantTarget
        , halfmoveClock = newHalfmoveClock
        , fullmoveNumber = newFullmoveNumber
        , moveHistory = move :: state.moveHistory
    }

isMoveLegal : GameState -> Move -> Bool
isMoveLegal state move =
    let
        newState = makeMove state move
    in
    not (isKingInCheck newState state.turn)

generateLegalMoves : GameState -> List Move
generateLegalMoves state =
    generateAllMoves state
        |> List.filter (isMoveLegal state)
