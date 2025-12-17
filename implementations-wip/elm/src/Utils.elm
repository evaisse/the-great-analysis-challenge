module Utils exposing (..)

import Types exposing (..)

squareToPosition : Square -> Position
squareToPosition square =
    { row = square // 8
    , col = modBy 8 square
    }

positionToSquare : Int -> Int -> Square
positionToSquare row col =
    row * 8 + col

squareToString : Square -> String
squareToString square =
    let
        pos = squareToPosition square
        file = String.fromChar (Char.fromCode (97 + pos.col))
        rank = String.fromInt (pos.row + 1)
    in
    file ++ rank

parseSquare : String -> Maybe Square
parseSquare str =
    if String.length str /= 2 then
        Nothing
    else
        let
            fileChar = String.left 1 str
            rankChar = String.right 1 str
            file = Char.toCode (String.uncons fileChar |> Maybe.map Tuple.first |> Maybe.withDefault 'a') - 97
            rank = String.toInt rankChar
        in
        case rank of
            Just r ->
                if file >= 0 && file < 8 && r >= 1 && r <= 8 then
                    Just (positionToSquare (r - 1) file)
                else
                    Nothing
            Nothing ->
                Nothing

pieceToChar : Piece -> String
pieceToChar piece =
    let
        char =
            case piece.pieceType of
                King -> "k"
                Queen -> "q"
                Rook -> "r"
                Bishop -> "b"
                Knight -> "n"
                Pawn -> "p"
    in
    case piece.color of
        White -> String.toUpper char
        Black -> char

charToPiece : String -> Maybe Piece
charToPiece char =
    let
        lower = String.toLower char
        pieceType =
            case lower of
                "k" -> Just King
                "q" -> Just Queen
                "r" -> Just Rook
                "b" -> Just Bishop
                "n" -> Just Knight
                "p" -> Just Pawn
                _ -> Nothing
    in
    case pieceType of
        Just pt ->
            let
                color =
                    if char == String.toUpper char then
                        White
                    else
                        Black
            in
            Just { pieceType = pt, color = color }
        Nothing ->
            Nothing

oppositeColor : Color -> Color
oppositeColor color =
    case color of
        White -> Black
        Black -> White

isValidSquare : Int -> Int -> Bool
isValidSquare row col =
    row >= 0 && row < 8 && col >= 0 && col < 8

getPieceValue : PieceType -> Int
getPieceValue pieceType =
    case pieceType of
        Pawn -> 100
        Knight -> 320
        Bishop -> 330
        Rook -> 500
        Queen -> 900
        King -> 20000

getAt : Int -> List a -> Maybe a
getAt index list =
    list
        |> List.drop index
        |> List.head

setAt : Int -> a -> List a -> List a
setAt index value list =
    List.indexedMap
        (\i item ->
            if i == index then
                value
            else
                item
        )
        list
