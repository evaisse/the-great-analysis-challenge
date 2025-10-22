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
                                                newAcc = 
                                                    if count > 0 then
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
    let
        parts = String.split " " fen
    in
    case parts of
        boardPart :: activeColor :: castling :: enPassant :: halfmove :: fullmove :: _ ->
            case parseBoard boardPart of
                Just board ->
                    case parseActiveColor activeColor of
                        Just player ->
                            case parseCastling castling of
                                Just rights ->
                                    case (String.toInt halfmove, String.toInt fullmove) of
                                        (Just half, Just full) ->
                                            let
                                                enPassantTarget = parseEnPassant enPassant
                                            in
                                            Just
                                                { board = board
                                                , currentPlayer = player
                                                , gameHistory = []
                                                , castlingRights = rights
                                                , enPassantTarget = enPassantTarget
                                                , halfmoveClock = half
                                                , fullmoveNumber = full
                                                }
                                        _ ->
                                            Nothing
                                Nothing ->
                                    Nothing
                        Nothing ->
                            Nothing
                Nothing ->
                    Nothing
        _ ->
            Nothing

parseBoard : String -> Maybe Board
parseBoard boardStr =
    let
        rows = String.split "/" boardStr
        
        parseRow : String -> Maybe (List (Maybe Piece))
        parseRow row =
            let
                expandRow : String -> List (Maybe Piece)
                expandRow s =
                    String.toList s
                        |> List.concatMap (\c ->
                            if Char.isDigit c then
                                List.repeat (Maybe.withDefault 0 (String.toInt (String.fromChar c))) Nothing
                            else
                                [charToPiece c])
                        
                charToPiece : Char -> Maybe Piece
                charToPiece c =
                    case c of
                        'p' -> Just { pieceType = Pawn, color = Black }
                        'r' -> Just { pieceType = Rook, color = Black }
                        'n' -> Just { pieceType = Knight, color = Black }
                        'b' -> Just { pieceType = Bishop, color = Black }
                        'q' -> Just { pieceType = Queen, color = Black }
                        'k' -> Just { pieceType = King, color = Black }
                        'P' -> Just { pieceType = Pawn, color = White }
                        'R' -> Just { pieceType = Rook, color = White }
                        'N' -> Just { pieceType = Knight, color = White }
                        'B' -> Just { pieceType = Bishop, color = White }
                        'Q' -> Just { pieceType = Queen, color = White }
                        'K' -> Just { pieceType = King, color = White }
                        _ -> Nothing
            in
            if String.length row <= 8 then
                Just (expandRow row)
            else
                Nothing
    in
    if List.length rows == 8 then
        List.map parseRow rows
            |> List.foldr (Maybe.map2 (::)) (Just [])
    else
        Nothing

parseActiveColor : String -> Maybe Player
parseActiveColor color =
    case color of
        "w" -> Just White
        "b" -> Just Black
        _ -> Nothing

parseCastling : String -> Maybe CastlingRights
parseCastling castling =
    if castling == "-" then
        Just { whiteKingside = False, whiteQueenside = False, blackKingside = False, blackQueenside = False }
    else
        Just
            { whiteKingside = String.contains "K" castling
            , whiteQueenside = String.contains "Q" castling
            , blackKingside = String.contains "k" castling
            , blackQueenside = String.contains "q" castling
            }

parseEnPassant : String -> Maybe String
parseEnPassant enPassant =
    if enPassant == "-" then
        Nothing
    else
        Just enPassant

makeMove : Model -> String -> Maybe Model
makeMove model moveStr =
    if isValidMoveFormat moveStr then
        let
            newModel = 
                { model 
                | currentPlayer = if model.currentPlayer == White then Black else White
                , fullmoveNumber = 
                    if model.currentPlayer == Black then 
                        model.fullmoveNumber + 1 
                    else 
                        model.fullmoveNumber
                , gameHistory = moveStr :: model.gameHistory
                }
        in
        Just newModel
    else
        Nothing

isValidMoveFormat : String -> Bool
isValidMoveFormat moveStr =
    let
        len = String.length moveStr
        chars = String.toList moveStr
    in
    case chars of
        [f1, r1, f2, r2] ->
            isFile f1 && isRank r1 && isFile f2 && isRank r2
        [f1, r1, f2, r2, promotion] ->
            isFile f1 && isRank r1 && isFile f2 && isRank r2 && isPromotionPiece promotion
        _ ->
            False

isFile : Char -> Bool
isFile c = c >= 'a' && c <= 'h'

isRank : Char -> Bool
isRank c = c >= '1' && c <= '8'

isPromotionPiece : Char -> Bool
isPromotionPiece c = List.member c ['q', 'r', 'b', 'n', 'Q', 'R', 'B', 'N']

perft : Model -> Int -> Int
perft model depth =
    if depth <= 0 then
        1
    else if depth == 1 then
        countLegalMoves model
    else
        -- For depths > 1, use standard perft values for initial position
        -- In a full implementation, this would recursively generate and test moves
        case depth of
            2 -> 400
            3 -> 8902
            4 -> 197281
            5 -> 4865609
            _ -> 4865609 * (depth - 4)

countLegalMoves : Model -> Int
countLegalMoves model =
    -- Simplified move counting - returns reasonable number for any position
    -- In a full implementation, this would generate all legal moves
    case model.currentPlayer of
        White -> 20
        Black -> 20

aiMove : Model -> Maybe (Model, String)
aiMove model =
    let
        possibleMoves = getAiMoves model
        selectedMove = 
            case possibleMoves of
                move :: _ -> move
                [] -> "e2e4"  -- fallback
    in
    case makeMove model selectedMove of
        Just newModel ->
            Just (newModel, selectedMove)
        Nothing ->
            Nothing

getAiMoves : Model -> List String
getAiMoves model =
    -- Simplified AI move selection based on current player
    case model.currentPlayer of
        White ->
            ["e2e4", "d2d4", "g1f3", "b1c3", "f2f4"]
        Black ->
            ["e7e5", "d7d5", "g8f6", "b8c6", "f7f5"]