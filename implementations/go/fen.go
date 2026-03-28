package main

import (
	"fmt"
	"strconv"
	"strings"
)

func (gs *GameState) castlingFEN() string {
	if gs.Chess960Mode {
		whiteFiles := make([]int, 0, 2)
		blackFiles := make([]int, 0, 2)
		if gs.CastlingRights[White][QueensideCastle] {
			whiteFiles = append(whiteFiles, gs.CastlingConfig.RookFile[White][QueensideCastle])
		}
		if gs.CastlingRights[White][KingsideCastle] {
			whiteFiles = append(whiteFiles, gs.CastlingConfig.RookFile[White][KingsideCastle])
		}
		if gs.CastlingRights[Black][QueensideCastle] {
			blackFiles = append(blackFiles, gs.CastlingConfig.RookFile[Black][QueensideCastle])
		}
		if gs.CastlingRights[Black][KingsideCastle] {
			blackFiles = append(blackFiles, gs.CastlingConfig.RookFile[Black][KingsideCastle])
		}

		var b strings.Builder
		for _, file := range sortedInts(whiteFiles) {
			b.WriteByte(byte('A' + file))
		}
		for _, file := range sortedInts(blackFiles) {
			b.WriteByte(byte('a' + file))
		}
		if b.Len() == 0 {
			return "-"
		}
		return b.String()
	}

	var castling strings.Builder
	if gs.CastlingRights[White][KingsideCastle] {
		castling.WriteRune('K')
	}
	if gs.CastlingRights[White][QueensideCastle] {
		castling.WriteRune('Q')
	}
	if gs.CastlingRights[Black][KingsideCastle] {
		castling.WriteRune('k')
	}
	if gs.CastlingRights[Black][QueensideCastle] {
		castling.WriteRune('q')
	}
	if castling.Len() == 0 {
		return "-"
	}
	return castling.String()
}

func sortedInts(values []int) []int {
	if len(values) == 0 {
		return values
	}
	cloned := make([]int, len(values))
	copy(cloned, values)
	for i := 0; i < len(cloned); i++ {
		for j := i + 1; j < len(cloned); j++ {
			if cloned[j] < cloned[i] {
				cloned[i], cloned[j] = cloned[j], cloned[i]
			}
		}
	}
	return cloned
}

func (gs *GameState) ToFEN() string {
	var fenParts []string

	// Board position
	var boardStr strings.Builder
	for rank := 7; rank >= 0; rank-- {
		emptyCount := 0
		for file := 0; file < 8; file++ {
			piece := gs.Board[rank][file]
			if piece.IsEmpty() {
				emptyCount++
			} else {
				if emptyCount > 0 {
					boardStr.WriteString(strconv.Itoa(emptyCount))
					emptyCount = 0
				}
				boardStr.WriteRune(piece.Symbol())
			}
		}
		if emptyCount > 0 {
			boardStr.WriteString(strconv.Itoa(emptyCount))
		}
		if rank > 0 {
			boardStr.WriteRune('/')
		}
	}
	fenParts = append(fenParts, boardStr.String())

	// Active color
	if gs.ActiveColor == White {
		fenParts = append(fenParts, "w")
	} else {
		fenParts = append(fenParts, "b")
	}

	// Castling availability
	fenParts = append(fenParts, gs.castlingFEN())

	// En passant target
	if gs.EnPassantTarget != nil {
		fenParts = append(fenParts, gs.EnPassantTarget.ToAlgebraic())
	} else {
		fenParts = append(fenParts, "-")
	}

	// Halfmove clock
	fenParts = append(fenParts, strconv.Itoa(gs.HalfmoveClock))

	// Fullmove number
	fenParts = append(fenParts, strconv.Itoa(gs.FullmoveNumber))

	return strings.Join(fenParts, " ")
}

func (gs *GameState) FromFEN(fen string) error {
	parts := strings.Fields(fen)
	if len(parts) != 6 {
		return fmt.Errorf("invalid FEN: expected 6 parts, got %d", len(parts))
	}

	// Clear the board
	for rank := 0; rank < 8; rank++ {
		for file := 0; file < 8; file++ {
			gs.Board[rank][file] = Piece{Type: Empty}
		}
	}

	// Parse board position
	ranks := strings.Split(parts[0], "/")
	if len(ranks) != 8 {
		return fmt.Errorf("invalid FEN: expected 8 ranks, got %d", len(ranks))
	}

	for rankIdx, rankStr := range ranks {
		rank := 7 - rankIdx // FEN starts from rank 8 (index 7)
		file := 0

		for _, char := range rankStr {
			if char >= '1' && char <= '8' {
				// Empty squares
				emptySquares := int(char - '0')
				file += emptySquares
			} else {
				// Piece
				piece, err := pieceFromSymbol(char)
				if err != nil {
					return fmt.Errorf("invalid piece symbol in FEN: %c", char)
				}
				if file >= 8 {
					return fmt.Errorf("invalid FEN: too many pieces in rank")
				}
				gs.Board[rank][file] = piece
				file++
			}
		}

		if file != 8 {
			return fmt.Errorf("invalid FEN: incomplete rank %d", rankIdx)
		}
	}

	// Parse active color
	switch parts[1] {
	case "w":
		gs.ActiveColor = White
	case "b":
		gs.ActiveColor = Black
	default:
		return fmt.Errorf("invalid active color in FEN: %s", parts[1])
	}

	// Parse castling rights
	gs.CastlingRights = [2][2]bool{{false, false}, {false, false}}
	gs.CastlingConfig = DefaultCastlingConfig()
	gs.Chess960Mode = false
	if file, ok := gs.FindHomeRankPiece(White, King); ok {
		gs.CastlingConfig.KingFile[White] = file
	}
	if file, ok := gs.FindHomeRankPiece(Black, King); ok {
		gs.CastlingConfig.KingFile[Black] = file
	}
	if parts[2] != "-" {
		for _, char := range parts[2] {
			switch char {
			case 'K':
				gs.CastlingRights[White][KingsideCastle] = true
			case 'Q':
				gs.CastlingRights[White][QueensideCastle] = true
			case 'k':
				gs.CastlingRights[Black][KingsideCastle] = true
			case 'q':
				gs.CastlingRights[Black][QueensideCastle] = true
			case 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H':
				rookFile := int(char - 'A')
				gs.Chess960Mode = true
				if rookFile > gs.CastlingConfig.KingFile[White] {
					gs.CastlingRights[White][KingsideCastle] = true
					gs.CastlingConfig.RookFile[White][KingsideCastle] = rookFile
				} else {
					gs.CastlingRights[White][QueensideCastle] = true
					gs.CastlingConfig.RookFile[White][QueensideCastle] = rookFile
				}
			case 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h':
				rookFile := int(char - 'a')
				gs.Chess960Mode = true
				if rookFile > gs.CastlingConfig.KingFile[Black] {
					gs.CastlingRights[Black][KingsideCastle] = true
					gs.CastlingConfig.RookFile[Black][KingsideCastle] = rookFile
				} else {
					gs.CastlingRights[Black][QueensideCastle] = true
					gs.CastlingConfig.RookFile[Black][QueensideCastle] = rookFile
				}
			default:
				return fmt.Errorf("invalid castling rights in FEN: %c", char)
			}
		}
	}

	// Parse en passant target
	if parts[3] != "-" {
		square := AlgebraicToSquare(parts[3])
		if !square.IsValid() {
			return fmt.Errorf("invalid en passant target in FEN: %s", parts[3])
		}
		gs.EnPassantTarget = &square
	} else {
		gs.EnPassantTarget = nil
	}

	// Parse halfmove clock
	halfmove, err := strconv.Atoi(parts[4])
	if err != nil {
		return fmt.Errorf("invalid halfmove clock in FEN: %s", parts[4])
	}
	gs.HalfmoveClock = halfmove

	// Parse fullmove number
	fullmove, err := strconv.Atoi(parts[5])
	if err != nil {
		return fmt.Errorf("invalid fullmove number in FEN: %s", parts[5])
	}
	gs.FullmoveNumber = fullmove
	gs.ZobristHash = computeZobristHash(gs)

	return nil
}

func pieceFromSymbol(symbol rune) (Piece, error) {
	var pieceType PieceType
	var color Color

	// Determine color (uppercase = white, lowercase = black)
	if symbol >= 'A' && symbol <= 'Z' {
		color = White
		symbol = rune(int(symbol) + 32) // Convert to lowercase
	} else if symbol >= 'a' && symbol <= 'z' {
		color = Black
	} else {
		return Piece{}, fmt.Errorf("invalid piece symbol: %c", symbol)
	}

	// Determine piece type
	switch symbol {
	case 'p':
		pieceType = Pawn
	case 'n':
		pieceType = Knight
	case 'b':
		pieceType = Bishop
	case 'r':
		pieceType = Rook
	case 'q':
		pieceType = Queen
	case 'k':
		pieceType = King
	default:
		return Piece{}, fmt.Errorf("invalid piece symbol: %c", symbol)
	}

	return NewPiece(pieceType, color), nil
}

// Standard starting position FEN
const StartingPositionFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
