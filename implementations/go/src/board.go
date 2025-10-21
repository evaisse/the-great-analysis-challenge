package main

import (
	"fmt"
	"strings"
)

func NewGameState() *GameState {
	gs := &GameState{
		ActiveColor:        White,
		CastlingRights:     [2][2]bool{{true, true}, {true, true}},
		EnPassantTarget:    nil,
		HalfmoveClock:      0,
		FullmoveNumber:     1,
		MoveHistory:        make([]Move, 0),
	}
	
	// Initialize starting position
	gs.SetupInitialPosition()
	return gs
}

func (gs *GameState) SetupInitialPosition() {
	// Clear board
	for rank := 0; rank < 8; rank++ {
		for file := 0; file < 8; file++ {
			gs.Board[rank][file] = Piece{Type: Empty}
		}
	}
	
	// White pieces (rank 0 and 1)
	gs.Board[0][0] = NewPiece(Rook, White)
	gs.Board[0][1] = NewPiece(Knight, White)
	gs.Board[0][2] = NewPiece(Bishop, White)
	gs.Board[0][3] = NewPiece(Queen, White)
	gs.Board[0][4] = NewPiece(King, White)
	gs.Board[0][5] = NewPiece(Bishop, White)
	gs.Board[0][6] = NewPiece(Knight, White)
	gs.Board[0][7] = NewPiece(Rook, White)
	
	for file := 0; file < 8; file++ {
		gs.Board[1][file] = NewPiece(Pawn, White)
	}
	
	// Black pieces (rank 6 and 7)
	for file := 0; file < 8; file++ {
		gs.Board[6][file] = NewPiece(Pawn, Black)
	}
	
	gs.Board[7][0] = NewPiece(Rook, Black)
	gs.Board[7][1] = NewPiece(Knight, Black)
	gs.Board[7][2] = NewPiece(Bishop, Black)
	gs.Board[7][3] = NewPiece(Queen, Black)
	gs.Board[7][4] = NewPiece(King, Black)
	gs.Board[7][5] = NewPiece(Bishop, Black)
	gs.Board[7][6] = NewPiece(Knight, Black)
	gs.Board[7][7] = NewPiece(Rook, Black)
}

func (gs *GameState) GetPiece(square Square) Piece {
	if !square.IsValid() {
		return Piece{Type: Empty}
	}
	return gs.Board[square.Rank][square.File]
}

func (gs *GameState) SetPiece(square Square, piece Piece) {
	if square.IsValid() {
		gs.Board[square.Rank][square.File] = piece
	}
}

func (gs *GameState) Display() string {
	var sb strings.Builder
	
	sb.WriteString("  a b c d e f g h\n")
	
	for rank := 7; rank >= 0; rank-- {
		sb.WriteString(fmt.Sprintf("%d ", rank+1))
		for file := 0; file < 8; file++ {
			piece := gs.Board[rank][file]
			sb.WriteRune(piece.Symbol())
			sb.WriteRune(' ')
		}
		sb.WriteString(fmt.Sprintf("%d\n", rank+1))
	}
	
	sb.WriteString("  a b c d e f g h\n\n")
	
	if gs.ActiveColor == White {
		sb.WriteString("White to move\n")
	} else {
		sb.WriteString("Black to move\n")
	}
	
	return sb.String()
}

func (gs *GameState) IsSquareAttacked(square Square, byColor Color) bool {
	// Check for pawn attacks
	pawnDirection := 1
	if byColor == Black {
		pawnDirection = -1
	}
	
	pawnAttackSquares := []Square{
		{square.File - 1, square.Rank - pawnDirection},
		{square.File + 1, square.Rank - pawnDirection},
	}
	
	for _, attackSquare := range pawnAttackSquares {
		if attackSquare.IsValid() {
			piece := gs.GetPiece(attackSquare)
			if piece.Type == Pawn && piece.Color == byColor {
				return true
			}
		}
	}
	
	// Check for knight attacks
	knightMoves := [][]int{
		{-2, -1}, {-2, 1}, {-1, -2}, {-1, 2},
		{1, -2}, {1, 2}, {2, -1}, {2, 1},
	}
	
	for _, move := range knightMoves {
		attackSquare := Square{square.File + move[0], square.Rank + move[1]}
		if attackSquare.IsValid() {
			piece := gs.GetPiece(attackSquare)
			if piece.Type == Knight && piece.Color == byColor {
				return true
			}
		}
	}
	
	// Check for king attacks
	kingMoves := [][]int{
		{-1, -1}, {-1, 0}, {-1, 1},
		{0, -1}, {0, 1},
		{1, -1}, {1, 0}, {1, 1},
	}
	
	for _, move := range kingMoves {
		attackSquare := Square{square.File + move[0], square.Rank + move[1]}
		if attackSquare.IsValid() {
			piece := gs.GetPiece(attackSquare)
			if piece.Type == King && piece.Color == byColor {
				return true
			}
		}
	}
	
	// Check for sliding piece attacks (bishop, rook, queen)
	directions := [][]int{
		{-1, -1}, {-1, 0}, {-1, 1}, {0, -1},
		{0, 1}, {1, -1}, {1, 0}, {1, 1},
	}
	
	for i, direction := range directions {
		for distance := 1; distance < 8; distance++ {
			attackSquare := Square{
				square.File + direction[0]*distance,
				square.Rank + direction[1]*distance,
			}
			
			if !attackSquare.IsValid() {
				break
			}
			
			piece := gs.GetPiece(attackSquare)
			if !piece.IsEmpty() {
				if piece.Color == byColor {
					// Check if this piece can attack in this direction
					isDiagonal := i == 0 || i == 2 || i == 5 || i == 7
					isOrthogonal := i == 1 || i == 3 || i == 4 || i == 6
					
					if (isDiagonal && (piece.Type == Bishop || piece.Type == Queen)) ||
						(isOrthogonal && (piece.Type == Rook || piece.Type == Queen)) {
						return true
					}
				}
				break // Piece blocks further attacks in this direction
			}
		}
	}
	
	return false
}

func (gs *GameState) IsInCheck(color Color) bool {
	// Find the king
	var kingSquare Square
	found := false
	
	for rank := 0; rank < 8; rank++ {
		for file := 0; file < 8; file++ {
			piece := gs.Board[rank][file]
			if piece.Type == King && piece.Color == color {
				kingSquare = Square{file, rank}
				found = true
				break
			}
		}
		if found {
			break
		}
	}
	
	if !found {
		return false // No king found (shouldn't happen in a valid game)
	}
	
	opponentColor := White
	if color == White {
		opponentColor = Black
	}
	
	return gs.IsSquareAttacked(kingSquare, opponentColor)
}

func (gs *GameState) Clone() *GameState {
	clone := &GameState{
		Board:           gs.Board,
		ActiveColor:     gs.ActiveColor,
		CastlingRights:  gs.CastlingRights,
		HalfmoveClock:   gs.HalfmoveClock,
		FullmoveNumber:  gs.FullmoveNumber,
		MoveHistory:     make([]Move, len(gs.MoveHistory)),
	}
	
	copy(clone.MoveHistory, gs.MoveHistory)
	
	if gs.EnPassantTarget != nil {
		target := *gs.EnPassantTarget
		clone.EnPassantTarget = &target
	}
	
	return clone
}