package game

type Piece byte

const (
	Empty Piece = iota
	Pawn
	Knight
	Bishop
	Rook
	Queen
	King
)

type Color byte

const (
	White Color = iota
	Black
)

func (p Piece) Color() Color {
	if p >= Pawn && p <= King {
		return White
	}
	if p >= Pawn+6 && p <= King+6 {
		return Black
	}
	return 2 // No color
}

func FromChar(c rune) Piece {
	switch c {
	case 'P':
		return Pawn
	case 'N':
		return Knight
	case 'B':
		return Bishop
	case 'R':
		return Rook
	case 'Q':
		return Queen
	case 'K':
		return King
	case 'p':
		return Pawn + 6
	case 'n':
		return Knight + 6
	case 'b':
		return Bishop + 6
	case 'r':
		return Rook + 6
	case 'q':
		return Queen + 6
	case 'k':
		return King + 6
	default:
		return Empty
	}
}

func (p Piece) String() string {
	switch p {
	case Pawn:
		return "P"
	case Knight:
		return "N"
	case Bishop:
		return "B"
	case Rook:
		return "R"
	case Queen:
		return "Q"
	case King:
		return "K"
	case Pawn + 6:
		return "p"
	case Knight + 6:
		return "n"
	case Bishop + 6:
		return "b"
	case Rook + 6:
		return "r"
	case Queen + 6:
		return "q"
	case King + 6:
		return "k"
	default:
		return "."
	}
}