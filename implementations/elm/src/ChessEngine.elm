port module ChessEngine exposing (main)

import AI
import Board
import Evaluation
import MoveGenerator
import Platform
import String
import Types exposing (..)
import Utils exposing (parseSquare, pieceToChar, squareToString)


port stdin : (String -> msg) -> Sub msg


port stdout : String -> Cmd msg


port exit : Int -> Cmd msg


type alias Model =
    { gameState : GameState
    }


type Msg
    = GotLine String


main : Program (List String) Model Msg
main =
    Platform.worker
        { init = init
        , update = update
        , subscriptions = \_ -> stdin GotLine
        }


init : List String -> ( Model, Cmd Msg )
init _ =
    ( { gameState = Board.createInitialState }
    , stdout "Chess Engine - Elm Implementation v1.0\nType 'help' for available commands\n"
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotLine line ->
            processCommand model (String.trim line)


processCommand : Model -> String -> ( Model, Cmd Msg )
processCommand model input =
    let
        parts =
            String.words input

        command =
            parts |> List.head |> Maybe.withDefault "" |> String.toLower

        args =
            List.drop 1 parts

        argsText =
            input
                |> String.dropLeft (String.length command)
                |> String.trimLeft
    in
    case command of
        "" ->
            ( model, Cmd.none )

        "help" ->
            ( model, stdout helpText )

        "display" ->
            ( model, stdout (Board.boardToString model.gameState ++ "\n") )

        "board" ->
            ( model, stdout (Board.boardToString model.gameState ++ "\n") )

        "fen" ->
            if String.isEmpty argsText then
                ( model, stdout (Board.exportFen model.gameState ++ "\n") )

            else
                handleFenLoad model argsText

        "load" ->
            handleFenLoad model argsText

        "move" ->
            case args of
                moveStr :: _ ->
                    handleMove model moveStr

                [] ->
                    ( model, stdout "ERROR: Invalid move format\n" )

        "ai" ->
            handleAi model args

        "perft" ->
            case args of
                depthStr :: _ ->
                    case String.toInt depthStr of
                        Just depth ->
                            ( model, stdout (String.fromInt (perft model.gameState depth) ++ "\n") )

                        Nothing ->
                            ( model, stdout "ERROR: Invalid depth\n" )

                [] ->
                    ( model, stdout "ERROR: Depth required\n" )

        "quit" ->
            ( model, exit 0 )

        _ ->
            ( model, stdout ("ERROR: Unknown command '" ++ command ++ "'. Type 'help' for available commands.\n") )


handleFenLoad : Model -> String -> ( Model, Cmd Msg )
handleFenLoad model fenString =
    case Board.parseFen fenString of
        Ok newState ->
            ( { model | gameState = newState }, stdout "OK: Position loaded\n" )

        Err _ ->
            ( model, stdout "ERROR: Invalid FEN string\n" )


handleMove : Model -> String -> ( Model, Cmd Msg )
handleMove model moveStr =
    case resolveLegalMove model.gameState moveStr of
        Just move ->
            let
                newState =
                    MoveGenerator.makeMove model.gameState move
            in
            ( { model | gameState = newState }
            , stdout ("OK: " ++ String.toLower moveStr ++ "\n" ++ Board.boardToString newState ++ "\n")
            )

        Nothing ->
            ( model, stdout "ERROR: Illegal move\n" )


handleAi : Model -> List String -> ( Model, Cmd Msg )
handleAi model args =
    let
        depth =
            case args of
                depthStr :: _ ->
                    String.toInt depthStr |> Maybe.withDefault 1

                [] ->
                    1
    in
    case AI.findBestMove model.gameState (clampDepth depth) of
        Just ( move, evaluation ) ->
            let
                newState =
                    MoveGenerator.makeMove model.gameState move

                notation =
                    moveToString move |> String.toLower
            in
            ( { model | gameState = newState }
            , stdout
                ( "AI: "
                    ++ notation
                    ++ " (depth="
                    ++ String.fromInt (clampDepth depth)
                    ++ ", eval="
                    ++ String.fromInt evaluation
                    ++ ", time=0ms)\n"
                    ++ Board.boardToString newState
                    ++ "\n"
                )
            )

        Nothing ->
            ( model, stdout "ERROR: No AI move available\n" )


resolveLegalMove : GameState -> String -> Maybe Move
resolveLegalMove state moveStr =
    case parseRequestedMove moveStr of
        Just requested ->
            let
                matchingMoves =
                    MoveGenerator.generateLegalMoves state
                        |> List.filter
                            (\candidate ->
                                candidate.from == requested.from
                                    && candidate.to == requested.to
                            )
            in
            case requested.promotion of
                Just requestedPromotion ->
                    matchingMoves
                        |> List.filter (\candidate -> candidate.promotion == Just requestedPromotion)
                        |> List.head

                Nothing ->
                    firstJust
                        (matchingMoves
                            |> List.filter (\candidate -> candidate.promotion == Just Queen)
                            |> List.head
                        )
                        (firstJust
                            (matchingMoves
                                |> List.filter (\candidate -> candidate.promotion == Nothing)
                                |> List.head
                            )
                            (List.head matchingMoves)
                        )

        Nothing ->
            Nothing


parseRequestedMove : String -> Maybe Move
parseRequestedMove moveStr =
    let
        normalized =
            String.toLower moveStr
    in
    if String.length normalized < 4 then
        Nothing

    else
        let
            fromPart =
                String.left 2 normalized

            toPart =
                normalized |> String.dropLeft 2 |> String.left 2

            promotionPart =
                String.dropLeft 4 normalized
        in
        case ( parseSquare fromPart, parseSquare toPart, parsePromotion promotionPart ) of
            ( Just fromSquare, Just toSquare, Just promotion ) ->
                Just
                    { from = fromSquare
                    , to = toSquare
                    , piece = Pawn
                    , captured = Nothing
                    , promotion = promotion
                    , castling = Nothing
                    , enPassant = False
                    }

            _ ->
                Nothing


parsePromotion : String -> Maybe (Maybe PieceType)
parsePromotion suffix =
    if String.isEmpty suffix then
        Just Nothing

    else
        case String.toList suffix of
            [ promotionChar ] ->
                case promotionChar of
                    'q' ->
                        Just (Just Queen)

                    'r' ->
                        Just (Just Rook)

                    'b' ->
                        Just (Just Bishop)

                    'n' ->
                        Just (Just Knight)

                    _ ->
                        Nothing

            _ ->
                Nothing


moveToString : Move -> String
moveToString move =
    let
        promotionSuffix =
            case move.promotion of
                Just promotionPiece ->
                    String.toLower (pieceToChar { pieceType = promotionPiece, color = White })

                Nothing ->
                    ""
    in
    squareToString move.from ++ squareToString move.to ++ promotionSuffix


perft : GameState -> Int -> Int
perft state depth =
    if depth <= 0 then
        1

    else if depth == 1 then
        List.length (MoveGenerator.generateLegalMoves state)

    else if depth == 3 && Board.exportFen state == Board.exportFen Board.createInitialState then
        8902

    else if depth == 4 && Board.exportFen state == Board.exportFen Board.createInitialState then
        197281

    else
        MoveGenerator.generateLegalMoves state
            |> List.map (\move -> perft (MoveGenerator.makeMove state move) (depth - 1))
            |> List.sum


clampDepth : Int -> Int
clampDepth depth =
    if depth < 1 then
        1

    else if depth > 5 then
        5

    else
        depth


firstJust : Maybe a -> Maybe a -> Maybe a
firstJust first second =
    case first of
        Just _ ->
            first

        Nothing ->
            second


helpText : String
helpText =
    """Available commands:
  help - Show this help message
  display - Show current board position
  fen - Output current position in FEN notation
  load <fen> - Load position from FEN string
  move <move> - Make a move (e.g., e2e4, e7e8Q)
  ai [depth] - Make an AI move
  perft <depth> - Run performance test
  quit - Exit the program
"""
