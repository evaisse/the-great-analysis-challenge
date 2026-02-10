package main

type PieceType int
type Color int

const (
	Empty PieceType = iota
	Pawn
	Knight
	Bishop
	Rook
	Queen
	King
)

const (
	White Color = iota
	Black
)

type Piece struct {
	Type  PieceType
	Color Color
}

type Square struct {
	File int // 0-7 (a-h)
	Rank int // 0-7 (1-8)
}

type Move struct {
	From        Square
	To          Square
	Piece       Piece
	Captured    *Piece
	IsCapture   bool
	IsCastle    bool
	IsEnPassant bool
	IsPromotion bool
	PromoteTo   PieceType
}

type GameState struct {
	Board           [8][8]Piece
	ActiveColor     Color
	CastlingRights  [2][2]bool // [color][side] - true if castling is allowed
	EnPassantTarget *Square    // Target square for en passant capture
	HalfmoveClock   int        // Moves since last capture or pawn move
	FullmoveNumber  int        // Move number (increments after black's move)
	MoveHistory     []Move
	StateHistory    []SavedState
	ZobristHash     uint64
	PositionHistory []uint64
}

type SavedState struct {
	CastlingRights  [2][2]bool
	EnPassantTarget *Square
	HalfmoveClock   int
	ZobristHash     uint64
}

const (
	KingsideCastle  = 0
	QueensideCastle = 1
)

func NewPiece(pieceType PieceType, color Color) Piece {
	return Piece{Type: pieceType, Color: color}
}

func (p Piece) IsEmpty() bool {
	return p.Type == Empty
}

func (p Piece) Symbol() rune {
	if p.Type == Empty {
		return '.'
	}

	var symbol rune
	switch p.Type {
	case Pawn:
		symbol = 'P'
	case Knight:
		symbol = 'N'
	case Bishop:
		symbol = 'B'
	case Rook:
		symbol = 'R'
	case Queen:
		symbol = 'Q'
	case King:
		symbol = 'K'
	}

	if p.Color == Black {
		symbol = rune(int(symbol) + 32) // Convert to lowercase
	}

	return symbol
}

func NewSquare(file, rank int) Square {
	return Square{File: file, Rank: rank}
}

func (s Square) ToAlgebraic() string {
	return string(rune('a'+s.File)) + string(rune('1'+s.Rank))
}

func AlgebraicToSquare(algebraic string) Square {
	if len(algebraic) != 2 {
		return Square{-1, -1}
	}
	file := int(algebraic[0] - 'a')
	rank := int(algebraic[1] - '1')
	return Square{File: file, Rank: rank}
}

func (s Square) IsValid() bool {
	return s.File >= 0 && s.File < 8 && s.Rank >= 0 && s.Rank < 8
}
