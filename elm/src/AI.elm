module AI exposing (..)

import Types exposing (..)
import MoveGenerator exposing (..)
import Evaluation exposing (..)

minimax : GameState -> Int -> Int -> Int -> Bool -> Int
minimax state depth alpha beta maximizing =
    if depth == 0 then
        evaluateGameState state
    else
        let
            legalMoves = generateLegalMoves state
        in
        if List.isEmpty legalMoves then
            evaluateGameState state
        else if maximizing then
            minimaxMax state legalMoves depth alpha beta -999999
        else
            minimaxMin state legalMoves depth alpha beta 999999

minimaxMax : GameState -> List Move -> Int -> Int -> Int -> Int -> Int
minimaxMax state moves depth alpha beta maxEval =
    case moves of
        [] ->
            maxEval
        move :: rest ->
            if alpha >= beta then
                maxEval
            else
                let
                    newState = makeMove state move
                    eval = minimax newState (depth - 1) alpha beta False
                    newMaxEval = max maxEval eval
                    newAlpha = max alpha eval
                in
                minimaxMax state rest depth newAlpha beta newMaxEval

minimaxMin : GameState -> List Move -> Int -> Int -> Int -> Int -> Int
minimaxMin state moves depth alpha beta minEval =
    case moves of
        [] ->
            minEval
        move :: rest ->
            if alpha >= beta then
                minEval
            else
                let
                    newState = makeMove state move
                    eval = minimax newState (depth - 1) alpha beta True
                    newMinEval = min minEval eval
                    newBeta = min beta eval
                in
                minimaxMin state rest depth alpha newBeta newMinEval

findBestMove : GameState -> Int -> Maybe (Move, Int)
findBestMove state depth =
    let
        legalMoves = generateLegalMoves state
    in
    case legalMoves of
        [] ->
            Nothing
        _ ->
            let
                evaluateMove move =
                    let
                        newState = makeMove state move
                        eval = minimax newState (depth - 1) -999999 999999 (state.turn == Black)
                    in
                    (move, eval)
                
                movesWithEval = List.map evaluateMove legalMoves
                
                bestMove =
                    if state.turn == White then
                        List.foldl
                            (\(move, eval) (bestM, bestE) ->
                                if eval > bestE then
                                    (move, eval)
                                else
                                    (bestM, bestE)
                            )
                            (Maybe.withDefault (List.head legalMoves |> Maybe.withDefault 
                                { from = 0, to = 0, piece = Pawn, captured = Nothing, promotion = Nothing, castling = Nothing, enPassant = False })
                                (List.head legalMoves), -999999)
                            movesWithEval
                    else
                        List.foldl
                            (\(move, eval) (bestM, bestE) ->
                                if eval < bestE then
                                    (move, eval)
                                else
                                    (bestM, bestE)
                            )
                            (Maybe.withDefault (List.head legalMoves |> Maybe.withDefault 
                                { from = 0, to = 0, piece = Pawn, captured = Nothing, promotion = Nothing, castling = Nothing, enPassant = False })
                                (List.head legalMoves), 999999)
                            movesWithEval
            in
            Just bestMove
