package main

import (
	"fmt"
	"os"
	"regexp"
	"strconv"
	"strings"
)

const pgnStartFEN = StartingPositionFEN

var pgnQuotedCommentPattern = regexp.MustCompile(`(?i)^pgn\s+comment\s+"((?:\\.|[^"])*)"\s*$`)
var pgnPlainCommentPattern = regexp.MustCompile(`(?i)^pgn\s+comment\s+(.+)$`)

type PgnMoveNode struct {
	SAN        string
	Move       Move
	FenBefore  string
	FenAfter   string
	NAGs       []string
	Comments   []string
	Variations []*PgnVariation
}

type PgnVariation struct {
	StartFEN        string
	LeadingComments []string
	Moves           []*PgnMoveNode
	Result          string
}

type pgnCursor struct {
	variation *PgnVariation
}

type PgnGame struct {
	Tags        map[string]string
	Mainline    *PgnVariation
	Result      string
	Source      string
	cursorStack []pgnCursor
}

func newPgnGame(source string, tags map[string]string, mainline *PgnVariation, result string) *PgnGame {
	if mainline == nil {
		mainline = &PgnVariation{StartFEN: pgnStartFEN}
	}
	if mainline.StartFEN == "" {
		mainline.StartFEN = pgnStartFEN
	}
	if mainline.Moves == nil {
		mainline.Moves = make([]*PgnMoveNode, 0)
	}
	if mainline.LeadingComments == nil {
		mainline.LeadingComments = make([]string, 0)
	}
	game := &PgnGame{
		Tags:     tags,
		Mainline: mainline,
		Result:   result,
		Source:   source,
	}
	game.syncResultTag()
	game.ResetCursor()
	return game
}

func (game *PgnGame) syncResultTag() {
	if game.Tags == nil {
		game.Tags = map[string]string{}
	}
	game.Tags["Result"] = game.Result
}

func (game *PgnGame) ResetCursor() {
	if game.Mainline == nil {
		game.Mainline = &PgnVariation{StartFEN: pgnStartFEN}
	}
	if game.Mainline.StartFEN == "" {
		game.Mainline.StartFEN = pgnStartFEN
	}
	game.cursorStack = []pgnCursor{{variation: game.Mainline}}
}

func (game *PgnGame) SetSource(source string) {
	game.Source = source
}

func (game *PgnGame) SetResult(result string) {
	game.Result = result
	game.syncResultTag()
	if game.Mainline != nil {
		game.Mainline.Result = result
	}
}

func (game *PgnGame) CurrentVariation() *PgnVariation {
	if len(game.cursorStack) == 0 {
		game.ResetCursor()
	}
	return game.cursorStack[len(game.cursorStack)-1].variation
}

func (game *PgnGame) CurrentMove() *PgnMoveNode {
	variation := game.CurrentVariation()
	if variation == nil || len(variation.Moves) == 0 {
		return nil
	}
	return variation.Moves[len(variation.Moves)-1]
}

func (game *PgnGame) CurrentMoves() []string {
	variation := game.CurrentVariation()
	if variation == nil {
		return nil
	}
	moves := make([]string, 0, len(variation.Moves))
	for _, move := range variation.Moves {
		moves = append(moves, move.SAN)
	}
	return moves
}

func (game *PgnGame) MainlineMoves() []string {
	if game.Mainline == nil {
		return nil
	}
	moves := make([]string, 0, len(game.Mainline.Moves))
	for _, move := range game.Mainline.Moves {
		moves = append(moves, move.SAN)
	}
	return moves
}

func (game *PgnGame) AppendMove(node *PgnMoveNode) {
	variation := game.CurrentVariation()
	if variation == nil {
		return
	}
	variation.Moves = append(variation.Moves, node)
}

func (game *PgnGame) RewindLastMove() bool {
	variation := game.CurrentVariation()
	if variation == nil || len(variation.Moves) == 0 {
		return false
	}
	variation.Moves = variation.Moves[:len(variation.Moves)-1]
	game.SetResult("*")
	return true
}

func (game *PgnGame) AddComment(text string) {
	text = strings.TrimSpace(text)
	if text == "" {
		return
	}
	move := game.CurrentMove()
	if move != nil {
		move.Comments = append(move.Comments, text)
		return
	}
	variation := game.CurrentVariation()
	if variation != nil {
		variation.LeadingComments = append(variation.LeadingComments, text)
	}
}

func (game *PgnGame) EnterVariation() (bool, string) {
	move := game.CurrentMove()
	if move == nil {
		return false, "ERROR: pgn variation enter requires a current move"
	}
	if len(move.Variations) == 0 {
		move.Variations = append(move.Variations, &PgnVariation{StartFEN: move.FenBefore, Moves: make([]*PgnMoveNode, 0), LeadingComments: make([]string, 0)})
	}
	variation := move.Variations[0]
	if variation.StartFEN == "" {
		variation.StartFEN = move.FenBefore
	}
	if variation.Moves == nil {
		variation.Moves = make([]*PgnMoveNode, 0)
	}
	if variation.LeadingComments == nil {
		variation.LeadingComments = make([]string, 0)
	}
	game.cursorStack = append(game.cursorStack, pgnCursor{variation: variation})
	return true, fmt.Sprintf("PGN: variation depth=%d; moves=%d", len(game.cursorStack)-1, len(variation.Moves))
}

func (game *PgnGame) ExitVariation() (bool, string) {
	if len(game.cursorStack) <= 1 {
		return false, "ERROR: already at mainline"
	}
	game.cursorStack = game.cursorStack[:len(game.cursorStack)-1]
	return true, fmt.Sprintf("PGN: variation depth=%d; moves=%d", len(game.cursorStack)-1, len(game.CurrentVariation().Moves))
}

func newPgnGameFromHistory(history []Move, startFEN, source string) *PgnGame {
	if startFEN == "" {
		startFEN = pgnStartFEN
	}
	gs, err := gameStateFromFEN(startFEN)
	if err != nil {
		gs = NewGameState()
		startFEN = gs.ToFEN()
	}
	game := newPgnGame(source, map[string]string{
		"Event":  "CLI Game",
		"Site":   "Local",
		"Result": "*",
	}, &PgnVariation{StartFEN: startFEN, Moves: make([]*PgnMoveNode, 0, len(history)), LeadingComments: make([]string, 0)}, "*")
	if startFEN != pgnStartFEN {
		game.Tags["SetUp"] = "1"
		game.Tags["FEN"] = startFEN
	}
	for _, raw := range history {
		move := cloneMove(raw)
		fenBefore := gs.ToFEN()
		san, err := moveToSAN(gs, move)
		if err != nil {
			san = moveToString(move)
		}
		gs.MakeMove(move)
		fenAfter := gs.ToFEN()
		game.Mainline.Moves = append(game.Mainline.Moves, &PgnMoveNode{SAN: san, Move: cloneMove(move), FenBefore: fenBefore, FenAfter: fenAfter})
	}
	game.ResetCursor()
	return game
}

func cloneMove(move Move) Move {
	clone := move
	if move.Captured != nil {
		captured := *move.Captured
		clone.Captured = &captured
	}
	return clone
}

func gameStateFromFEN(fen string) (*GameState, error) {
	gs := NewGameState()
	if err := gs.FromFEN(fen); err != nil {
		return nil, err
	}
	gs.MoveHistory = nil
	gs.StateHistory = nil
	gs.PositionHistory = nil
	gs.ZobristHash = computeZobristHash(gs)
	return gs, nil
}

func moveToSAN(gs *GameState, move Move) (string, error) {
	piece := gs.GetPiece(move.From)
	if piece.IsEmpty() {
		return "", fmt.Errorf("missing moving piece for SAN serialization")
	}
	target := gs.GetPiece(move.To)
	isCapture := move.IsEnPassant || !target.IsEmpty()
	var san string
	if move.IsCastle {
		if move.To.File == 6 {
			san = "O-O"
		} else {
			san = "O-O-O"
		}
	} else {
		destination := move.To.ToAlgebraic()
		promotion := ""
		if move.IsPromotion {
			promotion = "=" + pieceLetter(move.PromoteTo)
		}
		if piece.Type == Pawn {
			prefix := ""
			if isCapture {
				prefix = string(rune('a'+move.From.File)) + "x"
			}
			san = prefix + destination + promotion
		} else {
			prefix := pieceLetter(piece.Type) + disambiguation(gs, move, piece)
			if isCapture {
				prefix += "x"
			}
			san = prefix + destination + promotion
		}
	}
	test := gs.Clone()
	test.MakeMove(cloneMove(move))
	if test.IsInCheck(test.ActiveColor) {
		if len(test.GenerateLegalMoves()) == 0 {
			san += "#"
		} else {
			san += "+"
		}
	}
	return san, nil
}

func pieceLetter(piece PieceType) string {
	switch piece {
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
	default:
		return ""
	}
}

func disambiguation(gs *GameState, move Move, piece Piece) string {
	legal := gs.GenerateLegalMoves()
	clashes := make([]Move, 0)
	for _, candidate := range legal {
		if candidate.From == move.From && candidate.To == move.To && candidate.PromoteTo == move.PromoteTo {
			continue
		}
		other := gs.GetPiece(candidate.From)
		if other.Type == piece.Type && other.Color == piece.Color && candidate.To == move.To {
			clashes = append(clashes, candidate)
		}
	}
	if len(clashes) == 0 {
		return ""
	}
	sameFile := false
	sameRank := false
	for _, candidate := range clashes {
		if candidate.From.File == move.From.File {
			sameFile = true
		}
		if candidate.From.Rank == move.From.Rank {
			sameRank = true
		}
	}
	if !sameFile {
		return string(rune('a' + move.From.File))
	}
	if !sameRank {
		return string(rune('1' + move.From.Rank))
	}
	return string(rune('a'+move.From.File)) + string(rune('1'+move.From.Rank))
}

func normalizeSAN(token string) string {
	cleaned := strings.TrimSpace(token)
	for len(cleaned) > 0 {
		last := cleaned[len(cleaned)-1]
		if last == '+' || last == '#' || last == '!' || last == '?' {
			cleaned = cleaned[:len(cleaned)-1]
			continue
		}
		break
	}
	cleaned = strings.ReplaceAll(cleaned, "0-0-0", "O-O-O")
	cleaned = strings.ReplaceAll(cleaned, "0-0", "O-O")
	cleaned = strings.ReplaceAll(cleaned, "e.p.", "")
	cleaned = strings.ReplaceAll(cleaned, "ep", "")
	if dot := strings.Index(cleaned, "."); dot >= 0 {
		prefix := cleaned[:dot+1]
		allNumeric := true
		for _, ch := range prefix[:len(prefix)-1] {
			if ch < '0' || ch > '9' {
				allNumeric = false
				break
			}
		}
		if allNumeric {
			cleaned = cleaned[dot+1:]
			cleaned = strings.TrimLeft(cleaned, ".")
		}
	}
	return strings.TrimSpace(cleaned)
}

func sanToMove(gs *GameState, san string) (Move, error) {
	normalized := normalizeSAN(san)
	for _, move := range gs.GenerateLegalMoves() {
		candidate, err := moveToSAN(gs, move)
		if err != nil {
			continue
		}
		if normalizeSAN(candidate) == normalized {
			return move, nil
		}
	}
	return Move{}, fmt.Errorf("unresolved SAN move: %s", san)
}

type pgnToken struct {
	Kind  string
	Value string
}

func tokenizePGN(content string) ([]pgnToken, error) {
	tokens := make([]pgnToken, 0)
	for i := 0; i < len(content); {
		ch := content[i]
		if ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t' {
			i++
			continue
		}
		switch ch {
		case '[':
			end := strings.IndexByte(content[i:], ']')
			if end < 0 {
				return nil, fmt.Errorf("unterminated PGN tag")
			}
			raw := strings.TrimSpace(content[i+1 : i+end])
			firstSpace := strings.IndexAny(raw, " \t")
			if firstSpace <= 0 {
				return nil, fmt.Errorf("invalid PGN tag: [%s]", raw)
			}
			name := strings.TrimSpace(raw[:firstSpace])
			rest := strings.TrimSpace(raw[firstSpace:])
			if len(rest) < 2 || rest[0] != '"' || rest[len(rest)-1] != '"' {
				return nil, fmt.Errorf("invalid PGN tag: [%s]", raw)
			}
			value := strings.ReplaceAll(rest[1:len(rest)-1], `\"`, `"`)
			tokens = append(tokens, pgnToken{Kind: "TAG", Value: name + "\n" + value})
			i += end + 1
		case '{':
			end := strings.IndexByte(content[i:], '}')
			if end < 0 {
				return nil, fmt.Errorf("unterminated PGN comment")
			}
			tokens = append(tokens, pgnToken{Kind: "COMMENT", Value: strings.TrimSpace(content[i+1 : i+end])})
			i += end + 1
		case ';':
			end := strings.IndexByte(content[i:], '\n')
			if end < 0 {
				end = len(content) - i
			}
			tokens = append(tokens, pgnToken{Kind: "COMMENT", Value: strings.TrimSpace(content[i+1 : i+end])})
			i += end
		case '(':
			tokens = append(tokens, pgnToken{Kind: "LPAREN", Value: "("})
			i++
		case ')':
			tokens = append(tokens, pgnToken{Kind: "RPAREN", Value: ")"})
			i++
		case '$':
			start := i
			i++
			for i < len(content) && content[i] >= '0' && content[i] <= '9' {
				i++
			}
			tokens = append(tokens, pgnToken{Kind: "NAG", Value: content[start:i]})
		default:
			start := i
			for i < len(content) && !strings.ContainsRune(" []{}();\n\r\t", rune(content[i])) {
				i++
			}
			value := content[start:i]
			switch value {
			case "1-0", "0-1", "1/2-1/2", "*":
				tokens = append(tokens, pgnToken{Kind: "RESULT", Value: value})
			default:
				if strings.HasSuffix(value, ".") {
					numeric := true
					for _, ch2 := range strings.TrimRight(value, ".") {
						if ch2 < '0' || ch2 > '9' {
							numeric = false
							break
						}
					}
					if numeric {
						tokens = append(tokens, pgnToken{Kind: "MOVE_NO", Value: value})
						continue
					}
				}
				tokens = append(tokens, pgnToken{Kind: "SAN", Value: value})
			}
		}
	}
	return tokens, nil
}

func parsePGN(content, source string) (*PgnGame, error) {
	tokens, err := tokenizePGN(content)
	if err != nil {
		return nil, err
	}
	idx := 0
	tags := map[string]string{}
	for idx < len(tokens) && tokens[idx].Kind == "TAG" {
		parts := strings.SplitN(tokens[idx].Value, "\n", 2)
		if len(parts) == 2 {
			tags[parts[0]] = parts[1]
		}
		idx++
	}
	initialFEN := tags["FEN"]
	if initialFEN == "" {
		initialFEN = pgnStartFEN
	}
	gs, err := gameStateFromFEN(initialFEN)
	if err != nil {
		return nil, err
	}
	mainline, result, err := parsePGNSequence(tokens, &idx, gs, initialFEN, true)
	if err != nil {
		return nil, err
	}
	if result == "" {
		result = tags["Result"]
		if result == "" {
			result = "*"
		}
	}
	if _, ok := tags["Result"]; !ok {
		tags["Result"] = result
	}
	if mainline == nil {
		mainline = &PgnVariation{StartFEN: initialFEN, Moves: make([]*PgnMoveNode, 0), LeadingComments: make([]string, 0)}
	}
	mainline.Result = result
	return newPgnGame(source, tags, mainline, result), nil
}

func parsePGNSequence(tokens []pgnToken, idx *int, gs *GameState, startFEN string, isRoot bool) (*PgnVariation, string, error) {
	variation := &PgnVariation{
		StartFEN:        startFEN,
		LeadingComments: make([]string, 0),
		Moves:           make([]*PgnMoveNode, 0),
	}
	result := ""
	for *idx < len(tokens) {
		tok := tokens[*idx]
		switch tok.Kind {
		case "RPAREN":
			return variation, result, nil
		case "RESULT":
			*idx++
			if isRoot {
				return variation, tok.Value, nil
			}
			variation.Result = tok.Value
			return variation, tok.Value, nil
		case "MOVE_NO":
			*idx++
		case "COMMENT":
			if len(variation.Moves) == 0 {
				variation.LeadingComments = append(variation.LeadingComments, tok.Value)
			} else {
				variation.Moves[len(variation.Moves)-1].Comments = append(variation.Moves[len(variation.Moves)-1].Comments, tok.Value)
			}
			*idx++
		case "NAG":
			if len(variation.Moves) == 0 {
				return nil, "", fmt.Errorf("NAG without move")
			}
			variation.Moves[len(variation.Moves)-1].NAGs = append(variation.Moves[len(variation.Moves)-1].NAGs, tok.Value)
			*idx++
		case "LPAREN":
			if len(variation.Moves) == 0 {
				return nil, "", fmt.Errorf("variation without anchor move")
			}
			*idx++
			anchor := variation.Moves[len(variation.Moves)-1]
			variationGS, err := gameStateFromFEN(anchor.FenBefore)
			if err != nil {
				return nil, "", err
			}
			child, variationResult, err := parsePGNSequence(tokens, idx, variationGS, anchor.FenBefore, false)
			if err != nil {
				return nil, "", err
			}
			if *idx >= len(tokens) || tokens[*idx].Kind != "RPAREN" {
				return nil, "", fmt.Errorf("unterminated PGN variation")
			}
			*idx++
			if child != nil {
				if child.StartFEN == "" {
					child.StartFEN = anchor.FenBefore
				}
				if variationResult != "" {
					child.Result = variationResult
				}
				anchor.Variations = append(anchor.Variations, child)
			}
		case "SAN":
			fenBefore := gs.ToFEN()
			move, err := sanToMove(gs, tok.Value)
			if err != nil {
				return nil, "", err
			}
			san, err := moveToSAN(gs, move)
			if err != nil {
				return nil, "", err
			}
			gs.MakeMove(move)
			variation.Moves = append(variation.Moves, &PgnMoveNode{SAN: san, Move: cloneMove(move), FenBefore: fenBefore, FenAfter: gs.ToFEN()})
			*idx++
		default:
			return nil, "", fmt.Errorf("unexpected PGN token: %s", tok.Kind)
		}
	}
	return variation, result, nil
}

func serializePGN(game *PgnGame) string {
	if game == nil {
		return ""
	}
	var lines []string
	orderedTags := []string{"Event", "Site", "Date", "Round", "White", "Black", "Result", "SetUp", "FEN"}
	seen := map[string]bool{}
	for _, key := range orderedTags {
		if value, ok := game.Tags[key]; ok {
			lines = append(lines, fmt.Sprintf("[%s \"%s\"]", key, strings.ReplaceAll(value, `"`, `\"`)))
			seen[key] = true
		}
	}
	for key, value := range game.Tags {
		if !seen[key] {
			lines = append(lines, fmt.Sprintf("[%s \"%s\"]", key, strings.ReplaceAll(value, `"`, `\"`)))
		}
	}
	if len(lines) > 0 {
		lines = append(lines, "")
	}
	startFEN := pgnStartFEN
	if game.Mainline != nil && strings.TrimSpace(game.Mainline.StartFEN) != "" {
		startFEN = strings.TrimSpace(game.Mainline.StartFEN)
	}
	moveNumber, color := startingPly(startFEN)
	moveText := serializePGNVariation(game.Mainline, moveNumber, color, true)
	if game.Result != "" {
		moveText = strings.TrimSpace(moveText + " " + game.Result)
	}
	lines = append(lines, strings.TrimSpace(moveText))
	return strings.TrimSpace(strings.Join(lines, "\n")) + "\n"
}

func startingPly(fen string) (int, Color) {
	parts := strings.Fields(strings.TrimSpace(fen))
	if len(parts) >= 6 {
		moveNumber, err := strconv.Atoi(parts[5])
		if err != nil || moveNumber < 1 {
			moveNumber = 1
		}
		if parts[1] == "b" {
			return moveNumber, Black
		}
		return moveNumber, White
	}
	return 1, White
}

func serializePGNVariation(variation *PgnVariation, moveNumber int, color Color, isRoot bool) string {
	if variation == nil {
		return ""
	}
	parts := make([]string, 0)
	for _, comment := range variation.LeadingComments {
		parts = append(parts, "{"+comment+"}")
	}
	currentMoveNumber := moveNumber
	currentColor := color
	for _, node := range variation.Moves {
		if currentColor == White {
			parts = append(parts, fmt.Sprintf("%d. %s", currentMoveNumber, node.SAN))
		} else {
			if len(parts) == 0 || !strings.HasPrefix(parts[len(parts)-1], fmt.Sprintf("%d.", currentMoveNumber)) {
				parts = append(parts, fmt.Sprintf("%d... %s", currentMoveNumber, node.SAN))
			} else {
				parts = append(parts, node.SAN)
			}
		}
		parts = append(parts, node.NAGs...)
		for _, comment := range node.Comments {
			parts = append(parts, "{"+comment+"}")
		}
		for _, variation := range node.Variations {
			parts = append(parts, "("+serializePGNVariation(variation, currentMoveNumber, currentColor, false)+")")
		}
		if currentColor == Black {
			currentMoveNumber++
			currentColor = White
		} else {
			currentColor = Black
		}
	}
	if !isRoot && strings.TrimSpace(variation.Result) != "" {
		parts = append(parts, variation.Result)
	}
	return strings.TrimSpace(strings.Join(parts, " "))
}

func loadPGNFile(path string) (*PgnGame, error) {
	content, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return parsePGN(string(content), path)
}

func extractPgnCommentText(command string) (string, bool) {
	trimmed := strings.TrimSpace(command)
	if matches := pgnQuotedCommentPattern.FindStringSubmatch(trimmed); len(matches) == 2 {
		text := strings.ReplaceAll(matches[1], `\"`, `"`)
		text = strings.ReplaceAll(text, `\\`, `\\`)
		return text, true
	}
	if matches := pgnPlainCommentPattern.FindStringSubmatch(trimmed); len(matches) == 2 {
		text := strings.TrimSpace(matches[1])
		if text != "" {
			return text, true
		}
	}
	return "", false
}
