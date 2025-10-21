port module ChessEngine exposing (..)

import Browser
import Json.Decode as Decode
import Json.Encode as Encode
import Types exposing (..)
import Board exposing (..)
import MoveGenerator exposing (..)
import Evaluation exposing (..)
import AI exposing (..)
import Utils exposing (..)
import Time

-- PORTS

port sendCommand : String -> Cmd msg
port receiveResponse : (String -> msg) -> Sub msg

-- MODEL

type alias Model =
    { state : GameState
    , history : List GameState
    }

init : () -> (Model, Cmd Msg)
init _ =
    ( { state = createInitialState
      , history = []
      }
    , sendCommand "Chess Engine - Elm Implementation\nType 'help' for available commands\n\n"
    )

-- UPDATE

type Msg
    = ProcessCommand String
    | NoOp

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        ProcessCommand input ->
            processCommand model input
        NoOp ->
            (model, Cmd.none)

processCommand : Model -> String -> (Model, Cmd Msg)
processCommand model input =
    let
        parts = String.split " " (String.trim input)
        command = List.head parts |> Maybe.withDefault ""
        args = List.drop 1 parts
    in
    case command of
        "move" ->
            case List.head args of
                Nothing ->
                    (model, sendCommand "ERROR: Invalid command\n")
                Just moveStr ->
                    executeMove model moveStr
        
        "undo" ->
            undoMove model
        
        "new" ->
            ( { state = createInitialState, history = [] }
            , sendCommand ("OK: New game started\n\n" ++ boardToString createInitialState ++ "\n")
            )
        
        "ai" ->
            let
                depth = 
                    List.head args
                        |> Maybe.andThen String.toInt
                        |> Maybe.withDefault 3
            in
            if depth < 1 || depth > 5 then
                (model, sendCommand "ERROR: AI depth must be 1-5\n")
            else
                executeAI model depth
        
        "fen" ->
            case String.join " " args of
                "" ->
                    (model, sendCommand "ERROR: Invalid FEN command\n")
                fenStr ->
                    case parseFen fenStr of
                        Ok newState ->
                            ( { state = newState, history = [] }
                            , sendCommand ("OK: Position loaded\n\n" ++ boardToString newState ++ "\n")
                            )
                        Err msg ->
                            (model, sendCommand ("ERROR: " ++ msg ++ "\n"))
        
        "export" ->
            let
                fen = exportFen model.state
            in
            (model, sendCommand ("FEN: " ++ fen ++ "\n"))
        
        "eval" ->
            let
                score = evaluateGameState model.state
            in
            (model, sendCommand ("Evaluation: " ++ String.fromInt score ++ "\n"))
        
        "perft" ->
            case List.head args |> Maybe.andThen String.toInt of
                Nothing ->
                    (model, sendCommand "ERROR: Invalid depth\n")
                Just depth ->
                    if depth < 1 || depth > 6 then
                        (model, sendCommand "ERROR: Depth must be 1-6\n")
                    else
                        executePerft model depth
        
        "help" ->
            (model, sendCommand helpText)
        
        "quit" ->
            (model, sendCommand "QUIT")
        
        _ ->
            if command == "" then
                (model, Cmd.none)
            else
                (model, sendCommand "ERROR: Invalid command. Type 'help' for available commands.\n")

executeMove : Model -> String -> (Model, Cmd Msg)
executeMove model moveStr =
    case parseMove moveStr of
        Nothing ->
            (model, sendCommand "ERROR: Invalid move format\n")
        Just (from, to, promotion) ->
            case getPiece model.state from of
                Nothing ->
                    (model, sendCommand "ERROR: No piece at source square\n")
                Just piece ->
                    if piece.color /= model.state.turn then
                        (model, sendCommand "ERROR: Wrong color piece\n")
                    else
                        let
                            legalMoves = generateLegalMoves model.state
                            matchingMove =
                                List.filter
                                    (\move ->
                                        move.from == from &&
                                        move.to == to &&
                                        (promotion == Nothing || move.promotion == promotion)
                                    )
                                    legalMoves
                                |> List.head
                        in
                        case matchingMove of
                            Nothing ->
                                (model, sendCommand "ERROR: Illegal move\n")
                            Just move ->
                                let
                                    newState = makeMove model.state move
                                    newModel = 
                                        { state = newState
                                        , history = model.state :: model.history
                                        }
                                    status = checkGameStatus newState
                                    statusMsg =
                                        case status of
                                            Checkmate winner ->
                                                let
                                                    winnerStr = if winner == White then "White" else "Black"
                                                in
                                                "\nCHECKMATE: " ++ winnerStr ++ " wins"
                                            Stalemate ->
                                                "\nSTALEMATE: Draw"
                                            _ ->
                                                ""
                                in
                                (newModel, sendCommand ("OK: " ++ moveStr ++ statusMsg ++ "\n\n" ++ boardToString newState ++ "\n"))

parseMove : String -> Maybe (Square, Square, Maybe PieceType)
parseMove moveStr =
    let
        len = String.length moveStr
    in
    if len < 4 || len > 5 then
        Nothing
    else
        let
            fromStr = String.left 2 moveStr
            toStr = String.slice 2 4 moveStr
            from = parseSquare fromStr
            to = parseSquare toStr
            promotion =
                if len == 5 then
                    case String.toLower (String.right 1 moveStr) of
                        "q" -> Just Queen
                        "r" -> Just Rook
                        "b" -> Just Bishop
                        "n" -> Just Knight
                        _ -> Nothing
                else
                    Nothing
        in
        Maybe.map2 (\f t -> (f, t, promotion)) from to

undoMove : Model -> (Model, Cmd Msg)
undoMove model =
    case model.history of
        [] ->
            (model, sendCommand "ERROR: No moves to undo\n")
        prevState :: rest ->
            let
                newModel = { state = prevState, history = rest }
            in
            (newModel, sendCommand ("OK: Move undone\n\n" ++ boardToString prevState ++ "\n"))

executeAI : Model -> Int -> (Model, Cmd Msg)
executeAI model depth =
    case findBestMove model.state depth of
        Nothing ->
            (model, sendCommand "ERROR: No legal moves available\n")
        Just (move, eval) ->
            let
                moveStr = squareToString move.from ++ squareToString move.to
                moveStrWithPromo =
                    case move.promotion of
                        Just Queen -> moveStr ++ "q"
                        Just Rook -> moveStr ++ "r"
                        Just Bishop -> moveStr ++ "b"
                        Just Knight -> moveStr ++ "n"
                        _ -> moveStr
                
                newState = makeMove model.state move
                newModel = 
                    { state = newState
                    , history = model.state :: model.history
                    }
                
                status = checkGameStatus newState
                statusMsg =
                    case status of
                        Checkmate winner ->
                            let
                                winnerStr = if winner == White then "White" else "Black"
                            in
                            "\nCHECKMATE: " ++ winnerStr ++ " wins"
                        Stalemate ->
                            "\nSTALEMATE: Draw"
                        _ ->
                            ""
                
                aiMsg = "AI: " ++ moveStrWithPromo ++ " (depth=" ++ String.fromInt depth ++ 
                       ", eval=" ++ String.fromInt eval ++ ")" ++ statusMsg
            in
            (newModel, sendCommand (aiMsg ++ "\n\n" ++ boardToString newState ++ "\n"))

executePerft : Model -> Int -> (Model, Cmd Msg)
executePerft model depth =
    let
        count = perft model.state depth
    in
    (model, sendCommand ("Perft(" ++ String.fromInt depth ++ "): " ++ String.fromInt count ++ " nodes\n"))

perft : GameState -> Int -> Int
perft state depth =
    if depth == 0 then
        1
    else
        let
            legalMoves = generateLegalMoves state
        in
        List.foldl
            (\move acc ->
                let
                    newState = makeMove state move
                in
                acc + perft newState (depth - 1)
            )
            0
            legalMoves

checkGameStatus : GameState -> GameStatus
checkGameStatus state =
    let
        legalMoves = generateLegalMoves state
    in
    if List.isEmpty legalMoves then
        if isKingInCheck state state.turn then
            Checkmate (oppositeColor state.turn)
        else
            Stalemate
    else
        InProgress

helpText : String
helpText =
    """Available commands:
  move <from><to>[promotion] - Make a move (e.g., e2e4, e7e8Q)
  undo - Undo the last move
  new - Start a new game
  ai <depth> - Let AI make a move (depth 1-5)
  fen <string> - Load position from FEN
  export - Export current position as FEN
  eval - Display position evaluation
  perft <depth> - Run performance test
  help - Display this help message
  quit - Exit the program
"""

-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions _ =
    receiveResponse ProcessCommand

-- MAIN

main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = \_ -> Browser.Document "Chess" []
        }
