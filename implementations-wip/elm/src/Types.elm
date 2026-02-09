module Types exposing (..)

type PieceType
    = King
    | Queen
    | Rook
    | Bishop
    | Knight
    | Pawn

type Color
    = White
    | Black

type alias Piece =
    { pieceType : PieceType
    , color : Color
    }

type alias Square =
    Int

type alias Position =
    { row : Int
    , col : Int
    }

type alias Move =
    { from : Square
    , to : Square
    , piece : PieceType
    , captured : Maybe PieceType
    , promotion : Maybe PieceType
    , castling : Maybe String
    , enPassant : Bool
    }

type alias CastlingRights =
    { whiteKingside : Bool
    , whiteQueenside : Bool
    , blackKingside : Bool
    , blackQueenside : Bool
    }

type alias GameState =
    { board : List (Maybe Piece)
    , turn : Color
    , castlingRights : CastlingRights
    , enPassantTarget : Maybe Square
    , halfmoveClock : Int
    , fullmoveNumber : Int
    , moveHistory : List Move
    }

type GameStatus
    = InProgress
    | Checkmate Color
    | Stalemate
    | Draw

type alias SearchResult =
    { bestMove : Maybe Move
    , evaluation : Int
    , nodes : Int
    , timeMs : Int
    }
