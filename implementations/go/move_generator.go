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

	knightMoves := [][]int{
		{-2, -1}, {-2, 1}, {-1, -2}, {-1, 2},
		{1, -2}, {1, 2}, {2, -1}, {2, 1},
	}

	for _, move := range knightMoves {
		toSquare := Square{square.File + move[0], square.Rank + move[1]}
		if toSquare.IsValid() {
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
	}

	return moves
}

func (gs *GameState) GenerateSlidingMoves(square Square, directions [][]int) []Move {
	moves := make([]Move, 0, 14)
	piece := gs.GetPiece(square)

	for _, direction := range directions {
		for distance := 1; distance < 8; distance++ {
			toSquare := Square{
				square.File + direction[0]*distance,
				square.Rank + direction[1]*distance,
			}

			if !toSquare.IsValid() {
				break
			}

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

	// Regular king moves
	kingMoves := [][]int{
		{-1, -1}, {-1, 0}, {-1, 1},
		{0, -1}, {0, 1},
		{1, -1}, {1, 0}, {1, 1},
	}

	for _, move := range kingMoves {
		toSquare := Square{square.File + move[0], square.Rank + move[1]}
		if toSquare.IsValid() {
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
	}

	// Castling
	if !gs.IsInCheck(piece.Color) {
		rank := 0
		if piece.Color == Black {
			rank = 7
		}

		// Kingside castling
		if gs.CastlingRights[piece.Color][KingsideCastle] {
			if gs.GetPiece(Square{5, rank}).IsEmpty() && gs.GetPiece(Square{6, rank}).IsEmpty() {
				if !gs.IsSquareAttacked(Square{5, rank}, 1-piece.Color) && !gs.IsSquareAttacked(Square{6, rank}, 1-piece.Color) {
					moves = append(moves, Move{
						From:     square,
						To:       Square{6, rank},
						Piece:    piece,
						IsCastle: true,
					})
				}
			}
		}

		// Queenside castling
		if gs.CastlingRights[piece.Color][QueensideCastle] {
			if gs.GetPiece(Square{1, rank}).IsEmpty() && gs.GetPiece(Square{2, rank}).IsEmpty() && gs.GetPiece(Square{3, rank}).IsEmpty() {
				if !gs.IsSquareAttacked(Square{2, rank}, 1-piece.Color) && !gs.IsSquareAttacked(Square{3, rank}, 1-piece.Color) {
					moves = append(moves, Move{
						From:     square,
						To:       Square{2, rank},
						Piece:    piece,
						IsCastle: true,
					})
				}
			}
		}
	}

	return moves
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
	// Handle en passant capture
	if move.IsEnPassant {
		capturedPawnSquare := Square{move.To.File, move.From.Rank}
		gs.SetPiece(capturedPawnSquare, Piece{Type: Empty})
	}

	// Handle castling
	if move.IsCastle {
		// Move the rook
		rank := move.From.Rank
		if move.To.File == 6 { // Kingside
			rookFrom := Square{7, rank}
			rookTo := Square{5, rank}
			rook := gs.GetPiece(rookFrom)
			gs.SetPiece(rookFrom, Piece{Type: Empty})
			gs.SetPiece(rookTo, rook)
		} else { // Queenside
			rookFrom := Square{0, rank}
			rookTo := Square{3, rank}
			rook := gs.GetPiece(rookFrom)
			gs.SetPiece(rookFrom, Piece{Type: Empty})
			gs.SetPiece(rookTo, rook)
		}
	}

	// Move the piece
	gs.SetPiece(move.From, Piece{Type: Empty})

	if move.IsPromotion {
		gs.SetPiece(move.To, NewPiece(move.PromoteTo, move.Piece.Color))
	} else {
		gs.SetPiece(move.To, move.Piece)
	}

	// Update castling rights
	if move.Piece.Type == King {
		gs.CastlingRights[move.Piece.Color][KingsideCastle] = false
		gs.CastlingRights[move.Piece.Color][QueensideCastle] = false
	} else if move.Piece.Type == Rook {
		if move.From.File == 0 {
			gs.CastlingRights[move.Piece.Color][QueensideCastle] = false
		} else if move.From.File == 7 {
			gs.CastlingRights[move.Piece.Color][KingsideCastle] = false
		}
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

	// Add to move history
	gs.MoveHistory = append(gs.MoveHistory, move)
}

func (gs *GameState) UndoLastMove() bool {
	if len(gs.MoveHistory) == 0 {
		return false
	}

	// This is a simplified undo - in a full implementation,
	// you'd need to store additional game state information
	lastMoveIndex := len(gs.MoveHistory) - 1
	move := gs.MoveHistory[lastMoveIndex]
	gs.MoveHistory = gs.MoveHistory[:lastMoveIndex]

	// Switch back the active color
	gs.ActiveColor = 1 - gs.ActiveColor

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
		rank := move.From.Rank
		if move.To.File == 6 { // Kingside
			rookFrom := Square{5, rank}
			rookTo := Square{7, rank}
			rook := gs.GetPiece(rookFrom)
			gs.SetPiece(rookFrom, Piece{Type: Empty})
			gs.SetPiece(rookTo, rook)
		} else { // Queenside
			rookFrom := Square{3, rank}
			rookTo := Square{0, rank}
			rook := gs.GetPiece(rookFrom)
			gs.SetPiece(rookFrom, Piece{Type: Empty})
			gs.SetPiece(rookTo, rook)
		}
	}

	return true
}

func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}
