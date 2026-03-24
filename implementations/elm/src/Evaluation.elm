module Evaluation exposing (..)

import AttackTables
import Types exposing (..)
import Utils exposing (..)
import Board exposing (..)
import MoveGenerator exposing (..)

evaluateMaterial : GameState -> Int
evaluateMaterial state =
    List.range 0 63
        |> List.foldl
            (\square acc ->
                case getPiece state square of
                    Nothing ->
                        acc
                    Just piece ->
                        let
                            value = getPieceValue piece.pieceType
                        in
                        if piece.color == White then
                            acc + value
                        else
                            acc - value
            )
            0

evaluatePosition : GameState -> Int
evaluatePosition state =
    let
        materialScore = evaluateMaterial state
        
        -- Center control bonus
        centerSquares = [27, 28, 35, 36]  -- d4, e4, d5, e5
        centerBonus =
            centerSquares
                |> List.foldl
                    (\square acc ->
                        case getPiece state square of
                            Just piece ->
                                if piece.color == White then
                                    acc + 10
                                else
                                    acc - 10
                            Nothing ->
                                acc
                    )
                    0
        
        -- Pawn advancement bonus
        pawnBonus =
            List.range 0 63
                |> List.foldl
                    (\square acc ->
                        case getPiece state square of
                            Just piece ->
                                if piece.pieceType == Pawn then
                                    let
                                        row = square // 8
                                        bonus = if piece.color == White then row * 5 else (7 - row) * 5
                                    in
                                    if piece.color == White then
                                        acc + bonus
                                    else
                                        acc - bonus
                                else
                                    acc
                            Nothing ->
                                acc
                    )
                    0

        whiteKing =
            findKing state White

        blackKing =
            findKing state Black

        nonPawnPieces =
            List.range 0 63
                |> List.foldl
                    (\square acc ->
                        case getPiece state square of
                            Just piece ->
                                if piece.pieceType /= Pawn && piece.pieceType /= King then
                                    acc + 1

                                else
                                    acc

                            Nothing ->
                                acc
                    )
                    0

        queenCount =
            List.range 0 63
                |> List.foldl
                    (\square acc ->
                        case getPiece state square of
                            Just piece ->
                                if piece.pieceType == Queen then
                                    acc + 1

                                else
                                    acc

                            Nothing ->
                                acc
                    )
                    0

        endgameBonus =
            if nonPawnPieces <= 4 || (nonPawnPieces <= 6 && queenCount == 0) then
                case ( whiteKing, blackKing ) of
                    ( Just whiteKingSquare, Just blackKingSquare ) ->
                        14 - AttackTables.manhattanDistance whiteKingSquare blackKingSquare

                    _ ->
                        0

            else
                0
    in
    materialScore + centerBonus + pawnBonus + endgameBonus

evaluateGameState : GameState -> Int
evaluateGameState state =
    let
        legalMoves = generateLegalMoves state
    in
    if List.isEmpty legalMoves then
        if isKingInCheck state state.turn then
            -- Checkmate
            if state.turn == White then
                -100000
            else
                100000
        else
            -- Stalemate
            0
    else
        evaluatePosition state
