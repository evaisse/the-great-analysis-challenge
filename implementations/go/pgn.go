package main

import (
	"fmt"
	"regexp"
	"sort"
	"strings"
	"unicode"
)

type PgnMoveNode struct {
	SAN               string
	UCI               string
	MoveNumber        int
	Color             Color
	PositionBeforeFEN string
	NAGs              []string
	CommentsAfter     []string
	Variations        []*PgnVariation
}

type PgnVariation struct {
	StartFEN        string
	LeadingComments []string
	Moves           []*PgnMoveNode
	Result          string
}

type pgnCursor struct {
	variation   *PgnVariation
	cursorIndex int
}

type PgnGame struct {
	Source      string
	Tags        map[string]string
	Mainline    *PgnVariation
	Result      string
	cursorStack []pgnCursor
}

type pgnToken struct {
	Type  string
	Value string
	Name  string
}

type PgnParser struct {
	tokens []pgnToken
	index  int
}

var pgnQuotedCommentPattern = regexp.MustCompile(`(?i)^pgn\s+comment\s+"((?:\\.|[^"])*)"\s*$`)
var pgnPlainCommentPattern = regexp.MustCompile(`(?i)^pgn\s+comment\s+(.+)$`)

func NewPgnGame(source string, tags map[string]string, mainline *PgnVariation, result string) *PgnGame {
	game := &PgnGame{
		Source:   source,
		Tags:     clonePgnTags(tags),
		Mainline: mainline,
		Result:   result,
	}
	game.syncResultTag()
	game.ResetCursor()
	return game
}

func CreateLivePgnGame(source string, initialFEN string) *PgnGame {
	startFEN := strings.TrimSpace(initialFEN)
	if startFEN == "" {
		startFEN = StartingPositionFEN
	}

	tags := map[string]string{
		"Event":  "CLI Game",
		"Site":   "Local",
		"Date":   "????.??.??",
		"Round":  "-",
		"White":  "White",
		"Black":  "Black",
		"Result": "*",
	}
	if startFEN != StartingPositionFEN {
		tags["SetUp"] = "1"
		tags["FEN"] = startFEN
	}

	return NewPgnGame(source, tags, &PgnVariation{StartFEN: startFEN}, "*")
}

func clonePgnTags(tags map[string]string) map[string]string {
	cloned := make(map[string]string, len(tags))
	for key, value := range tags {
		cloned[key] = value
	}
	return cloned
}

func (game *PgnGame) ResetCursor() {
	game.cursorStack = []pgnCursor{{
		variation:   game.Mainline,
		cursorIndex: len(game.Mainline.Moves) - 1,
	}}
}

func (game *PgnGame) SetSource(source string) {
	game.Source = source
}

func (game *PgnGame) SetResult(result string) {
	game.Result = result
	game.syncResultTag()
}

func (game *PgnGame) MainlineMoves() []string {
	moves := make([]string, 0, len(game.Mainline.Moves))
	for _, move := range game.Mainline.Moves {
		moves = append(moves, move.SAN)
	}
	return moves
}

func (game *PgnGame) AppendMove(move *PgnMoveNode) {
	contextIndex := len(game.cursorStack) - 1
	variation := game.cursorStack[contextIndex].variation
	variation.Moves = append(variation.Moves, move)
	game.cursorStack[contextIndex].cursorIndex = len(variation.Moves) - 1
}

func (game *PgnGame) RewindLastMove() bool {
	contextIndex := len(game.cursorStack) - 1
	variation := game.cursorStack[contextIndex].variation
	cursorIndex := game.cursorStack[contextIndex].cursorIndex

	if cursorIndex != len(variation.Moves)-1 || cursorIndex < 0 {
		return false
	}

	variation.Moves = variation.Moves[:len(variation.Moves)-1]
	game.cursorStack[contextIndex].cursorIndex = len(variation.Moves) - 1
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
		move.CommentsAfter = append(move.CommentsAfter, text)
		return
	}

	variation := game.CurrentVariation()
	variation.LeadingComments = append(variation.LeadingComments, text)
}

func (game *PgnGame) EnterVariation() (bool, string) {
	move := game.CurrentMove()
	if move == nil {
		return false, "ERROR: pgn variation enter requires a current move"
	}

	if len(move.Variations) == 0 {
		move.Variations = append(move.Variations, &PgnVariation{StartFEN: move.PositionBeforeFEN})
	}

	variation := move.Variations[0]
	game.cursorStack = append(game.cursorStack, pgnCursor{
		variation:   variation,
		cursorIndex: len(variation.Moves) - 1,
	})

	return true, fmt.Sprintf("PGN: variation depth=%d; moves=%d", len(game.cursorStack)-1, len(variation.Moves))
}

func (game *PgnGame) ExitVariation() (bool, string) {
	if len(game.cursorStack) <= 1 {
		return false, "ERROR: already at mainline"
	}

	game.cursorStack = game.cursorStack[:len(game.cursorStack)-1]
	return true, fmt.Sprintf("PGN: variation depth=%d; moves=%d", len(game.cursorStack)-1, len(game.CurrentVariation().Moves))
}

func (game *PgnGame) CurrentVariation() *PgnVariation {
	return game.cursorStack[len(game.cursorStack)-1].variation
}

func (game *PgnGame) CurrentMove() *PgnMoveNode {
	context := game.cursorStack[len(game.cursorStack)-1]
	if context.cursorIndex < 0 {
		return nil
	}
	if context.cursorIndex >= len(context.variation.Moves) {
		return nil
	}
	return context.variation.Moves[context.cursorIndex]
}

func (game *PgnGame) Serialize() string {
	return serializePgnGame(game)
}

func (game *PgnGame) syncResultTag() {
	if game.Tags == nil {
		game.Tags = make(map[string]string)
	}
	game.Tags["Result"] = game.Result
}

func serializePgnGame(game *PgnGame) string {
	lines := make([]string, 0, len(game.Tags)+3)
	for _, tag := range orderedPgnTags(game.Tags) {
		escaped := strings.ReplaceAll(tag[1], `\`, `\\`)
		escaped = strings.ReplaceAll(escaped, `"`, `\"`)
		lines = append(lines, fmt.Sprintf("[%s \"%s\"]", tag[0], escaped))
	}

	lines = append(lines, "")
	movetext := strings.TrimSpace(serializePgnVariation(game.Mainline, true))
	if movetext != "" {
		lines = append(lines, movetext+" "+game.Result)
	} else {
		lines = append(lines, game.Result)
	}

	return strings.Join(lines, "\n")
}

func orderedPgnTags(tags map[string]string) [][2]string {
	orderedNames := []string{"Event", "Site", "Date", "Round", "White", "Black", "Result", "SetUp", "FEN"}
	remaining := clonePgnTags(tags)
	ordered := make([][2]string, 0, len(tags))

	for _, name := range orderedNames {
		if value, ok := remaining[name]; ok {
			ordered = append(ordered, [2]string{name, value})
			delete(remaining, name)
		}
	}

	extraKeys := make([]string, 0, len(remaining))
	for key := range remaining {
		extraKeys = append(extraKeys, key)
	}
	sort.Strings(extraKeys)
	for _, key := range extraKeys {
		ordered = append(ordered, [2]string{key, remaining[key]})
	}

	return ordered
}

func serializePgnVariation(variation *PgnVariation, isRoot bool) string {
	parts := make([]string, 0)
	for _, comment := range variation.LeadingComments {
		parts = append(parts, pgnCommentText(comment))
	}

	previousColor := Color(-1)
	for _, move := range variation.Moves {
		if move.Color == White {
			parts = append(parts, fmt.Sprintf("%d.", move.MoveNumber))
		} else if previousColor != White {
			parts = append(parts, fmt.Sprintf("%d...", move.MoveNumber))
		}

		parts = append(parts, move.SAN)
		parts = append(parts, move.NAGs...)
		for _, comment := range move.CommentsAfter {
			parts = append(parts, pgnCommentText(comment))
		}
		for _, child := range move.Variations {
			parts = append(parts, "("+serializePgnVariation(child, false)+")")
		}

		previousColor = move.Color
	}

	if !isRoot && strings.TrimSpace(variation.Result) != "" {
		parts = append(parts, variation.Result)
	}

	filtered := make([]string, 0, len(parts))
	for _, part := range parts {
		if strings.TrimSpace(part) != "" {
			filtered = append(filtered, part)
		}
	}
	return strings.TrimSpace(strings.Join(filtered, " "))
}

func pgnCommentText(comment string) string {
	return "{" + strings.TrimSpace(comment) + "}"
}

func (parser *PgnParser) Parse(content string, source string) (*PgnGame, error) {
	parser.tokens = parser.tokenize(content)
	parser.index = 0

	tags := make(map[string]string)
	for {
		token := parser.peek()
		if token == nil || token.Type != "TAG" {
			break
		}
		parser.index++
		tags[token.Name] = token.Value
	}

	if len(tags) == 0 {
		tags = clonePgnTags(CreateLivePgnGame(source, StartingPositionFEN).Tags)
	}

	startFEN := StartingPositionFEN
	if tags["SetUp"] == "1" && strings.TrimSpace(tags["FEN"]) != "" {
		startFEN = strings.TrimSpace(tags["FEN"])
	}

	mainline, result, err := parser.parseVariation(startFEN, true)
	if err != nil {
		return nil, err
	}
	if result == "" {
		result = tags["Result"]
	}
	if result == "" {
		result = "*"
	}

	return NewPgnGame(source, tags, mainline, result), nil
}

func (parser *PgnParser) parseVariation(startFEN string, isRoot bool) (*PgnVariation, string, error) {
	variation := &PgnVariation{StartFEN: startFEN}
	state, err := newPgnGameState(startFEN)
	if err != nil {
		return nil, "", fmt.Errorf("invalid PGN position state: %w", err)
	}

	result := ""
	var lastMove *PgnMoveNode

	for {
		token := parser.peek()
		if token == nil {
			break
		}

		switch token.Type {
		case "VARIATION_END":
			if !isRoot {
				parser.index++
			}
			return variation, result, nil
		case "RESULT":
			parser.index++
			if isRoot {
				result = token.Value
			} else {
				variation.Result = token.Value
			}
		case "COMMENT":
			parser.index++
			if lastMove != nil {
				lastMove.CommentsAfter = append(lastMove.CommentsAfter, token.Value)
			} else {
				variation.LeadingComments = append(variation.LeadingComments, token.Value)
			}
		case "MOVE_NUMBER":
			parser.index++
		case "NAG":
			parser.index++
			if lastMove != nil {
				lastMove.NAGs = append(lastMove.NAGs, token.Value)
			}
		case "VARIATION_START":
			parser.index++
			anchorFEN := startFEN
			if lastMove != nil {
				anchorFEN = lastMove.PositionBeforeFEN
			}
			child, _, childErr := parser.parseVariation(anchorFEN, false)
			if childErr != nil {
				return nil, "", childErr
			}
			if lastMove != nil {
				lastMove.Variations = append(lastMove.Variations, child)
			}
		case "SAN":
			parser.index++
			rawSAN, inlineNAGs := splitAnnotatedSAN(token.Value)
			beforeFEN := state.ToFEN()
			move, resolveErr := resolveSAN(state, rawSAN)
			if resolveErr != nil {
				return nil, "", fmt.Errorf("illegal PGN move %q: %w", token.Value, resolveErr)
			}

			node := &PgnMoveNode{
				SAN:               moveToSAN(state, move, nil),
				UCI:               strings.ToLower(moveToString(move)),
				MoveNumber:        state.FullmoveNumber,
				Color:             state.ActiveColor,
				PositionBeforeFEN: beforeFEN,
				NAGs:              append([]string{}, inlineNAGs...),
			}
			variation.Moves = append(variation.Moves, node)
			lastMove = node
			state.MakeMove(move)
		default:
			return nil, "", fmt.Errorf("unsupported PGN token: %s", token.Type)
		}
	}

	return variation, result, nil
}

func (parser *PgnParser) tokenize(content string) []pgnToken {
	content = strings.TrimPrefix(content, "\uFEFF")
	tokens := make([]pgnToken, 0)
	length := len(content)

	for i := 0; i < length; {
		char := content[i]

		if unicode.IsSpace(rune(char)) {
			i++
			continue
		}

		switch char {
		case '[':
			token, next := readPgnTagToken(content, i)
			tokens = append(tokens, token)
			i = next
			continue
		case '{':
			end := strings.IndexByte(content[i+1:], '}')
			if end < 0 {
				end = length - i - 1
			}
			value := strings.TrimSpace(content[i+1 : i+1+end])
			tokens = append(tokens, pgnToken{Type: "COMMENT", Value: value})
			i += end + 2
			continue
		case ';':
			end := strings.IndexByte(content[i+1:], '\n')
			if end < 0 {
				end = length - i - 1
			}
			value := strings.TrimSpace(content[i+1 : i+1+end])
			tokens = append(tokens, pgnToken{Type: "COMMENT", Value: value})
			i += end + 1
			continue
		case '(':
			tokens = append(tokens, pgnToken{Type: "VARIATION_START", Value: "("})
			i++
			continue
		case ')':
			tokens = append(tokens, pgnToken{Type: "VARIATION_END", Value: ")"})
			i++
			continue
		case '$':
			j := i + 1
			for j < length && content[j] >= '0' && content[j] <= '9' {
				j++
			}
			tokens = append(tokens, pgnToken{Type: "NAG", Value: content[i:j]})
			i = j
			continue
		}

		j := i
		for j < length && !unicode.IsSpace(rune(content[j])) && !isPgnTokenDelimiter(content[j]) {
			j++
		}

		value := strings.TrimSpace(content[i:j])
		i = j
		if value == "" {
			continue
		}

		switch {
		case isPgnResultToken(value):
			tokens = append(tokens, pgnToken{Type: "RESULT", Value: value})
		case isPgnMoveNumberToken(value):
			tokens = append(tokens, pgnToken{Type: "MOVE_NUMBER", Value: value})
		default:
			tokens = append(tokens, pgnToken{Type: "SAN", Value: value})
		}
	}

	return tokens
}

func readPgnTagToken(content string, start int) (pgnToken, int) {
	i := start + 1
	length := len(content)
	for i < length && unicode.IsSpace(rune(content[i])) {
		i++
	}

	nameStart := i
	for i < length {
		char := content[i]
		if (char >= 'A' && char <= 'Z') || (char >= 'a' && char <= 'z') || (char >= '0' && char <= '9') || char == '_' {
			i++
			continue
		}
		break
	}
	name := content[nameStart:i]

	for i < length && unicode.IsSpace(rune(content[i])) {
		i++
	}

	value := ""
	if i < length && content[i] == '"' {
		i++
		var builder strings.Builder
		for i < length {
			if content[i] == '\\' && i+1 < length {
				builder.WriteByte(content[i+1])
				i += 2
				continue
			}
			if content[i] == '"' {
				i++
				break
			}
			builder.WriteByte(content[i])
			i++
		}
		value = builder.String()
	}

	for i < length && content[i] != ']' {
		i++
	}
	if i < length && content[i] == ']' {
		i++
	}

	return pgnToken{Type: "TAG", Name: name, Value: value}, i
}

func (parser *PgnParser) peek() *pgnToken {
	if parser.index >= len(parser.tokens) {
		return nil
	}
	return &parser.tokens[parser.index]
}

func isPgnTokenDelimiter(char byte) bool {
	return strings.ContainsRune("[]{}();", rune(char))
}

func isPgnResultToken(token string) bool {
	switch token {
	case "1-0", "0-1", "1/2-1/2", "*":
		return true
	default:
		return false
	}
}

func isPgnMoveNumberToken(token string) bool {
	matched, _ := regexp.MatchString(`^\d+\.(?:\.\.)?$`, token)
	if matched {
		return true
	}
	matched, _ = regexp.MatchString(`^\d+\.\.\.$`, token)
	return matched
}

func splitAnnotatedSAN(token string) (string, []string) {
	san := strings.TrimSpace(token)
	nags := make([]string, 0)
	annotationToNAG := map[string]string{
		"!!": "$3",
		"??": "$4",
		"!?": "$5",
		"?!": "$6",
		"!":  "$1",
		"?":  "$2",
	}

	for {
		switched := false
		for _, suffix := range []string{"!!", "??", "!?", "?!", "!", "?"} {
			if strings.HasSuffix(san, suffix) {
				nags = append([]string{annotationToNAG[suffix]}, nags...)
				san = strings.TrimSpace(strings.TrimSuffix(san, suffix))
				switched = true
				break
			}
		}
		if !switched {
			break
		}
	}

	return strings.TrimSpace(san), nags
}

func resolveSAN(state *GameState, san string) (Move, error) {
	legalMoves := state.GenerateLegalMoves()
	target := normalizeSAN(san)
	matches := make([]Move, 0, 2)

	for _, move := range legalMoves {
		candidate := moveToSAN(state, move, legalMoves)
		if normalizeSAN(candidate) == target {
			matches = append(matches, move)
		}
	}

	switch len(matches) {
	case 1:
		return matches[0], nil
	case 0:
		return Move{}, fmt.Errorf("illegal SAN move: %s", san)
	default:
		return Move{}, fmt.Errorf("ambiguous SAN move: %s", san)
	}
}

func moveToSAN(state *GameState, move Move, legalMoves []Move) string {
	if legalMoves == nil {
		legalMoves = state.GenerateLegalMoves()
	}

	piece := state.GetPiece(move.From)
	if piece.IsEmpty() {
		piece = move.Piece
	}

	var san string
	if move.IsCastle {
		if move.To.File > move.From.File {
			san = "O-O"
		} else {
			san = "O-O-O"
		}
	} else {
		destination := move.To.ToAlgebraic()
		isCapture := move.IsEnPassant || move.IsCapture || move.Captured != nil
		if !isCapture {
			target := state.GetPiece(move.To)
			isCapture = !target.IsEmpty() && target.Color != piece.Color
		}

		var builder strings.Builder
		if piece.Type == Pawn {
			if isCapture {
				builder.WriteByte(byte('a' + move.From.File))
			}
		} else {
			builder.WriteString(pieceLetter(piece.Type))
			builder.WriteString(sanDisambiguation(state, move, piece.Type, legalMoves))
		}

		if isCapture {
			builder.WriteByte('x')
		}
		builder.WriteString(destination)
		if move.IsPromotion {
			builder.WriteByte('=')
			builder.WriteString(pieceLetter(move.PromoteTo))
		}
		san = builder.String()
	}

	clone := state.Clone()
	clone.MakeMove(move)
	nextMoves := clone.GenerateLegalMoves()
	if len(nextMoves) == 0 && clone.IsInCheck(clone.ActiveColor) {
		return san + "#"
	}
	if clone.IsInCheck(clone.ActiveColor) {
		return san + "+"
	}
	return san
}

func normalizeSAN(san string) string {
	normalized := strings.TrimSpace(san)
	normalized = strings.ReplaceAll(normalized, "0", "O")
	normalized = strings.TrimSpace(normalized)
	for strings.HasSuffix(normalized, "+") || strings.HasSuffix(normalized, "#") {
		normalized = strings.TrimSpace(normalized[:len(normalized)-1])
	}
	normalized, _ = splitAnnotatedSAN(normalized)
	return strings.TrimSpace(normalized)
}

func pieceLetter(pieceType PieceType) string {
	switch pieceType {
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

func sanDisambiguation(state *GameState, move Move, pieceType PieceType, legalMoves []Move) string {
	candidates := make([]Move, 0)
	for _, candidate := range legalMoves {
		if candidate.To != move.To || candidate.PromoteTo != move.PromoteTo {
			continue
		}
		if candidate.From == move.From && candidate.To == move.To && candidate.IsPromotion == move.IsPromotion {
			continue
		}
		piece := state.GetPiece(candidate.From)
		if piece.Type == pieceType && piece.Color == state.ActiveColor {
			candidates = append(candidates, candidate)
		}
	}

	if len(candidates) == 0 {
		return ""
	}

	shareFile := false
	shareRank := false
	for _, candidate := range candidates {
		if candidate.From.File == move.From.File {
			shareFile = true
		}
		if candidate.From.Rank == move.From.Rank {
			shareRank = true
		}
	}

	file := string(rune('a' + move.From.File))
	rank := string(rune('1' + move.From.Rank))
	if !shareFile {
		return file
	}
	if !shareRank {
		return rank
	}
	return file + rank
}

func newPgnGameState(fen string) (*GameState, error) {
	state := NewGameState()
	if err := state.FromFEN(fen); err != nil {
		return nil, err
	}
	state.MoveHistory = state.MoveHistory[:0]
	state.StateHistory = state.StateHistory[:0]
	state.PositionHistory = state.PositionHistory[:0]
	state.ZobristHash = computeZobristHash(state)
	return state, nil
}

func extractPgnCommentText(command string) (string, bool) {
	if matches := pgnQuotedCommentPattern.FindStringSubmatch(strings.TrimSpace(command)); len(matches) == 2 {
		text := strings.ReplaceAll(matches[1], `\"`, `"`)
		text = strings.ReplaceAll(text, `\\`, "\\")
		return text, true
	}
	if matches := pgnPlainCommentPattern.FindStringSubmatch(strings.TrimSpace(command)); len(matches) == 2 {
		text := strings.TrimSpace(matches[1])
		if text != "" {
			return text, true
		}
	}
	return "", false
}
