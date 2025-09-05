package game

import (
	"fmt"
	"strings"
)

type Board struct {
	Squares       [64]Piece
	Turn          Color
	Castling      [4]bool // KQkq
	EnPassant     int
	HalfMoveClock int
	FullMoveClock int
}

func NewBoard() *Board {
	b := &Board{}
	b.LoadFen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
	return b
}

func (b *Board) LoadFen(fen string) {
	parts := strings.Split(fen, " ")
	
	// Pieces
	rank, file := 7, 0
	for _, r := range parts[0] {
		if r == '/' {
			rank--
			file = 0
		} else if r >= '1' && r <= '8' {
			file += int(r - '0')
		} else {
			b.Squares[rank*8+file] = FromChar(r)
			file++
		}
	}

	// Turn
	if parts[1] == "w" {
		b.Turn = White
	} else {
		b.Turn = Black
	}

	// Castling
	b.Castling = [4]bool{}
	for _, r := range parts[2] {
		switch r {
		case 'K':
			b.Castling[0] = true
		case 'Q':
			b.Castling[1] = true
		case 'k':
			b.Castling[2] = true
		case 'q':
			b.Castling[3] = true
		}
	}

	// En passant
	if parts[3] != "-" {
		file := int(parts[3][0] - 'a')
		rank := int(parts[3][1] - '1')
		b.EnPassant = rank*8 + file
	} else {
		b.EnPassant = -1
	}

	// Halfmove clock
	fmt.Sscanf(parts[4], "%d", &b.HalfMoveClock)

	// Fullmove clock
	fmt.Sscanf(parts[5], "%d", &b.FullMoveClock)
}

func (b *Board) String() string {
	var sb strings.Builder
	sb.WriteString("  a b c d e f g h\n")
	for r := 7; r >= 0; r-- {
		sb.WriteString(fmt.Sprintf("%d ", r+1))
		for f := 0; f < 8; f++ {
			sb.WriteString(b.Squares[r*8+f].String())
			sb.WriteString(" ")
		}
		sb.WriteString(fmt.Sprintf("%d\n", r+1))
	}
	sb.WriteString("  a b c d e f g h\n")
	return sb.String()
}