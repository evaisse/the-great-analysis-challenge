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

type AI struct {
	nodesEvaluated int
	evalCalls      int
	ttHits         int
	ttMisses       int
	betaCutoffs    int
	moveGenCalls   int
	moveGenTimeNS  int64
	moveGenTotal   int
	evalTimeNS     int64
	tt             map[uint64]TTEntry
	deadline       time.Time
	timedOut       bool
	depthSummaries []DepthSummary
	lastSnapshot   *TraceSnapshot
}

type DepthSummary struct {
	Depth        int    `json:"depth"`
	ElapsedMS    int64  `json:"elapsed_ms"`
	Nodes        int    `json:"nodes"`
	EvalCalls    int    `json:"eval_calls"`
	MoveGenCalls int    `json:"move_gen_calls"`
	BestMove     string `json:"best_move,omitempty"`
	ScoreCP      int    `json:"score_cp"`
}

type TraceSnapshot struct {
	ElapsedMS       int64          `json:"elapsed_ms"`
	BestMove        string         `json:"best_move,omitempty"`
	BestScoreCP     int            `json:"best_score_cp"`
	DepthReached    int            `json:"depth_reached"`
	TimedOut        bool           `json:"timed_out"`
	Nodes           int            `json:"nodes"`
	NPS             int64          `json:"nps"`
	EvalCalls       int            `json:"eval_calls"`
	EvalTimeMS      float64        `json:"eval_time_ms"`
	MoveGenCalls    int            `json:"move_gen_calls"`
	MoveGenTimeMS   float64        `json:"move_gen_time_ms"`
	MoveGenTotal    int            `json:"move_gen_total_moves"`
	BranchingFactor float64        `json:"branching_factor"`
	TTHits          int            `json:"tt_hits"`
	TTMisses        int            `json:"tt_misses"`
	BetaCutoffs     int            `json:"beta_cutoffs"`
	DepthBreakdown  []DepthSummary `json:"depth_breakdown"`
}

type TTFlag int

const (
	TTExact TTFlag = iota
	TTLowerBound
	TTUpperBound
)

type TTEntry struct {
	Depth    int
	Score    int
	Flag     TTFlag
	BestMove Move
}

type SearchResult struct {
	Move        Move
	Score       int
	Depth       int
	TimedOut    bool
	ElapsedMS   int64
	Nodes       int
	EvalCalls   int
	TTHits      int
	TTMisses    int
	BetaCutoffs int
}

func NewAI() *AI {
	return &AI{
		nodesEvaluated: 0,
		ttHits:         0,
		ttMisses:       0,
		betaCutoffs:    0,
		moveGenCalls:   0,
		moveGenTimeNS:  0,
		moveGenTotal:   0,
		evalTimeNS:     0,
		tt:             make(map[uint64]TTEntry, 1<<16),
	}
}

func (ai *AI) FindBestMove(gs *GameState, depth int) Move {
	result := ai.Search(gs, depth, 0)
	return result.Move
}

func (ai *AI) Search(gs *GameState, depth int, movetimeMs int) SearchResult {
	ai.nodesEvaluated = 0
	ai.evalCalls = 0
	ai.ttHits = 0
	ai.ttMisses = 0
	ai.betaCutoffs = 0
	ai.moveGenCalls = 0
	ai.moveGenTimeNS = 0
	ai.moveGenTotal = 0
	ai.evalTimeNS = 0
	ai.timedOut = false
	ai.depthSummaries = nil
	ai.lastSnapshot = nil

	if depth < 1 || depth > MAX_DEPTH {
		depth = 3
	}

	start := time.Now()
	if movetimeMs > 0 {
		ai.deadline = start.Add(time.Duration(movetimeMs) * time.Millisecond)
	} else {
		ai.deadline = time.Time{}
	}

	legalMoves := ai.generateLegalMovesTimed(gs)
	if len(legalMoves) == 0 {
		ai.lastSnapshot = ai.buildTraceSnapshot(0, "", DRAW_VALUE, 0, false)
		return SearchResult{
			Move:        Move{},
			Score:       DRAW_VALUE,
			Depth:       0,
			TimedOut:    false,
			ElapsedMS:   time.Since(start).Milliseconds(),
			Nodes:       0,
			EvalCalls:   0,
			TTHits:      0,
			TTMisses:    0,
			BetaCutoffs: 0,
		}
	}

	bestMove := legalMoves[0]
	bestScore := NEG_INFINITY
	completedDepth := 0

	// Iterative deepening: keep the last fully completed depth result.
	for currentDepth := 1; currentDepth <= depth; currentDepth++ {
		depthStart := time.Now()
		nodesBefore := ai.nodesEvaluated
		evalCallsBefore := ai.evalCalls
		moveGenCallsBefore := ai.moveGenCalls
		score, move, ok := ai.searchRoot(gs, currentDepth)
		if !ok {
			break
		}
		ai.depthSummaries = append(ai.depthSummaries, DepthSummary{
			Depth:        currentDepth,
			ElapsedMS:    time.Since(depthStart).Milliseconds(),
			Nodes:        ai.nodesEvaluated - nodesBefore,
			EvalCalls:    ai.evalCalls - evalCallsBefore,
			MoveGenCalls: ai.moveGenCalls - moveGenCallsBefore,
			BestMove:     moveToString(move),
			ScoreCP:      score,
		})
		bestMove = move
		bestScore = score
		completedDepth = currentDepth
	}

	if completedDepth == 0 {
		// Fallback when timeout happens before completing depth=1.
		bestMove = legalMoves[0]
		bestScore = ai.evaluate(gs)
		completedDepth = 1
	}

	elapsedMS := time.Since(start).Milliseconds()
	ai.lastSnapshot = ai.buildTraceSnapshot(elapsedMS, moveToString(bestMove), bestScore, completedDepth, ai.timedOut)

	return SearchResult{
		Move:        bestMove,
		Score:       bestScore,
		Depth:       completedDepth,
		TimedOut:    ai.timedOut,
		ElapsedMS:   elapsedMS,
		Nodes:       ai.nodesEvaluated,
		EvalCalls:   ai.evalCalls,
		TTHits:      ai.ttHits,
		TTMisses:    ai.ttMisses,
		BetaCutoffs: ai.betaCutoffs,
	}
}

func (ai *AI) searchRoot(gs *GameState, depth int) (int, Move, bool) {
	if ai.timeExceeded() {
		return 0, Move{}, false
	}
	ai.nodesEvaluated++

	moves := ai.generateLegalMovesTimed(gs)
	if len(moves) == 0 {
		return DRAW_VALUE, Move{}, true
	}

	ttMove := Move{}
	if entry, ok := ai.tt[gs.ZobristHash]; ok {
		ai.ttHits++
		ttMove = entry.BestMove
	} else {
		ai.ttMisses++
	}
	orderedMoves := ai.orderMoves(moves, ttMove)

	bestScore := NEG_INFINITY
	bestMove := orderedMoves[0]
	alpha := NEG_INFINITY
	beta := INFINITY

	for _, move := range orderedMoves {
		if ai.timeExceeded() {
			return 0, Move{}, false
		}
		testState := gs.Clone()
		testState.MakeMove(move)

		score, _, ok := ai.negamax(testState, depth-1, -beta, -alpha)
		if !ok {
			return 0, Move{}, false
		}
		score = -score

		if score > bestScore {
			bestScore = score
			bestMove = move
		}
		if score > alpha {
			alpha = score
		}
	}

	return bestScore, bestMove, true
}

func (ai *AI) negamax(gs *GameState, depth int, alpha int, beta int) (int, Move, bool) {
	if ai.timeExceeded() {
		return 0, Move{}, false
	}
	ai.nodesEvaluated++

	if gs.IsDraw() {
		return DRAW_VALUE, Move{}, true
	}

	originalAlpha := alpha
	bestMove := Move{}

	if entry, ok := ai.tt[gs.ZobristHash]; ok {
		if entry.Depth >= depth {
			ai.ttHits++
			switch entry.Flag {
			case TTExact:
				return entry.Score, entry.BestMove, true
			case TTLowerBound:
				if entry.Score > alpha {
					alpha = entry.Score
				}
			case TTUpperBound:
				if entry.Score < beta {
					beta = entry.Score
				}
			}
			if alpha >= beta {
				ai.betaCutoffs++
				return entry.Score, entry.BestMove, true
			}
			bestMove = entry.BestMove
		} else {
			ai.ttMisses++
		}
	} else {
		ai.ttMisses++
	}

	if depth == 0 {
		return ai.evaluate(gs), Move{}, true
	}

	moves := ai.generateLegalMovesTimed(gs)
	if len(moves) == 0 {
		if gs.IsInCheck(gs.ActiveColor) {
			return -MATE_VALUE + (MAX_DEPTH - depth), Move{}, true
		}
		return DRAW_VALUE, Move{}, true
	}

	orderedMoves := ai.orderMoves(moves, bestMove)
	bestScore := NEG_INFINITY
	bestSoFar := orderedMoves[0]

	for _, move := range orderedMoves {
		if ai.timeExceeded() {
			return 0, Move{}, false
		}
		testState := gs.Clone()
		testState.MakeMove(move)

		score, _, ok := ai.negamax(testState, depth-1, -beta, -alpha)
		if !ok {
			return 0, Move{}, false
		}
		score = -score

		if score > bestScore {
			bestScore = score
			bestSoFar = move
		}
		if score > alpha {
			alpha = score
		}
		if alpha >= beta {
			ai.betaCutoffs++
			break
		}
	}

	flag := TTExact
	if bestScore <= originalAlpha {
		flag = TTUpperBound
	} else if bestScore >= beta {
		flag = TTLowerBound
	}

	ai.tt[gs.ZobristHash] = TTEntry{
		Depth:    depth,
		Score:    bestScore,
		Flag:     flag,
		BestMove: bestSoFar,
	}

	return bestScore, bestSoFar, true
}

func (ai *AI) orderMoves(moves []Move, ttMove Move) []Move {
	type scoredMove struct {
		move  Move
		score int
	}
	scored := make([]scoredMove, 0, len(moves))
	for _, move := range moves {
		score := 0
		if sameMove(move, ttMove) {
			score += 100000
		}
		if move.IsCapture {
			score += 10000
			if move.Captured != nil {
				score += pieceValues[move.Captured.Type]
			}
		}
		if move.IsPromotion {
			score += 9000
			score += pieceValues[move.PromoteTo]
		}
		if move.IsCastle {
			score += 100
		}
		scored = append(scored, scoredMove{move: move, score: score})
	}

	sort.Slice(scored, func(i, j int) bool {
		return scored[i].score > scored[j].score
	})

	ordered := make([]Move, 0, len(scored))
	for _, s := range scored {
		ordered = append(ordered, s.move)
	}
	return ordered
}

func sameMove(a Move, b Move) bool {
	return a.From == b.From &&
		a.To == b.To &&
		a.IsPromotion == b.IsPromotion &&
		(!a.IsPromotion || a.PromoteTo == b.PromoteTo)
}

func (ai *AI) timeExceeded() bool {
	if ai.deadline.IsZero() {
		return false
	}
	if time.Now().After(ai.deadline) {
		ai.timedOut = true
		return true
	}
	return false
}

func (ai *AI) minimax(gs *GameState, depth int, alpha, beta int, maximizingPlayer bool) (int, Move) {
	ai.nodesEvaluated++

	if depth == 0 {
		return ai.evaluate(gs), Move{}
	}

	moves := gs.GenerateLegalMoves()

	// Check for terminal positions
	if len(moves) == 0 {
		if gs.IsInCheck(gs.ActiveColor) {
			// Checkmate
			if maximizingPlayer {
				return -MATE_VALUE + (MAX_DEPTH - depth), Move{}
			} else {
				return MATE_VALUE - (MAX_DEPTH - depth), Move{}
			}
		} else {
			// Stalemate
			return DRAW_VALUE, Move{}
		}
	}

	var bestMove Move

	if maximizingPlayer {
		maxEval := NEG_INFINITY

		for _, move := range moves {
			// Make move
			testState := gs.Clone()
			testState.MakeMove(move)

			eval, _ := ai.minimax(testState, depth-1, alpha, beta, false)

			if eval > maxEval {
				maxEval = eval
				bestMove = move
			}

			alpha = max(alpha, eval)
			if beta <= alpha {
				break // Alpha-beta pruning
			}
		}

		return maxEval, bestMove
	} else {
		minEval := INFINITY

		for _, move := range moves {
			// Make move
			testState := gs.Clone()
			testState.MakeMove(move)

			eval, _ := ai.minimax(testState, depth-1, alpha, beta, true)

			if eval < minEval {
				minEval = eval
				bestMove = move
			}

			beta = min(beta, eval)
			if beta <= alpha {
				break // Alpha-beta pruning
			}
		}

		return minEval, bestMove
	}
}

func (ai *AI) evaluate(gs *GameState) int {
	start := time.Now()
	ai.evalCalls++
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
		whiteMoves = len(ai.generateLegalMovesTimed(gs))
	} else {
		// Switch to white temporarily to count moves
		tempState := gs.Clone()
		tempState.ActiveColor = White
		whiteMoves = len(ai.generateLegalMovesTimed(tempState))
	}

	// Count black moves
	if gs.ActiveColor == Black {
		blackMoves = len(ai.generateLegalMovesTimed(gs))
	} else {
		// Switch to black temporarily to count moves
		tempState := gs.Clone()
		tempState.ActiveColor = Black
		blackMoves = len(ai.generateLegalMovesTimed(tempState))
	}

	// Mobility bonus (each legal move is worth a small amount)
	score += (whiteMoves - blackMoves) * 3

	// Return score from current player's perspective
	if gs.ActiveColor == White {
		ai.evalTimeNS += time.Since(start).Nanoseconds()
		return score
	} else {
		ai.evalTimeNS += time.Since(start).Nanoseconds()
		return -score
	}
}

func (ai *AI) generateLegalMovesTimed(gs *GameState) []Move {
	start := time.Now()
	moves := gs.GenerateLegalMoves()
	ai.moveGenCalls++
	ai.moveGenTimeNS += time.Since(start).Nanoseconds()
	ai.moveGenTotal += len(moves)
	return moves
}

func (ai *AI) buildTraceSnapshot(elapsedMS int64, bestMove string, bestScore int, depthReached int, timedOut bool) *TraceSnapshot {
	branchingFactor := 0.0
	if ai.moveGenCalls > 0 {
		branchingFactor = float64(ai.moveGenTotal) / float64(ai.moveGenCalls)
	}

	depthBreakdown := make([]DepthSummary, len(ai.depthSummaries))
	copy(depthBreakdown, ai.depthSummaries)

	nps := int64(0)
	if ai.nodesEvaluated > 0 {
		divisor := elapsedMS
		if divisor <= 0 {
			divisor = 1
		}
		nps = int64(ai.nodesEvaluated) * 1000 / divisor
	}

	return &TraceSnapshot{
		ElapsedMS:       elapsedMS,
		BestMove:        bestMove,
		BestScoreCP:     bestScore,
		DepthReached:    depthReached,
		TimedOut:        timedOut,
		Nodes:           ai.nodesEvaluated,
		NPS:             nps,
		EvalCalls:       ai.evalCalls,
		EvalTimeMS:      float64(ai.evalTimeNS) / 1_000_000,
		MoveGenCalls:    ai.moveGenCalls,
		MoveGenTimeMS:   float64(ai.moveGenTimeNS) / 1_000_000,
		MoveGenTotal:    ai.moveGenTotal,
		BranchingFactor: branchingFactor,
		TTHits:          ai.ttHits,
		TTMisses:        ai.ttMisses,
		BetaCutoffs:     ai.betaCutoffs,
		DepthBreakdown:  depthBreakdown,
	}
}

func (ai *AI) GetTraceSnapshot() *TraceSnapshot {
	if ai.lastSnapshot == nil {
		return nil
	}
	clone := *ai.lastSnapshot
	clone.DepthBreakdown = append([]DepthSummary(nil), ai.lastSnapshot.DepthBreakdown...)
	return &clone
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

func (ai *AI) GetEvalCalls() int {
	return ai.evalCalls
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
