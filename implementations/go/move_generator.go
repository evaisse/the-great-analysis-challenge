package main

import "fmt"

func (gs *GameState) GenerateLegalMoves() []Move {
	pseudoLegalMoves := gs.GeneratePseudoLegalMoves()
	legalMoves := make([]Move, 0, len(pseudoLegalMoves))

	for _, move := range pseudoLegalMoves {
		if gs.IsLegalMove(move) {
			legalMoves = append(legalMoves, move)
		}
	}

	return legalMoves
}

func (gs *GameState) GeneratePseudoLegalMoves() []Move {
	moves := make([]Move, 0, 64)

	for rank := 0; rank < 8; rank++ {
		for file := 0; file < 8; file++ {
			square := Square{file, rank}
			piece := gs.GetPiece(square)

			if piece.IsEmpty() || piece.Color != gs.ActiveColor {
				continue
			}

			switch piece.Type {
			case Pawn:
				moves = append(moves, gs.GeneratePawnMoves(square)...)
			case Knight:
				moves = append(moves, gs.GenerateKnightMoves(square)...)
			case Bishop:
				moves = append(moves, gs.GenerateBishopMoves(square)...)
			case Rook:
				moves = append(moves, gs.GenerateRookMoves(square)...)
			case Queen:
				moves = append(moves, gs.GenerateQueenMoves(square)...)
			case King:
				moves = append(moves, gs.GenerateKingMoves(square)...)
			}
		}
	}

	return moves
}

func (gs *GameState) GeneratePawnMoves(square Square) []Move {
	moves := make([]Move, 0, 4)
	piece := gs.GetPiece(square)
	direction := 1
	startRank := 1
	promotionRank := 7

	if piece.Color == Black {
		direction = -1
		startRank = 6
		promotionRank = 0
	}

	// Forward move
	oneForward := Square{square.File, square.Rank + direction}
	if oneForward.IsValid() && gs.GetPiece(oneForward).IsEmpty() {
		if oneForward.Rank == promotionRank {
			// Promotion moves
			for _, promoteTo := range []PieceType{Queen, Rook, Bishop, Knight} {
				moves = append(moves, Move{
					From:        square,
					To:          oneForward,
					Piece:       piece,
					IsPromotion: true,
					PromoteTo:   promoteTo,
				})
			}
		} else {
			moves = append(moves, Move{
				From:  square,
				To:    oneForward,
				Piece: piece,
			})

			// Two-square initial move
			if square.Rank == startRank {
				twoForward := Square{square.File, square.Rank + 2*direction}
				if twoForward.IsValid() && gs.GetPiece(twoForward).IsEmpty() {
					moves = append(moves, Move{
						From:  square,
						To:    twoForward,
						Piece: piece,
					})
				}
			}
		}
	}

	// Captures
	for _, fileOffset := range []int{-1, 1} {
		captureSquare := Square{square.File + fileOffset, square.Rank + direction}
		if captureSquare.IsValid() {
			target := gs.GetPiece(captureSquare)
			if !target.IsEmpty() && target.Color != piece.Color {
				captured := target
				if captureSquare.Rank == promotionRank {
					// Promotion captures
					for _, promoteTo := range []PieceType{Queen, Rook, Bishop, Knight} {
						moves = append(moves, Move{
							From:        square,
							To:          captureSquare,
							Piece:       piece,
							Captured:    &captured,
							IsCapture:   true,
							IsPromotion: true,
							PromoteTo:   promoteTo,
						})
					}
				} else {
					moves = append(moves, Move{
						From:      square,
						To:        captureSquare,
						Piece:     piece,
						Captured:  &captured,
						IsCapture: true,
					})
				}
			}
		}
	}

	// En passant
	if gs.EnPassantTarget != nil {
		for _, fileOffset := range []int{-1, 1} {
			captureSquare := Square{square.File + fileOffset, square.Rank + direction}
			if captureSquare == *gs.EnPassantTarget {
				capturedPawnSquare := Square{gs.EnPassantTarget.File, square.Rank}
				capturedPawn := gs.GetPiece(capturedPawnSquare)
				moves = append(moves, Move{
					From:        square,
					To:          captureSquare,
					Piece:       piece,
					Captured:    &capturedPawn,
					IsCapture:   true,
					IsEnPassant: true,
				})
			}
		}
	}

	return moves
}

func (gs *GameState) GenerateKnightMoves(square Square) []Move {
	moves := make([]Move, 0, 8)
	piece := gs.GetPiece(square)

	for _, toSquare := range knightAttacks(square) {
		target := gs.GetPiece(toSquare)
		if target.IsEmpty() {
			moves = append(moves, Move{
				From:  square,
				To:    toSquare,
				Piece: piece,
			})
		} else if target.Color != piece.Color {
			moves = append(moves, Move{
				From:      square,
				To:        toSquare,
				Piece:     piece,
				Captured:  &target,
				IsCapture: true,
			})
		}
	}

	return moves
}

func (gs *GameState) GenerateSlidingMoves(square Square, directions [][]int) []Move {
	moves := make([]Move, 0, 14)
	piece := gs.GetPiece(square)

	for _, direction := range directions {
		toSquareList := rayAttacks(directionToEnum(direction[0], direction[1]), square)
		for _, toSquare := range toSquareList {
			target := gs.GetPiece(toSquare)
			if target.IsEmpty() {
				moves = append(moves, Move{
					From:  square,
					To:    toSquare,
					Piece: piece,
				})
			} else {
				if target.Color != piece.Color {
					moves = append(moves, Move{
						From:      square,
						To:        toSquare,
						Piece:     piece,
						Captured:  &target,
						IsCapture: true,
					})
				}
				break // Can't move past any piece
			}
		}
	}

	return moves
}

func (gs *GameState) GenerateBishopMoves(square Square) []Move {
	directions := [][]int{
		{-1, -1}, {-1, 1}, {1, -1}, {1, 1},
	}
	return gs.GenerateSlidingMoves(square, directions)
}

func (gs *GameState) GenerateRookMoves(square Square) []Move {
	directions := [][]int{
		{-1, 0}, {1, 0}, {0, -1}, {0, 1},
	}
	return gs.GenerateSlidingMoves(square, directions)
}

func (gs *GameState) GenerateQueenMoves(square Square) []Move {
	directions := [][]int{
		{-1, -1}, {-1, 0}, {-1, 1},
		{0, -1}, {0, 1},
		{1, -1}, {1, 0}, {1, 1},
	}
	return gs.GenerateSlidingMoves(square, directions)
}

func (gs *GameState) GenerateKingMoves(square Square) []Move {
	moves := make([]Move, 0, 10)
	piece := gs.GetPiece(square)

	for _, toSquare := range kingAttacks(square) {
		target := gs.GetPiece(toSquare)
		if target.IsEmpty() {
			moves = append(moves, Move{
				From:  square,
				To:    toSquare,
				Piece: piece,
			})
		} else if target.Color != piece.Color {
			moves = append(moves, Move{
				From:      square,
				To:        toSquare,
				Piece:     piece,
				Captured:  &target,
				IsCapture: true,
			})
		}
	}

	// Castling
	if !gs.IsInCheck(piece.Color) {
		moves = append(moves, gs.generateCastlingMoves(square, piece)...)
	}

	return moves
}

func (gs *GameState) generateCastlingMoves(square Square, piece Piece) []Move {
	moves := make([]Move, 0, 2)
	for _, side := range []int{KingsideCastle, QueensideCastle} {
		if !gs.CastlingRights[piece.Color][side] {
			continue
		}

		kingStart, rookStart, kingTarget, rookTarget := gs.GetCastleDetails(piece.Color, side)
		if square != kingStart {
			continue
		}

		rook := gs.GetPiece(rookStart)
		if rook.Type != Rook || rook.Color != piece.Color {
			continue
		}

		blockerSquares := append(gs.LinePath(kingStart, kingTarget), gs.LinePath(rookStart, rookTarget)...)
		seen := make(map[Square]bool)
		blocked := false
		for _, pathSquare := range blockerSquares {
			if seen[pathSquare] {
				continue
			}
			seen[pathSquare] = true
			if pathSquare == kingStart || pathSquare == rookStart {
				continue
			}
			if !gs.GetPiece(pathSquare).IsEmpty() {
				blocked = true
				break
			}
		}
		if blocked {
			continue
		}

		attackSquares := append([]Square{kingStart}, gs.LinePath(kingStart, kingTarget)...)
		seen = make(map[Square]bool)
		unsafe := false
		for _, attackSquare := range attackSquares {
			if seen[attackSquare] {
				continue
			}
			seen[attackSquare] = true
			if gs.IsSquareAttacked(attackSquare, 1-piece.Color) {
				unsafe = true
				break
			}
		}
		if unsafe {
			continue
		}

		moves = append(moves, Move{
			From:     square,
			To:       kingTarget,
			Piece:    piece,
			IsCastle: true,
		})
	}
	return moves
}

func directionToEnum(fileDelta, rankDelta int) Direction {
	switch {
	case fileDelta == -1 && rankDelta == -1:
		return DirectionSouthWest
	case fileDelta == 0 && rankDelta == -1:
		return DirectionSouth
	case fileDelta == 1 && rankDelta == -1:
		return DirectionSouthEast
	case fileDelta == -1 && rankDelta == 0:
		return DirectionWest
	case fileDelta == 1 && rankDelta == 0:
		return DirectionEast
	case fileDelta == -1 && rankDelta == 1:
		return DirectionNorthWest
	case fileDelta == 0 && rankDelta == 1:
		return DirectionNorth
	case fileDelta == 1 && rankDelta == 1:
		return DirectionNorthEast
	default:
		panic(fmt.Sprintf("unsupported direction: %d,%d", fileDelta, rankDelta))
	}
}

func (gs *GameState) IsLegalMove(move Move) bool {
	// Make a copy of the game state
	testState := gs.Clone()

	// Make the move
	testState.MakeMove(move)

	// Check if the move leaves the king in check
	return !testState.IsInCheck(gs.ActiveColor)
}

func (gs *GameState) IsValidMove(from, to Square) (Move, error) {
	piece := gs.GetPiece(from)
	if piece.IsEmpty() {
		return Move{}, fmt.Errorf("ERROR: No piece at source square")
	}

	if piece.Color != gs.ActiveColor {
		return Move{}, fmt.Errorf("ERROR: Wrong color piece")
	}

	legalMoves := gs.GenerateLegalMoves()
	for _, move := range legalMoves {
		if move.From == from && move.To == to {
			return move, nil
		}
	}

	return Move{}, fmt.Errorf("ERROR: Illegal move")
}

func (gs *GameState) MakeMove(move Move) {
	// Record current position hash in history before moving
	gs.PositionHistory = append(gs.PositionHistory, gs.ZobristHash)

	// Save current state for undo
	gs.StateHistory = append(gs.StateHistory, SavedState{
		CastlingRights:  gs.CastlingRights,
		CastlingConfig:  gs.CastlingConfig,
		Chess960Mode:    gs.Chess960Mode,
		EnPassantTarget: gs.EnPassantTarget,
		HalfmoveClock:   gs.HalfmoveClock,
		ZobristHash:     gs.ZobristHash,
	})

	// Handle en passant capture
	if move.IsEnPassant {
		capturedPawnSquare := Square{move.To.File, move.From.Rank}
		gs.SetPiece(capturedPawnSquare, Piece{Type: Empty})
	}

	var castleRook Piece
	var rookFrom Square
	var rookTo Square
	if move.IsCastle {
		side := QueensideCastle
		if move.To.File == 6 {
			side = KingsideCastle
		}
		_, rookFrom, _, rookTo = gs.GetCastleDetails(move.Piece.Color, side)
		castleRook = gs.GetPiece(rookFrom)
	}

	// Move the piece
	gs.SetPiece(move.From, Piece{Type: Empty})

	if move.IsPromotion {
		gs.SetPiece(move.To, NewPiece(move.PromoteTo, move.Piece.Color))
	} else {
		gs.SetPiece(move.To, move.Piece)
	}

	// Handle castling
	if move.IsCastle {
		if rookFrom != move.From && rookFrom != move.To {
			gs.SetPiece(rookFrom, Piece{Type: Empty})
		}
		gs.SetPiece(rookTo, castleRook)
	}

	// Update castling rights
	if move.Piece.Type == King {
		gs.CastlingRights[move.Piece.Color][KingsideCastle] = false
		gs.CastlingRights[move.Piece.Color][QueensideCastle] = false
	} else if move.Piece.Type == Rook {
		if move.From.File == gs.CastlingConfig.RookFile[move.Piece.Color][QueensideCastle] {
			gs.CastlingRights[move.Piece.Color][QueensideCastle] = false
		} else if move.From.File == gs.CastlingConfig.RookFile[move.Piece.Color][KingsideCastle] {
			gs.CastlingRights[move.Piece.Color][KingsideCastle] = false
		}
	}
	if move.To.Rank == 0 && move.To.File == gs.CastlingConfig.RookFile[White][QueensideCastle] {
		gs.CastlingRights[White][QueensideCastle] = false
	} else if move.To.Rank == 0 && move.To.File == gs.CastlingConfig.RookFile[White][KingsideCastle] {
		gs.CastlingRights[White][KingsideCastle] = false
	} else if move.To.Rank == 7 && move.To.File == gs.CastlingConfig.RookFile[Black][QueensideCastle] {
		gs.CastlingRights[Black][QueensideCastle] = false
	} else if move.To.Rank == 7 && move.To.File == gs.CastlingConfig.RookFile[Black][KingsideCastle] {
		gs.CastlingRights[Black][KingsideCastle] = false
	}

	// Update en passant target
	gs.EnPassantTarget = nil
	if move.Piece.Type == Pawn && abs(move.To.Rank-move.From.Rank) == 2 {
		gs.EnPassantTarget = &Square{move.From.File, (move.From.Rank + move.To.Rank) / 2}
	}

	// Update counters
	if move.IsCapture || move.Piece.Type == Pawn {
		gs.HalfmoveClock = 0
	} else {
		gs.HalfmoveClock++
	}

	if gs.ActiveColor == Black {
		gs.FullmoveNumber++
	}

	// Switch active color
	gs.ActiveColor = 1 - gs.ActiveColor

	// Recalculate hash
	gs.ZobristHash = computeZobristHash(gs)

	// Add to move history
	gs.MoveHistory = append(gs.MoveHistory, move)
}

func (gs *GameState) UndoLastMove() bool {
	if len(gs.MoveHistory) == 0 {
		return false
	}

	lastMoveIndex := len(gs.MoveHistory) - 1
	move := gs.MoveHistory[lastMoveIndex]
	gs.MoveHistory = gs.MoveHistory[:lastMoveIndex]

	// Restore position history
	if len(gs.PositionHistory) > 0 {
		gs.PositionHistory = gs.PositionHistory[:len(gs.PositionHistory)-1]
	}

	// Restore state history
	lastStateIndex := len(gs.StateHistory) - 1
	savedState := gs.StateHistory[lastStateIndex]
	gs.StateHistory = gs.StateHistory[:lastStateIndex]

	gs.CastlingRights = savedState.CastlingRights
	gs.CastlingConfig = savedState.CastlingConfig
	gs.Chess960Mode = savedState.Chess960Mode
	gs.EnPassantTarget = savedState.EnPassantTarget
	gs.HalfmoveClock = savedState.HalfmoveClock
	gs.ZobristHash = savedState.ZobristHash

	// Switch back the active color
	if gs.ActiveColor == White {
		gs.FullmoveNumber--
	}
	gs.ActiveColor = 1 - gs.ActiveColor

	var castleRook Piece
	var rookFrom Square
	var rookTo Square
	if move.IsCastle {
		side := QueensideCastle
		if move.To.File == 6 {
			side = KingsideCastle
		}
		_, rookFrom, _, rookTo = gs.GetCastleDetails(move.Piece.Color, side)
		castleRook = gs.GetPiece(rookTo)
	}

	// Restore the piece to its original position
	gs.SetPiece(move.From, move.Piece)

	// Handle captured pieces
	if move.Captured != nil {
		if move.IsEnPassant {
			// Restore the captured pawn to its original square
			capturedPawnSquare := Square{move.To.File, move.From.Rank}
			gs.SetPiece(capturedPawnSquare, *move.Captured)
			gs.SetPiece(move.To, Piece{Type: Empty})
		} else {
			gs.SetPiece(move.To, *move.Captured)
		}
	} else {
		gs.SetPiece(move.To, Piece{Type: Empty})
	}

	// Handle castling undo
	if move.IsCastle {
		if rookTo != move.From {
			gs.SetPiece(rookTo, Piece{Type: Empty})
		}
		gs.SetPiece(rookFrom, castleRook)
	}

	return true
}

func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}
