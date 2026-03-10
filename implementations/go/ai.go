package main

import (
	"sort"
	"time"
)

const (
	MATE_VALUE   = 20000
	DRAW_VALUE   = 0
	MAX_DEPTH    = 5
	INFINITY     = 999999
	NEG_INFINITY = -999999
)

type ttFlag int

const (
	ttExact ttFlag = iota
	ttLowerBound
	ttUpperBound
)

var pieceValues = map[PieceType]int{
	Pawn:   100,
	Knight: 320,
	Bishop: 330,
	Rook:   500,
	Queen:  900,
	King:   20000,
}

// Piece-square tables for positional evaluation
var pawnTable = [8][8]int{
	{0, 0, 0, 0, 0, 0, 0, 0},
	{50, 50, 50, 50, 50, 50, 50, 50},
	{10, 10, 20, 30, 30, 20, 10, 10},
	{5, 5, 10, 25, 25, 10, 5, 5},
	{0, 0, 0, 20, 20, 0, 0, 0},
	{5, -5, -10, 0, 0, -10, -5, 5},
	{5, 10, 10, -20, -20, 10, 10, 5},
	{0, 0, 0, 0, 0, 0, 0, 0},
}

var knightTable = [8][8]int{
	{-50, -40, -30, -30, -30, -30, -40, -50},
	{-40, -20, 0, 0, 0, 0, -20, -40},
	{-30, 0, 10, 15, 15, 10, 0, -30},
	{-30, 5, 15, 20, 20, 15, 5, -30},
	{-30, 0, 15, 20, 20, 15, 0, -30},
	{-30, 5, 10, 15, 15, 10, 5, -30},
	{-40, -20, 0, 5, 5, 0, -20, -40},
	{-50, -40, -30, -30, -30, -30, -40, -50},
}

var bishopTable = [8][8]int{
	{-20, -10, -10, -10, -10, -10, -10, -20},
	{-10, 0, 0, 0, 0, 0, 0, -10},
	{-10, 0, 5, 10, 10, 5, 0, -10},
	{-10, 5, 5, 10, 10, 5, 5, -10},
	{-10, 0, 10, 10, 10, 10, 0, -10},
	{-10, 10, 10, 10, 10, 10, 10, -10},
	{-10, 5, 0, 0, 0, 0, 5, -10},
	{-20, -10, -10, -10, -10, -10, -10, -20},
}

var rookTable = [8][8]int{
	{0, 0, 0, 0, 0, 0, 0, 0},
	{5, 10, 10, 10, 10, 10, 10, 5},
	{-5, 0, 0, 0, 0, 0, 0, -5},
	{-5, 0, 0, 0, 0, 0, 0, -5},
	{-5, 0, 0, 0, 0, 0, 0, -5},
	{-5, 0, 0, 0, 0, 0, 0, -5},
	{-5, 0, 0, 0, 0, 0, 0, -5},
	{0, 0, 0, 5, 5, 0, 0, 0},
}

var queenTable = [8][8]int{
	{-20, -10, -10, -5, -5, -10, -10, -20},
	{-10, 0, 0, 0, 0, 0, 0, -10},
	{-10, 0, 5, 5, 5, 5, 0, -10},
	{-5, 0, 5, 5, 5, 5, 0, -5},
	{0, 0, 5, 5, 5, 5, 0, -5},
	{-10, 5, 5, 5, 5, 5, 0, -10},
	{-10, 0, 5, 0, 0, 0, 0, -10},
	{-20, -10, -10, -5, -5, -10, -10, -20},
}

var kingMiddlegameTable = [8][8]int{
	{-30, -40, -40, -50, -50, -40, -40, -30},
	{-30, -40, -40, -50, -50, -40, -40, -30},
	{-30, -40, -40, -50, -50, -40, -40, -30},
	{-30, -40, -40, -50, -50, -40, -40, -30},
	{-20, -30, -30, -40, -40, -30, -30, -20},
	{-10, -20, -20, -20, -20, -20, -20, -10},
	{20, 20, 0, 0, 0, 0, 20, 20},
	{20, 30, 10, 0, 0, 10, 30, 20},
}

type TTEntry struct {
	Depth       int
	Score       int
	Flag        ttFlag
	BestMove    Move
	HasBestMove bool
}

type SearchResult struct {
	Move   Move
	Score  int
	Depth  int
	Aborted bool
}

type searchContext struct {
	deadline    time.Time
	hasDeadline bool
	aborted     bool
}

func (ctx *searchContext) shouldStop() bool {
	if !ctx.hasDeadline || ctx.aborted {
		return ctx.aborted
	}

	if !time.Now().Before(ctx.deadline) {
		ctx.aborted = true
	}

	return ctx.aborted
}

type AI struct {
	nodesEvaluated int
	transposition  map[uint64]TTEntry
}

func NewAI() *AI {
	return &AI{
		nodesEvaluated: 0,
		transposition:  make(map[uint64]TTEntry, 1<<16),
	}
}

func (ai *AI) FindBestMove(gs *GameState, depth int) Move {
	if depth < 1 || depth > MAX_DEPTH {
		depth = 3
	}

	result := ai.findBestMoveIterative(gs, depth, 0)
	return result.Move
}

func (ai *AI) FindBestMoveWithDepth(gs *GameState, depth int) SearchResult {
	if depth < 1 || depth > MAX_DEPTH {
		depth = 3
	}
	return ai.findBestMoveIterative(gs, depth, 0)
}

func (ai *AI) FindBestMoveTimed(gs *GameState, movetime time.Duration, maxDepth int) SearchResult {
	if maxDepth < 1 || maxDepth > MAX_DEPTH {
		maxDepth = MAX_DEPTH
	}
	if movetime < 0 {
		movetime = 0
	}
	return ai.findBestMoveIterative(gs, maxDepth, movetime)
}

func (ai *AI) findBestMoveIterative(gs *GameState, maxDepth int, movetime time.Duration) SearchResult {
	ai.nodesEvaluated = 0

	legalMoves := gs.GenerateLegalMoves()
	if len(legalMoves) == 0 {
		return SearchResult{}
	}

	ctx := &searchContext{}
	if movetime > 0 {
		ctx.hasDeadline = true
		ctx.deadline = time.Now().Add(movetime)
	}

	ttMove, hasTTMove := ai.getTTMove(gs.ZobristHash)
	orderedFallback := ai.orderMoves(legalMoves, ttMove, hasTTMove)

	result := SearchResult{
		Move:   orderedFallback[0],
		Score:  ai.evaluate(gs),
		Depth:  0,
		Aborted: false,
	}

	for depth := 1; depth <= maxDepth; depth++ {
		if ctx.shouldStop() {
			break
		}

		score, bestMove, completed := ai.negamaxRoot(gs, depth, ctx)
		if !completed {
			break
		}

		result.Score = score
		result.Move = bestMove
		result.Depth = depth
	}

	result.Aborted = ctx.aborted
	return result
}

func (ai *AI) negamaxRoot(gs *GameState, depth int, ctx *searchContext) (int, Move, bool) {
	moves := gs.GenerateLegalMoves()
	if len(moves) == 0 {
		if gs.IsInCheck(gs.ActiveColor) {
			return -MATE_VALUE, Move{}, true
		}
		return DRAW_VALUE, Move{}, true
	}

	alpha := NEG_INFINITY
	beta := INFINITY
	alphaOrig := alpha
	betaOrig := beta

	ttMove, hasTTMove, cutoff, ttScore := ai.probeTT(gs.ZobristHash, depth, &alpha, &beta)
	if cutoff {
		ordered := ai.orderMoves(moves, ttMove, hasTTMove)
		return ttScore, ordered[0], true
	}

	orderedMoves := ai.orderMoves(moves, ttMove, hasTTMove)
	bestScore := NEG_INFINITY
	bestMove := orderedMoves[0]

	for i, move := range orderedMoves {
		if ctx.shouldStop() {
			return 0, Move{}, false
		}

		testState := gs.Clone()
		testState.MakeMove(move)

		score, completed := ai.negamax(testState, depth-1, -beta, -alpha, 1, ctx)
		if !completed {
			return 0, Move{}, false
		}
		score = -score

		if i == 0 || score > bestScore {
			bestScore = score
			bestMove = move
		}

		if score > alpha {
			alpha = score
		}
		if alpha >= beta {
			break
		}
	}

	ai.storeTT(gs.ZobristHash, depth, bestScore, alphaOrig, betaOrig, bestMove)
	return bestScore, bestMove, true
}

func (ai *AI) negamax(gs *GameState, depth int, alpha, beta int, ply int, ctx *searchContext) (int, bool) {
	if ctx.shouldStop() {
		return 0, false
	}

	ai.nodesEvaluated++

	if depth == 0 {
		return ai.evaluate(gs), true
	}

	moves := gs.GenerateLegalMoves()
	if len(moves) == 0 {
		if gs.IsInCheck(gs.ActiveColor) {
			return -MATE_VALUE + ply, true
		}
		return DRAW_VALUE, true
	}

	alphaOrig := alpha
	betaOrig := beta

	ttMove, hasTTMove, cutoff, ttScore := ai.probeTT(gs.ZobristHash, depth, &alpha, &beta)
	if cutoff {
		return ttScore, true
	}

	orderedMoves := ai.orderMoves(moves, ttMove, hasTTMove)
	bestScore := NEG_INFINITY
	bestMove := orderedMoves[0]

	for i, move := range orderedMoves {
		if ctx.shouldStop() {
			return 0, false
		}

		testState := gs.Clone()
		testState.MakeMove(move)

		score, completed := ai.negamax(testState, depth-1, -beta, -alpha, ply+1, ctx)
		if !completed {
			return 0, false
		}
		score = -score

		if i == 0 || score > bestScore {
			bestScore = score
			bestMove = move
		}

		if score > alpha {
			alpha = score
		}
		if alpha >= beta {
			break
		}
	}

	ai.storeTT(gs.ZobristHash, depth, bestScore, alphaOrig, betaOrig, bestMove)
	return bestScore, true
}

func (ai *AI) probeTT(hash uint64, depth int, alpha, beta *int) (Move, bool, bool, int) {
	entry, ok := ai.transposition[hash]
	if !ok {
		return Move{}, false, false, 0
	}

	if entry.Depth < depth {
		return entry.BestMove, entry.HasBestMove, false, 0
	}

	switch entry.Flag {
	case ttExact:
		return entry.BestMove, entry.HasBestMove, true, entry.Score
	case ttLowerBound:
		if entry.Score > *alpha {
			*alpha = entry.Score
		}
	case ttUpperBound:
		if entry.Score < *beta {
			*beta = entry.Score
		}
	}

	if *alpha >= *beta {
		return entry.BestMove, entry.HasBestMove, true, entry.Score
	}

	return entry.BestMove, entry.HasBestMove, false, 0
}

func (ai *AI) storeTT(hash uint64, depth int, score int, alphaOrig int, betaOrig int, bestMove Move) {
	flag := ttExact
	if score <= alphaOrig {
		flag = ttUpperBound
	} else if score >= betaOrig {
		flag = ttLowerBound
	}

	if existing, ok := ai.transposition[hash]; ok && existing.Depth > depth {
		return
	}

	if len(ai.transposition) >= 1<<20 {
		ai.transposition = make(map[uint64]TTEntry, 1<<16)
	}

	ai.transposition[hash] = TTEntry{
		Depth:       depth,
		Score:       score,
		Flag:        flag,
		BestMove:    bestMove,
		HasBestMove: true,
	}
}

func (ai *AI) getTTMove(hash uint64) (Move, bool) {
	entry, ok := ai.transposition[hash]
	if !ok || !entry.HasBestMove {
		return Move{}, false
	}
	return entry.BestMove, true
}

type scoredMove struct {
	move     Move
	score    int
	notation string
}

func (ai *AI) orderMoves(moves []Move, ttMove Move, hasTTMove bool) []Move {
	scored := make([]scoredMove, 0, len(moves))
	for _, move := range moves {
		score := ai.moveOrderScore(move)
		if hasTTMove && movesEqual(move, ttMove) {
			score += 1_000_000
		}
		scored = append(scored, scoredMove{
			move:     move,
			score:    score,
			notation: moveToNotation(move),
		})
	}

	sort.SliceStable(scored, func(i, j int) bool {
		if scored[i].score != scored[j].score {
			return scored[i].score > scored[j].score
		}
		return scored[i].notation < scored[j].notation
	})

	ordered := make([]Move, len(scored))
	for i := range scored {
		ordered[i] = scored[i].move
	}
	return ordered
}

func (ai *AI) moveOrderScore(move Move) int {
	score := 0

	if move.IsCapture {
		victimValue := 0
		if move.Captured != nil {
			victimValue = pieceValues[move.Captured.Type]
		}
		attackerValue := pieceValues[move.Piece.Type]
		score += victimValue*10 - attackerValue
	}

	if move.IsPromotion {
		score += pieceValues[move.PromoteTo] * 10
	}

	if move.IsCastle {
		score += 25
	}

	return score
}

func moveToNotation(move Move) string {
	notation := move.From.ToAlgebraic() + move.To.ToAlgebraic()
	if move.IsPromotion {
		switch move.PromoteTo {
		case Queen:
			notation += "q"
		case Rook:
			notation += "r"
		case Bishop:
			notation += "b"
		case Knight:
			notation += "n"
		}
	}
	return notation
}

func movesEqual(a, b Move) bool {
	if a.From != b.From || a.To != b.To || a.IsPromotion != b.IsPromotion {
		return false
	}
	if a.IsPromotion {
		return a.PromoteTo == b.PromoteTo
	}
	return true
}

func (ai *AI) evaluate(gs *GameState) int {
	score := 0

	// Material and positional evaluation
	for rank := 0; rank < 8; rank++ {
		for file := 0; file < 8; file++ {
			piece := gs.Board[rank][file]
			if !piece.IsEmpty() {
				pieceValue := ai.evaluatePiece(piece, Square{file, rank})
				if piece.Color == White {
					score += pieceValue
				} else {
					score -= pieceValue
				}
			}
		}
	}

	// Mobility bonus
	whiteMoves := 0
	blackMoves := 0

	// Count white moves
	if gs.ActiveColor == White {
		whiteMoves = len(gs.GenerateLegalMoves())
	} else {
		// Switch to white temporarily to count moves
		tempState := gs.Clone()
		tempState.ActiveColor = White
		whiteMoves = len(tempState.GenerateLegalMoves())
	}

	// Count black moves
	if gs.ActiveColor == Black {
		blackMoves = len(gs.GenerateLegalMoves())
	} else {
		// Switch to black temporarily to count moves
		tempState := gs.Clone()
		tempState.ActiveColor = Black
		blackMoves = len(tempState.GenerateLegalMoves())
	}

	// Mobility bonus (each legal move is worth a small amount)
	score += (whiteMoves - blackMoves) * 3

	// Return score from current player's perspective
	if gs.ActiveColor == White {
		return score
	} else {
		return -score
	}
}

func (ai *AI) evaluatePiece(piece Piece, square Square) int {
	value := pieceValues[piece.Type]

	// Positional bonuses
	rank := square.Rank
	file := square.File

	// Flip the board for black pieces
	if piece.Color == Black {
		rank = 7 - rank
	}

	switch piece.Type {
	case Pawn:
		value += pawnTable[rank][file]
		// Bonus for advanced pawns
		if piece.Color == White {
			value += square.Rank * 5
		} else {
			value += (7 - square.Rank) * 5
		}

	case Knight:
		value += knightTable[rank][file]
		// Central control bonus
		if (file >= 2 && file <= 5) && (rank >= 2 && rank <= 5) {
			value += 10
		}

	case Bishop:
		value += bishopTable[rank][file]
		// Central control bonus
		if (file >= 2 && file <= 5) && (rank >= 2 && rank <= 5) {
			value += 10
		}

	case Rook:
		value += rookTable[rank][file]
		// Open file bonus (simplified)
		if ai.isOpenFile(square.File, piece.Color) {
			value += 15
		}

	case Queen:
		value += queenTable[rank][file]
		// Central control bonus
		if (file >= 2 && file <= 5) && (rank >= 2 && rank <= 5) {
			value += 10
		}

	case King:
		value += kingMiddlegameTable[rank][file]
		// Safety evaluation would go here in a more sophisticated engine
	}

	return value
}

func (ai *AI) isOpenFile(file int, color Color) bool {
	// Simplified open file detection
	// In a real engine, you'd check if there are no pawns on this file
	return false
}

func (ai *AI) GetNodesEvaluated() int {
	return ai.nodesEvaluated
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
