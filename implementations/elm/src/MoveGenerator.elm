module MoveGenerator exposing (..)

import AttackTables
import Board exposing (..)
import Types exposing (..)
import Utils exposing (..)

generateSlidingMoves : GameState -> Square -> List (List Square) -> List Move
generateSlidingMoves state from rays =
    case getPiece state from of
        Nothing ->
            []

        Just piece ->
            let
                buildMove to captured =
                    { from = from
                    , to = to
                    , piece = piece.pieceType
                    , captured = captured
                    , promotion = Nothing
                    , castling = Nothing
                    , enPassant = False
                    }

                generateRay ray =
                    case ray of
                        [] ->
                            []

                        to :: rest ->
                            case getPiece state to of
                                Nothing ->
                                    buildMove to Nothing :: generateRay rest

                                Just targetPiece ->
                                    if targetPiece.color /= piece.color then
                                        [ buildMove to (Just targetPiece.pieceType) ]

                                        else
                                        []
            in
            List.concatMap generateRay rays

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
            AttackTables.knightAttacks from
                |> List.filterMap
                    (\to ->
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
                    )

generateKingMoves : GameState -> Square -> List Move
generateKingMoves state from =
    case getPiece state from of
        Nothing ->
            []

        Just piece ->
            let
                regularMoves =
                    AttackTables.kingAttacks from
                        |> List.filterMap
                            (\to ->
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

                            )

                isRookAt square color =
                    case getPiece state square of
                        Just rook ->
                            rook.pieceType == Rook && rook.color == color

                        Nothing ->
                            False

                castlingMoves =
                    if piece.color == White && from == 4 then
                        let
                            kingsideCastle =
                                if state.castlingRights.whiteKingside &&
                                    getPiece state 5 == Nothing &&
                                    getPiece state 6 == Nothing &&
                                    isRookAt 7 White &&
                                    not (isSquareAttacked state 4 Black) &&
                                    not (isSquareAttacked state 5 Black) &&
                                    not (isSquareAttacked state 6 Black) then
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
                                    isRookAt 0 White &&
                                    not (isSquareAttacked state 4 Black) &&
                                    not (isSquareAttacked state 3 Black) &&
                                    not (isSquareAttacked state 2 Black) then
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
                                    isRookAt 63 Black &&
                                    not (isSquareAttacked state 60 White) &&
                                    not (isSquareAttacked state 61 White) &&
                                    not (isSquareAttacked state 62 White) then
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
                                    isRookAt 56 Black &&
                                    not (isSquareAttacked state 60 White) &&
                                    not (isSquareAttacked state 59 White) &&
                                    not (isSquareAttacked state 58 White) then
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
                    generateSlidingMoves state from (AttackTables.bishopRays from)
                Rook ->
                    generateSlidingMoves state from (AttackTables.rookRays from)
                Queen ->
                    generateSlidingMoves state from (AttackTables.queenRays from)
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
    pawnAttacksSquare state targetSquare byColor
        || List.any (\square -> pieceMatches state square byColor Knight) (AttackTables.knightAttacks targetSquare)
        || slidingAttacksSquare state (AttackTables.bishopRays targetSquare) byColor [ Bishop, Queen ]
        || slidingAttacksSquare state (AttackTables.rookRays targetSquare) byColor [ Rook, Queen ]
        || List.any (\square -> pieceMatches state square byColor King) (AttackTables.kingAttacks targetSquare)


pawnAttacksSquare : GameState -> Square -> Color -> Bool
pawnAttacksSquare state targetSquare byColor =
    let
        pos =
            squareToPosition targetSquare

        sourceRow =
            if byColor == White then
                pos.row - 1

            else
                pos.row + 1
    in
    [ pos.col - 1, pos.col + 1 ]
        |> List.any
            (\sourceCol ->
                if isValidSquare sourceRow sourceCol then
                    pieceMatches state (positionToSquare sourceRow sourceCol) byColor Pawn

                else
                    False
            )


pieceMatches : GameState -> Square -> Color -> PieceType -> Bool
pieceMatches state square color pieceType =
    case getPiece state square of
        Just piece ->
            piece.color == color && piece.pieceType == pieceType

        Nothing ->
            False


slidingAttacksSquare : GameState -> List (List Square) -> Color -> List PieceType -> Bool
slidingAttacksSquare state rays byColor attackers =
    List.any (\ray -> rayAttacksSquare state ray byColor attackers) rays


rayAttacksSquare : GameState -> List Square -> Color -> List PieceType -> Bool
rayAttacksSquare state ray byColor attackers =
    case ray of
        [] ->
            False

        square :: rest ->
            case getPiece state square of
                Nothing ->
                    rayAttacksSquare state rest byColor attackers

                Just piece ->
                    piece.color == byColor && List.member piece.pieceType attackers

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
                    captureSquare = if piece.color == White then move.to - 8 else move.to + 8
                in
                setPiece state captureSquare Nothing
            else
                state
        
        -- Handle castling
        boardAfterCastling =
            case move.castling of
                Just "K" ->
                    boardAfterEnPassant
                        |> (\currentState -> setPiece currentState 7 Nothing)
                        |> (\currentState -> setPiece currentState 5 (Just { pieceType = Rook, color = White }))
                Just "Q" ->
                    boardAfterEnPassant
                        |> (\currentState -> setPiece currentState 0 Nothing)
                        |> (\currentState -> setPiece currentState 3 (Just { pieceType = Rook, color = White }))
                Just "k" ->
                    boardAfterEnPassant
                        |> (\currentState -> setPiece currentState 63 Nothing)
                        |> (\currentState -> setPiece currentState 61 (Just { pieceType = Rook, color = Black }))
                Just "q" ->
                    boardAfterEnPassant
                        |> (\currentState -> setPiece currentState 56 Nothing)
                        |> (\currentState -> setPiece currentState 59 (Just { pieceType = Rook, color = Black }))
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
                |> (\currentState -> setPiece currentState move.from Nothing)
                |> (\currentState -> setPiece currentState move.to (Just finalPiece))
        
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
