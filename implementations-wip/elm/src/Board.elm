module Board exposing (..)

import Types exposing (..)
import Utils exposing (..)

createEmptyBoard : List (Maybe Piece)
createEmptyBoard =
    List.repeat 64 Nothing

createInitialBoard : List (Maybe Piece)
createInitialBoard =
    let
        whiteRook = Just { pieceType = Rook, color = White }
        whiteKnight = Just { pieceType = Knight, color = White }
        whiteBishop = Just { pieceType = Bishop, color = White }
        whiteQueen = Just { pieceType = Queen, color = White }
        whiteKing = Just { pieceType = King, color = White }
        whitePawn = Just { pieceType = Pawn, color = White }
        
        blackRook = Just { pieceType = Rook, color = Black }
        blackKnight = Just { pieceType = Knight, color = Black }
        blackBishop = Just { pieceType = Bishop, color = Black }
        blackQueen = Just { pieceType = Queen, color = Black }
        blackKing = Just { pieceType = King, color = Black }
        blackPawn = Just { pieceType = Pawn, color = Black }
        
        emptyRow = List.repeat 8 Nothing
    in
    [ whiteRook, whiteKnight, whiteBishop, whiteQueen, whiteKing, whiteBishop, whiteKnight, whiteRook ]
        ++ List.repeat 8 whitePawn
        ++ List.concat (List.repeat 4 emptyRow)
        ++ List.repeat 8 blackPawn
        ++ [ blackRook, blackKnight, blackBishop, blackQueen, blackKing, blackBishop, blackKnight, blackRook ]

createInitialState : GameState
createInitialState =
    { board = createInitialBoard
    , turn = White
    , castlingRights =
        { whiteKingside = True
        , whiteQueenside = True
        , blackKingside = True
        , blackQueenside = True
        }
    , enPassantTarget = Nothing
    , halfmoveClock = 0
    , fullmoveNumber = 1
    , moveHistory = []
    }

getPiece : GameState -> Square -> Maybe Piece
getPiece state square =
    getAt square state.board |> Maybe.withDefault Nothing

setPiece : GameState -> Square -> Maybe Piece -> GameState
setPiece state square piece =
    { state | board = setAt square piece state.board }

boardToString : GameState -> String
boardToString state =
    let
        rowToString row =
            List.range 0 7
                |> List.map (\col ->
                    let
                        square = positionToSquare row col
                        char =
                            case getPiece state square of
                                Just piece -> pieceToChar piece
                                Nothing -> "."
                    in
                    char
                )
                |> String.join " "
        
        boardRows =
            List.range 0 7
                |> List.reverse
                |> List.map (\row ->
                    String.fromInt (row + 1) ++ " " ++ rowToString row ++ " " ++ String.fromInt (row + 1)
                )
        
        header = "  a b c d e f g h"
        turnStr =
            case state.turn of
                White -> "White to move"
                Black -> "Black to move"
    in
    header ++ "\n" ++ String.join "\n" boardRows ++ "\n" ++ header ++ "\n\n" ++ turnStr

parseFen : String -> Result String GameState
parseFen fen =
    let
        parts = String.split " " fen
    in
    case parts of
        pieces :: turn :: castling :: enPassant :: halfmove :: fullmove :: _ ->
            parseFenPieces pieces
                |> Result.andThen (\board ->
                    let
                        turnColor =
                            if turn == "w" then White else Black
                        
                        castlingRights =
                            { whiteKingside = String.contains "K" castling
                            , whiteQueenside = String.contains "Q" castling
                            , blackKingside = String.contains "k" castling
                            , blackQueenside = String.contains "q" castling
                            }
                        
                        enPassantTarget =
                            if enPassant == "-" then
                                Nothing
                            else
                                parseSquare enPassant
                        
                        halfmoveClock =
                            String.toInt halfmove |> Maybe.withDefault 0
                        
                        fullmoveNumber =
                            String.toInt fullmove |> Maybe.withDefault 1
                    in
                    Ok
                        { board = board
                        , turn = turnColor
                        , castlingRights = castlingRights
                        , enPassantTarget = enPassantTarget
                        , halfmoveClock = halfmoveClock
                        , fullmoveNumber = fullmoveNumber
                        , moveHistory = []
                        }
                )
        _ ->
            Err "Invalid FEN string"

parseFenPieces : String -> Result String (List (Maybe Piece))
parseFenPieces pieces =
    let
        ranks = String.split "/" pieces
    in
    if List.length ranks /= 8 then
        Err "Invalid FEN: wrong number of ranks"
    else
        let
            parseRank : String -> Result String (List (Maybe Piece))
            parseRank rank =
                String.toList rank
                    |> List.foldl
                        (\char acc ->
                            case acc of
                                Err e -> Err e
                                Ok squares ->
                                    case String.fromChar char |> String.toInt of
                                        Just n ->
                                            if n >= 1 && n <= 8 then
                                                Ok (squares ++ List.repeat n Nothing)
                                            else
                                                Err "Invalid FEN: invalid number"
                                        Nothing ->
                                            case charToPiece (String.fromChar char) of
                                                Just piece ->
                                                    Ok (squares ++ [Just piece])
                                                Nothing ->
                                                    Err ("Invalid piece character: " ++ String.fromChar char)
                        )
                        (Ok [])
            
            parsedRanks =
                ranks
                    |> List.reverse
                    |> List.map parseRank
                    |> List.foldr
                        (\rankResult acc ->
                            case (rankResult, acc) of
                                (Ok rank, Ok board) ->
                                    if List.length rank == 8 then
                                        Ok (board ++ rank)
                                    else
                                        Err "Invalid FEN: wrong rank length"
                                (Err e, _) ->
                                    Err e
                                (_, Err e) ->
                                    Err e
                        )
                        (Ok [])
        in
        parsedRanks

exportFen : GameState -> String
exportFen state =
    let
        piecesToFen =
            List.range 0 7
                |> List.reverse
                |> List.map (\row ->
                    List.range 0 7
                        |> List.foldl
                            (\col (emptyCount, str) ->
                                let
                                    square = positionToSquare row col
                                in
                                case getPiece state square of
                                    Nothing ->
                                        (emptyCount + 1, str)
                                    Just piece ->
                                        let
                                            newStr =
                                                if emptyCount > 0 then
                                                    str ++ String.fromInt emptyCount ++ pieceToChar piece
                                                else
                                                    str ++ pieceToChar piece
                                        in
                                        (0, newStr)
                            )
                            (0, "")
                        |> (\(emptyCount, str) ->
                            if emptyCount > 0 then
                                str ++ String.fromInt emptyCount
                            else
                                str
                        )
                )
                |> String.join "/"
        
        turn =
            case state.turn of
                White -> "w"
                Black -> "b"
        
        castling =
            let
                rights = state.castlingRights
                str =
                    (if rights.whiteKingside then "K" else "")
                        ++ (if rights.whiteQueenside then "Q" else "")
                        ++ (if rights.blackKingside then "k" else "")
                        ++ (if rights.blackQueenside then "q" else "")
            in
            if str == "" then "-" else str
        
        enPassant =
            case state.enPassantTarget of
                Nothing -> "-"
                Just square -> squareToString square
    in
    piecesToFen ++ " " ++ turn ++ " " ++ castling ++ " " ++ enPassant ++ " "
        ++ String.fromInt state.halfmoveClock ++ " " ++ String.fromInt state.fullmoveNumber

findKing : GameState -> Color -> Maybe Square
findKing state color =
    List.range 0 63
        |> List.filter (\square ->
            case getPiece state square of
                Just piece ->
                    piece.pieceType == King && piece.color == color
                Nothing ->
                    False
        )
        |> List.head
