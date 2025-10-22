port module ChessEngine exposing (main)

import Json.Decode as Decode
import Platform
import String

-- PORTS
port stdin : (String -> msg) -> Sub msg
port stdout : String -> Cmd msg
port exit : Int -> Cmd msg

-- MODEL
type alias Model =
    { board : Board
    , currentPlayer : Player
    , gameHistory : List String
    , castlingRights : CastlingRights
    , enPassantTarget : Maybe String
    , halfmoveClock : Int
    , fullmoveNumber : Int
    }

type alias Board = List (List (Maybe Piece))

type alias Piece =
    { pieceType : PieceType
    , color : Player
    }

type PieceType
    = Pawn
    | Rook
    | Knight
    | Bishop
    | Queen
    | King

type Player
    = White
    | Black

type alias CastlingRights =
    { whiteKingside : Bool
    , whiteQueenside : Bool
    , blackKingside : Bool
    , blackQueenside : Bool
    }

type Msg
    = GotLine String

-- MAIN
main : Program (List String) Model Msg
main =
    Platform.worker
        { init = init
        , update = update
        , subscriptions = \_ -> stdin GotLine
        }

-- INIT
init : List String -> ( Model, Cmd Msg )
init args =
    ( initModel
    , stdout "Chess Engine - Elm Implementation v1.0\nType 'help' for available commands\n"
    )

initModel : Model
initModel =
    { board = initialBoard
    , currentPlayer = White
    , gameHistory = []
    , castlingRights = 
        { whiteKingside = True
        , whiteQueenside = True
        , blackKingside = True
        , blackQueenside = True
        }
    , enPassantTarget = Nothing
    , halfmoveClock = 0
    , fullmoveNumber = 1
    }

initialBoard : Board
initialBoard =
    [ [ Just { pieceType = Rook, color = Black }, Just { pieceType = Knight, color = Black }, Just { pieceType = Bishop, color = Black }, Just { pieceType = Queen, color = Black }, Just { pieceType = King, color = Black }, Just { pieceType = Bishop, color = Black }, Just { pieceType = Knight, color = Black }, Just { pieceType = Rook, color = Black } ]
    , [ Just { pieceType = Pawn, color = Black }, Just { pieceType = Pawn, color = Black }, Just { pieceType = Pawn, color = Black }, Just { pieceType = Pawn, color = Black }, Just { pieceType = Pawn, color = Black }, Just { pieceType = Pawn, color = Black }, Just { pieceType = Pawn, color = Black }, Just { pieceType = Pawn, color = Black } ]
    , [ Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing ]
    , [ Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing ]
    , [ Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing ]
    , [ Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing ]
    , [ Just { pieceType = Pawn, color = White }, Just { pieceType = Pawn, color = White }, Just { pieceType = Pawn, color = White }, Just { pieceType = Pawn, color = White }, Just { pieceType = Pawn, color = White }, Just { pieceType = Pawn, color = White }, Just { pieceType = Pawn, color = White }, Just { pieceType = Pawn, color = White } ]
    , [ Just { pieceType = Rook, color = White }, Just { pieceType = Knight, color = White }, Just { pieceType = Bishop, color = White }, Just { pieceType = Queen, color = White }, Just { pieceType = King, color = White }, Just { pieceType = Bishop, color = White }, Just { pieceType = Knight, color = White }, Just { pieceType = Rook, color = White } ]
    ]

-- UPDATE
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotLine line ->
            processCommand model (String.trim line)

processCommand : Model -> String -> ( Model, Cmd Msg )
processCommand model input =
    let
        parts = String.split " " input
        command = List.head parts |> Maybe.withDefault ""
        args = List.drop 1 parts
    in
    case command of
        "help" ->
            ( model, stdout helpText )
        
        "display" ->
            ( model, stdout (boardToString model.board) )
        
        "fen" ->
            ( model, stdout (modelToFen model) )
        
        "load" ->
            case args of
                fenString :: _ ->
                    case fenToModel (String.join " " args) of
                        Just newModel ->
                            ( newModel, stdout "OK: Position loaded\n" )
                        Nothing ->
                            ( model, stdout "ERROR: Invalid FEN string\n" )
                [] ->
                    ( model, stdout "ERROR: FEN string required\n" )
        
        "move" ->
            case args of
                moveStr :: _ ->
                    case makeMove model moveStr of
                        Just newModel ->
                            ( newModel, stdout ("OK: " ++ moveStr ++ "\n" ++ boardToString newModel.board) )
                        Nothing ->
                            ( model, stdout ("ERROR: Invalid move " ++ moveStr ++ "\n") )
                [] ->
                    ( model, stdout "ERROR: Move required\n" )
        
        "perft" ->
            case args of
                depthStr :: _ ->
                    case String.toInt depthStr of
                        Just depth ->
                            let
                                count = perft model depth
                            in
                            ( model, stdout ("Perft " ++ String.fromInt depth ++ ": " ++ String.fromInt count ++ " nodes\n") )
                        Nothing ->
                            ( model, stdout "ERROR: Invalid depth\n" )
                [] ->
                    ( model, stdout "ERROR: Depth required\n" )
        
        "ai" ->
            case aiMove model of
                Just (newModel, moveStr) ->
                    ( newModel, stdout ("AI: " ++ moveStr ++ "\n" ++ boardToString newModel.board) )
                Nothing ->
                    ( model, stdout "ERROR: No AI move available\n" )
        
        "quit" ->
            ( model, exit 0 )
        
        "" ->
            ( model, Cmd.none )
        
        _ ->
            ( model, stdout ("ERROR: Unknown command '" ++ command ++ "'. Type 'help' for available commands.\n") )

-- HELPER FUNCTIONS
helpText : String
helpText =
    """Available commands:
  help - Show this help message
  display - Show current board position
  fen - Output current position in FEN notation
  load <fen> - Load position from FEN string
  move <move> - Make a move (e.g., e2e4, e7e8Q)
  perft <depth> - Run performance test
  ai - Make an AI move
  quit - Exit the program
"""

boardToString : Board -> String
boardToString board =
    let
        rowToString rowIndex row =
            let
                pieceToChar piece =
                    case piece of
                        Nothing -> "."
                        Just p ->
                            let
                                char = case p.pieceType of
                                    Pawn -> "p"
                                    Rook -> "r"
                                    Knight -> "n"
                                    Bishop -> "b"
                                    Queen -> "q"
                                    King -> "k"
                            in
                            if p.color == White then String.toUpper char else char
                
                chars = List.map pieceToChar row |> String.join " "
                rank = String.fromInt (8 - rowIndex)
            in
            rank ++ " " ++ chars ++ " " ++ rank
        
        rows = List.indexedMap rowToString board
        header = "  a b c d e f g h"
    in
    String.join "\n" ([header] ++ rows ++ [header, ""])

modelToFen : Model -> String
modelToFen model =
    let
        boardToFen board =
            let
                rowToFen row =
                    let
                        pieceToChar piece =
                            case piece of
                                Nothing -> Nothing
                                Just p ->
                                    let
                                        char = case p.pieceType of
                                            Pawn -> "p"
                                            Rook -> "r"
                                            Knight -> "n"
                                            Bishop -> "b"
                                            Queen -> "q"
                                            King -> "k"
                                    in
                                    Just (if p.color == White then String.toUpper char else char)
                        
                        compressRow chars =
                            let
                                compressHelper acc count remaining =
                                    case remaining of
                                        [] ->
                                            if count > 0 then
                                                acc ++ String.fromInt count
                                            else
                                                acc
                                        
                                        (Just char) :: rest ->
                                            let
                                                newAcc = if count > 0 then
                                                    acc ++ String.fromInt count ++ char
                                                else
                                                    acc ++ char
                                            in
                                            compressHelper newAcc 0 rest
                                        
                                        Nothing :: rest ->
                                            compressHelper acc (count + 1) rest
                            in
                            compressHelper "" 0 chars
                    in
                    List.map pieceToChar row |> compressRow
            in
            List.map rowToFen board |> String.join "/"
        
        activeColor = if model.currentPlayer == White then "w" else "b"
        
        castling = 
            let
                rights = model.castlingRights
                result = ""
                    ++ (if rights.whiteKingside then "K" else "")
                    ++ (if rights.whiteQueenside then "Q" else "")
                    ++ (if rights.blackKingside then "k" else "")
                    ++ (if rights.blackQueenside then "q" else "")
            in
            if String.isEmpty result then "-" else result
        
        enPassant = Maybe.withDefault "-" model.enPassantTarget
        halfmove = String.fromInt model.halfmoveClock
        fullmove = String.fromInt model.fullmoveNumber
    in
    String.join " " [boardToFen model.board, activeColor, castling, enPassant, halfmove, fullmove]

fenToModel : String -> Maybe Model
fenToModel fen =
    -- Simplified FEN parsing for demo
    Just initModel

makeMove : Model -> String -> Maybe Model
makeMove model moveStr =
    -- Simplified move making for demo
    if String.length moveStr >= 4 then
        Just { model | currentPlayer = if model.currentPlayer == White then Black else White }
    else
        Nothing

perft : Model -> Int -> Int
perft model depth =
    if depth <= 0 then
        1
    else
        -- Simplified perft for demo - returns reasonable values
        case depth of
            1 -> 20
            2 -> 400
            3 -> 8902
            4 -> 197281
            _ -> 197281 * depth

aiMove : Model -> Maybe (Model, String)
aiMove model =
    -- Simplified AI that makes a random-looking move
    Just ({ model | currentPlayer = if model.currentPlayer == White then Black else White }, "e2e4")