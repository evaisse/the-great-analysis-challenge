package main

import (
	"fmt"
	"strings"
)

func NewGameState() *GameState {
	gs := &GameState{
		ActiveColor:     White,
		CastlingRights:  [2][2]bool{{true, true}, {true, true}},
		CastlingConfig:  DefaultCastlingConfig(),
		Chess960Mode:    false,
		EnPassantTarget: nil,
		HalfmoveClock:   0,
		FullmoveNumber:  1,
		MoveHistory:     make([]Move, 0),
		PositionHistory: make([]uint64, 0),
	}

	// Initialize starting position
	gs.SetupInitialPosition()
	gs.ZobristHash = computeZobristHash(gs)
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
	gs.CastlingConfig = DefaultCastlingConfig()
	gs.Chess960Mode = false
}

func (gs *GameState) LinePath(start, target Square) []Square {
	if start == target {
		return nil
	}

	fileStep := 0
	if target.File > start.File {
		fileStep = 1
	} else if target.File < start.File {
		fileStep = -1
	}

	rankStep := 0
	if target.Rank > start.Rank {
		rankStep = 1
	} else if target.Rank < start.Rank {
		rankStep = -1
	}

	file := start.File + fileStep
	rank := start.Rank + rankStep
	path := make([]Square, 0, 8)
	for file != target.File || rank != target.Rank {
		path = append(path, Square{file, rank})
		file += fileStep
		rank += rankStep
	}
	path = append(path, target)
	return path
}

func (gs *GameState) GetCastleDetails(color Color, side int) (Square, Square, Square, Square) {
	rank := 0
	if color == Black {
		rank = 7
	}
	kingStart := Square{gs.CastlingConfig.KingFile[color], rank}
	rookStart := Square{gs.CastlingConfig.RookFile[color][side], rank}
	kingTarget := Square{2, rank}
	rookTarget := Square{3, rank}
	if side == KingsideCastle {
		kingTarget = Square{6, rank}
		rookTarget = Square{5, rank}
	}
	return kingStart, rookStart, kingTarget, rookTarget
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
	for _, attackSquare := range knightAttacks(square) {
		piece := gs.GetPiece(attackSquare)
		if piece.Type == Knight && piece.Color == byColor {
			return true
		}
	}

	// Check for king attacks
	for _, attackSquare := range kingAttacks(square) {
		piece := gs.GetPiece(attackSquare)
		if piece.Type == King && piece.Color == byColor {
			return true
		}
	}

	// Check for sliding piece attacks (bishop, rook, queen)
	directions := []struct {
		fileDelta  int
		rankDelta  int
		isDiagonal bool
	}{
		{-1, -1, true},
		{-1, 0, false},
		{-1, 1, true},
		{0, -1, false},
		{0, 1, false},
		{1, -1, true},
		{1, 0, false},
		{1, 1, true},
	}

	for _, direction := range directions {
		for _, attackSquare := range rayAttacks(directionToEnum(direction.fileDelta, direction.rankDelta), square) {
			piece := gs.GetPiece(attackSquare)
			if !piece.IsEmpty() {
				if piece.Color == byColor {
					if (direction.isDiagonal && (piece.Type == Bishop || piece.Type == Queen)) ||
						(!direction.isDiagonal && (piece.Type == Rook || piece.Type == Queen)) {
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
		CastlingConfig:  gs.CastlingConfig,
		Chess960Mode:    gs.Chess960Mode,
		HalfmoveClock:   gs.HalfmoveClock,
		FullmoveNumber:  gs.FullmoveNumber,
		MoveHistory:     make([]Move, len(gs.MoveHistory)),
		ZobristHash:     gs.ZobristHash,
		PositionHistory: make([]uint64, len(gs.PositionHistory)),
	}

	copy(clone.MoveHistory, gs.MoveHistory)
	copy(clone.PositionHistory, gs.PositionHistory)

	if gs.EnPassantTarget != nil {
		target := *gs.EnPassantTarget
		clone.EnPassantTarget = &target
	}

	return clone
}

func (gs *GameState) FindHomeRankPiece(color Color, pieceType PieceType) (int, bool) {
	rank := 0
	if color == Black {
		rank = 7
	}
	for file := 0; file < 8; file++ {
		piece := gs.Board[rank][file]
		if piece.Type == pieceType && piece.Color == color {
			return file, true
		}
	}
	return 0, false
}

func (gs *GameState) ConfigureChess960() {
	whiteKingFile, whiteOK := gs.FindHomeRankPiece(White, King)
	blackKingFile, blackOK := gs.FindHomeRankPiece(Black, King)
	if !whiteOK || !blackOK {
		gs.CastlingConfig = DefaultCastlingConfig()
		gs.Chess960Mode = false
		return
	}

	whiteRooks := make([]int, 0, 2)
	blackRooks := make([]int, 0, 2)
	for file := 0; file < 8; file++ {
		if piece := gs.Board[0][file]; piece.Type == Rook && piece.Color == White {
			whiteRooks = append(whiteRooks, file)
		}
		if piece := gs.Board[7][file]; piece.Type == Rook && piece.Color == Black {
			blackRooks = append(blackRooks, file)
		}
	}
	if len(whiteRooks) == 0 || len(blackRooks) == 0 {
		gs.CastlingConfig = DefaultCastlingConfig()
		gs.Chess960Mode = false
		return
	}

	config := DefaultCastlingConfig()
	config.KingFile[White] = whiteKingFile
	config.KingFile[Black] = blackKingFile
	config.RookFile[White][KingsideCastle] = selectRookFile(whiteRooks, whiteKingFile, true, 7)
	config.RookFile[White][QueensideCastle] = selectRookFile(whiteRooks, whiteKingFile, false, 0)
	config.RookFile[Black][KingsideCastle] = selectRookFile(blackRooks, blackKingFile, true, 7)
	config.RookFile[Black][QueensideCastle] = selectRookFile(blackRooks, blackKingFile, false, 0)
	gs.CastlingConfig = config
	gs.Chess960Mode = !config.IsClassical()
}

func selectRookFile(rookFiles []int, kingFile int, kingside bool, fallback int) int {
	selected := fallback
	found := false
	for _, file := range rookFiles {
		if kingside {
			if file > kingFile && (!found || file > selected) {
				selected = file
				found = true
			}
		} else {
			if file < kingFile && (!found || file < selected) {
				selected = file
				found = true
			}
		}
	}
	return selected
}

func (gs *GameState) IsDrawByRepetition() bool {
	start := len(gs.PositionHistory) - gs.HalfmoveClock
	if start < 0 {
		start = 0
	}

	count := 1
	for i := len(gs.PositionHistory) - 1; i >= start; i-- {
		if gs.PositionHistory[i] == gs.ZobristHash {
			count++
			if count >= 3 {
				return true
			}
		}
	}
	return false
}

func (gs *GameState) IsDrawByFiftyMoves() bool {
	return gs.HalfmoveClock >= 100
}

func (gs *GameState) IsDraw() bool {
	return gs.IsDrawByRepetition() || gs.IsDrawByFiftyMoves()
}

func (gs *GameState) GetDrawReason() string {
	if gs.IsDrawByFiftyMoves() {
		return "50-move rule"
	}
	if gs.IsDrawByRepetition() {
		return "repetition"
	}
	return ""
}
