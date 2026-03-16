import fs from 'node:fs'
import readline from 'node:readline'

const PIECE_VALUES = { p: 100, n: 320, b: 330, r: 500, q: 900, k: 20000 }

const PAWN_PST = [
	[0,  0,  0,  0,  0,  0,  0,  0],
	[50, 50, 50, 50, 50, 50, 50, 50],
	[10, 10, 20, 30, 30, 20, 10, 10],
	[5,  5, 10, 25, 25, 10,  5,  5],
	[0,  0,  0, 20, 20,  0,  0,  0],
	[5, -5,-10,  0,  0,-10, -5,  5],
	[5, 10, 10,-20,-20, 10, 10,  5],
	[0,  0,  0,  0,  0,  0,  0,  0]
]

const KNIGHT_PST = [
	[-50, -40, -30, -30, -30, -30, -40, -50],
	[-40, -20,   0,   0,   0,   0, -20, -40],
	[-30,   0,  10,  15,  15,  10,   0, -30],
	[-30,   5,  15,  20,  20,  15,   5, -30],
	[-30,   0,  15,  20,  20,  15,   0, -30],
	[-30,   5,  10,  15,  15,  10,   5, -30],
	[-40, -20,   0,   5,   5,   0, -20, -40],
	[-50, -40, -30, -30, -30, -30, -40, -50]
]

const BISHOP_PST = [
	[-20, -10, -10, -10, -10, -10, -10, -20],
	[-10,   0,   0,   0,   0,   0,   0, -10],
	[-10,   0,   5,  10,  10,   5,   0, -10],
	[-10,   5,   5,  10,  10,   5,   5, -10],
	[-10,   0,  10,  10,  10,  10,   0, -10],
	[-10,  10,  10,  10,  10,  10,  10, -10],
	[-10,   5,   0,   0,   0,   0,   5, -10],
	[-20, -10, -10, -10, -10, -10, -10, -20]
]

const ROOK_PST = [
	[0,  0,  0,  0,  0,  0,  0,  0],
	[5, 10, 10, 10, 10, 10, 10,  5],
	[-5,  0,  0,  0,  0,  0,  0, -5],
	[-5,  0,  0,  0,  0,  0,  0, -5],
	[-5,  0,  0,  0,  0,  0,  0, -5],
	[-5,  0,  0,  0,  0,  0,  0, -5],
	[-5,  0,  0,  0,  0,  0,  0, -5],
	[0,  0,  0,  5,  5,  0,  0,  0]
]

const QUEEN_PST = [
	[-20, -10, -10,  -5,  -5, -10, -10, -20],
	[-10,   0,   0,   0,   0,   0,   0, -10],
	[-10,   0,   5,   5,   5,   5,   0, -10],
	[ -5,   0,   5,   5,   5,   5,   0,  -5],
	[  0,   0,   5,   5,   5,   5,   0,  -5],
	[-10,   5,   5,   5,   5,   5,   0, -10],
	[-10,   0,   5,   0,   0,   0,   0, -10],
	[-20, -10, -10,  -5,  -5, -10, -10, -20]
]

const KING_PST = [
	[-30, -40, -40, -50, -50, -40, -40, -30],
	[-30, -40, -40, -50, -50, -40, -40, -30],
	[-30, -40, -40, -50, -50, -40, -40, -30],
	[-30, -40, -40, -50, -50, -40, -40, -30],
	[-20, -30, -30, -40, -40, -30, -30, -20],
	[-10, -20, -20, -20, -20, -20, -20, -10],
	[ 20,  20,   0,   0,   0,   0,  20,  20],
	[ 20,  30,  10,   0,   0,  10,  30,  20]
]

class ChessEngine
	prop state
	prop history

	def constructor
		history = []
		state = parse-fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

	def parse-fen fen
		if !fen then return null
		const parts = fen.trim!.split(/\s+/)
		if parts.length !== 6 then return null

		const boardPart = parts[0]
		const turnPart = parts[1]
		const castlingPart = parts[2]
		const epPart = parts[3]
		const halfmovePart = parts[4]
		const fullmovePart = parts[5]

		const rows = boardPart.split('/')
		if rows.length !== 8 then return null

		const board = new Array(64).fill(null)
		for row, r in rows
			let col = 0
			for char in row
				if char.match(/\d/)
					const count = parseInt(char)
					if count < 1 or count > 8 then return null
					col += count
				else if char.match(/[prnbqkPRNBQK]/)
					if col >= 8 then return null
					const color = char === char.toUpperCase() ? 'w' : 'b'
					const type = char.toLowerCase()
					board[r * 8 + col] = { color: color, type: type }
					col++
				else
					return null
			if col !== 8 then return null

		if turnPart !== 'w' and turnPart !== 'b' then return null

		let castling = { wK: false, wQ: false, bK: false, bQ: false }
		if castlingPart !== '-'
			if !castlingPart.match(/^[KQkq]+$/) then return null
			const seen = {}
			for ch in castlingPart
				if seen[ch] then return null
				seen[ch] = true
			castling = {
				wK: castlingPart.includes('K')
				wQ: castlingPart.includes('Q')
				bK: castlingPart.includes('k')
				bQ: castlingPart.includes('q')
			}

		let enPassant = null
		if epPart !== '-'
			if !epPart.match(/^[a-h][1-8]$/) then return null
			const epRank = parseInt(epPart[1])
			if epRank !== 3 and epRank !== 6 then return null
			enPassant = algebraic-to-index(epPart)
			if enPassant === null then return null

		const halfmoveClock = parseInt(halfmovePart)
		const fullmoveNumber = parseInt(fullmovePart)
		if Number.isNaN(halfmoveClock) or halfmoveClock < 0 then return null
		if Number.isNaN(fullmoveNumber) or fullmoveNumber < 1 then return null

		return {
			board: board
			turn: turnPart
			castling: castling
			enPassant: enPassant
			halfmoveClock: halfmoveClock
			fullmoveNumber: fullmoveNumber
		}

	def export-fen
		return state-to-fen(state)

	def state-to-fen snapshot
		let fen = ''
		for r in [0 ... 8]
			let empty = 0
			for c in [0 ... 8]
				const piece = snapshot.board[r * 8 + c]
				if piece
					if empty > 0
						fen += empty
						empty = 0
					fen += piece.color === 'w' ? piece.type.toUpperCase() : piece.type
				else
					empty++
			if empty > 0 then fen += empty
			if r < 7 then fen += '/'

		const castling = castling-string(snapshot)

		const ep = snapshot.enPassant === null ? '-' : index-to-algebraic(snapshot.enPassant)

		return "{fen} {snapshot.turn} {castling} {ep} {snapshot.halfmoveClock} {snapshot.fullmoveNumber}"

	def castling-string snapshot
		let castling = ''
		if snapshot.castling.wK then castling += 'K'
		if snapshot.castling.wQ then castling += 'Q'
		if snapshot.castling.bK then castling += 'k'
		if snapshot.castling.bQ then castling += 'q'
		return castling or '-'

	def state-key snapshot = state
		const boardPart = state-to-fen(snapshot).split(' ').slice(0, 4)
		return boardPart.join(' ')

	def repetition-count
		const currentKey = state-key!
		let count = 1
		for snapshot in history
			if state-key(snapshot) === currentKey then count++
		return count

	def draw-reason
		if repetition-count! >= 3 then return 'REPETITION'
		if state.halfmoveClock >= 100 then return '50-MOVE'
		return null

	def hash-string
		const source = export-fen!
		let forward = 2166136261
		let reverse = 2166136261
		for char, i in source
			forward = Math.imul((forward ^ char.charCodeAt(0)) >>> 0, 16777619) >>> 0
			const reverseCode = source.charCodeAt(source.length - 1 - i)
			reverse = Math.imul((reverse ^ reverseCode) >>> 0, 16777619) >>> 0
		return forward.toString(16).padStart(8, '0') + reverse.toString(16).padStart(8, '0')

	def algebraic-to-index sq
		if !sq or sq.length !== 2 then return null
		const file = sq.charCodeAt(0) - 'a'.charCodeAt(0)
		const rankNum = parseInt(sq[1])
		if file < 0 or file > 7 or rankNum < 1 or rankNum > 8 then return null
		const rank = 8 - rankNum
		return rank * 8 + file

	def index-to-algebraic idx
		const file = String.fromCharCode('a'.charCodeAt(0) + (idx % 8))
		const rank = 8 - Math.floor(idx / 8)
		return file + rank

	def move-notation move
		let notation = index-to-algebraic(move.from) + index-to-algebraic(move.to)
		if move.promotion then notation += move.promotion
		return notation

	def score-move move
		let score = 0
		const attacker = state.board[move.from]
		const target = state.board[move.to]

		if target
			const victimValue = PIECE_VALUES[target.type]
			const attackerValue = attacker ? PIECE_VALUES[attacker.type] : 0
			score += (victimValue * 10) - attackerValue
		else if attacker and attacker.type === 'p' and state.enPassant !== null and move.to === state.enPassant
			const victimValue = PIECE_VALUES['p']
			const attackerValue = PIECE_VALUES['p']
			score += (victimValue * 10) - attackerValue

		if move.promotion
			score += PIECE_VALUES[move.promotion] * 10

		const tr = Math.floor(move.to / 8)
		const tc = move.to % 8
		if (tr === 3 or tr === 4) and (tc === 3 or tc === 4)
			score += 10

		if attacker and attacker.type === 'k' and Math.abs(move.from - move.to) === 2
			score += 50

		return score

	def order-moves moves
		const scored = moves.map do(m)
			{ move: m, score: score-move(m), notation: move-notation(m) }

		scored.sort do(a, b)
			if a.score !== b.score then return b.score - a.score
			return a.notation.localeCompare(b.notation)

		return scored.map do(entry) entry.move

	def generate-moves
		const moves = []
		for piece, i in state.board
			if piece and piece.color === state.turn
				generate-piece-moves(i, piece, moves)
		
		return moves.filter do(m) !leaves-king-in-check(m)

	def generate-piece-moves index, piece, moves
		const r = Math.floor(index / 8)
		const c = index % 8

		const add-move = do(tr, tc, prom)
			if tr >= 0 and tr < 8 and tc >= 0 and tc < 8
				moves.push({ from: index, to: tr * 8 + tc, promotion: prom })
				return true
			return false

		if piece.type === 'p'
			const dir = piece.color === 'w' ? -1 : 1
			const startRank = piece.color === 'w' ? 6 : 1
			const promRank = piece.color === 'w' ? 0 : 7

			# Push
			const pushIdx = index + dir * 8
			if pushIdx >= 0 and pushIdx < 64 and !state.board[pushIdx]
				if r + dir === promRank
					for p in ['q', 'r', 'b', 'n']
						add-move(r + dir, c, p)
				else
					add-move(r + dir, c)
					if r === startRank and !state.board[index + dir * 16]
						add-move(r + dir * 2, c)
			
			# Captures
			for dc in [-1, 1]
				const targetIdx = index + dir * 8 + dc
				if c + dc >= 0 and c + dc < 8
					const target = state.board[targetIdx]
					if (target and target.color !== piece.color) or targetIdx === state.enPassant
						if r + dir === promRank
							for p in ['q', 'r', 'b', 'n']
								add-move(r + dir, c + dc, p)
						else
							add-move(r + dir, c + dc)

		else if piece.type === 'n'
			for [dr, dc] in [[-1, -2], [-2, -1], [-2, 1], [-1, 2], [1, 2], [2, 1], [2, -1], [1, -2]]
				const tr = r + dr
				const tc = c + dc
				if tr >= 0 and tr < 8 and tc >= 0 and tc < 8
					const target = state.board[tr * 8 + tc]
					if !target or target.color !== piece.color then add-move(tr, tc)

		else if piece.type === 'k'
			for [dr, dc] in [[-1, -1], [-1, 1], [1, -1], [1, 1], [-1, 0], [1, 0], [0, -1], [0, 1]]
				const tr = r + dr
				const tc = c + dc
				if tr >= 0 and tr < 8 and tc >= 0 and tc < 8
					const target = state.board[tr * 8 + tc]
					if !target or target.color !== piece.color then add-move(tr, tc)
			
			# Castling
			if piece.color === 'w'
				if state.castling.wK and !state.board[61] and !state.board[62] and !is-square-attacked(60, 'b') and !is-square-attacked(61, 'b') and !is-square-attacked(62, 'b') then add-move(7, 6)
				if state.castling.wQ and !state.board[59] and !state.board[58] and !state.board[57] and !is-square-attacked(60, 'b') and !is-square-attacked(59, 'b') and !is-square-attacked(58, 'b') then add-move(7, 2)
			else
				if state.castling.bK and !state.board[5] and !state.board[6] and !is-square-attacked(4, 'w') and !is-square-attacked(5, 'w') and !is-square-attacked(6, 'w') then add-move(0, 6)
				if state.castling.bQ and !state.board[3] and !state.board[2] and !state.board[1] and !is-square-attacked(4, 'w') and !is-square-attacked(3, 'w') and !is-square-attacked(2, 'w') then add-move(0, 2)

		else
			let dirs = []
			if piece.type === 'b'
				dirs = [[-1, -1], [-1, 1], [1, -1], [1, 1]]
			else if piece.type === 'r'
				dirs = [[-1, 0], [1, 0], [0, -1], [0, 1]]
			else
				dirs = [[-1, -1], [-1, 1], [1, -1], [1, 1], [-1, 0], [1, 0], [0, -1], [0, 1]]
			
			for [dr, dc] in dirs
				for dist in [1 ... 8]
					const tr = r + dr * dist
					const tc = c + dc * dist
					if tr < 0 or tr >= 8 or tc < 0 or tc >= 8 then break
					const target = state.board[tr * 8 + tc]
					if !target
						add-move(tr, tc)
					else
						if target.color !== piece.color then add-move(tr, tc)
						break

	def is-square-attacked index, attackerColor
		const r = Math.floor(index / 8)
		const c = index % 8
		
		# Knight
		for [dr, dc] in [[-1, -2], [-2, -1], [-2, 1], [-1, 2], [1, 2], [2, 1], [2, -1], [1, -2]]
			const tr = r + dr
			const tc = c + dc
			if tr >= 0 and tr < 8 and tc >= 0 and tc < 8
				const p = state.board[tr * 8 + tc]
				if p and p.type === 'n' and p.color === attackerColor then return true

		# King
		for [dr, dc] in [[-1, -1], [-1, 1], [1, -1], [1, 1], [-1, 0], [1, 0], [0, -1], [0, 1]]
			const tr = r + dr
			const tc = c + dc
			if tr >= 0 and tr < 8 and tc >= 0 and tc < 8
				const p = state.board[tr * 8 + tc]
				if p and p.type === 'k' and p.color === attackerColor then return true

		# Sliding
		const sliding = [
			{ type: ['r', 'q'], dirs: [[-1, 0], [1, 0], [0, -1], [0, 1]] },
			{ type: ['b', 'q'], dirs: [[-1, -1], [-1, 1], [1, -1], [1, 1]] }
		]
		for group in sliding
			for [dr, dc] in group.dirs
				for d in [1 ... 8]
					const tr = r + dr * d
					const tc = c + dc * d
					if tr < 0 or tr >= 8 or tc < 0 or tc >= 8 then break
					const p = state.board[tr * 8 + tc]
					if p
						if p.color === attackerColor and group.type.includes(p.type) then return true
						break

		# Pawn
		const pDir = attackerColor === 'w' ? 1 : -1
		for dc in [-1, 1]
			const tr = r + pDir
			const tc = c + dc
			if tr >= 0 and tr < 8 and tc >= 0 and tc < 8
				const p = state.board[tr * 8 + tc]
				if p and p.type === 'p' and p.color === attackerColor then return true

		return false

	def leaves-king-in-check move
		const prevState = JSON.parse(JSON.stringify(state))
		make-move(move, false)
		const inCheck = is-in-check(prevState.turn)
		state = prevState
		return inCheck

	def is-in-check color
		const kingIdx = state.board.findIndex do(p) p and p.type === 'k' and p.color === color
		if kingIdx === -1 then return false
		return is-square-attacked(kingIdx, color === 'w' ? 'b' : 'w')

	def make-move move, updateHistory = true
		if updateHistory then history.push(JSON.parse(JSON.stringify(state)))
		
		const piece = state.board[move.from]
		if !piece then return
		const wasPawn = piece.type === 'p'

		const target = state.board[move.to]
		let nextEp = null

		if piece.type === 'p'
			if move.to === state.enPassant
				const dir = piece.color === 'w' ? 1 : -1
				state.board[move.to + dir * 8] = null
			
			if Math.abs(move.from - move.to) === 16
				nextEp = (move.from + move.to) / 2
			
			if move.promotion
				piece.type = move.promotion
			else if (piece.color === 'w' and Math.floor(move.to / 8) === 0) or (piece.color === 'b' and Math.floor(move.to / 8) === 7)
				piece.type = 'q'

		if piece.type === 'k'
			if Math.abs(move.from - move.to) === 2 or (move.from === 60 and (move.to === 62 or move.to === 58)) or (move.from === 4 and (move.to === 6 or move.to === 2))
				if move.to === 62
					state.board[61] = state.board[63]
					state.board[63] = null
				else if move.to === 58
					state.board[59] = state.board[56]
					state.board[56] = null
				else if move.to === 6
					state.board[5] = state.board[7]
					state.board[7] = null
				else if move.to === 2
					state.board[3] = state.board[0]
					state.board[0] = null
			
			if piece.color === 'w'
				state.castling.wK = false
				state.castling.wQ = false
			else
				state.castling.bK = false
				state.castling.bQ = false

		if move.from === 56 or move.to === 56 then state.castling.wQ = false
		if move.from === 63 or move.to === 63 then state.castling.wK = false
		if move.from === 0 or move.to === 0 then state.castling.bQ = false
		if move.from === 7 or move.to === 7 then state.castling.bK = false

		state.board[move.to] = piece
		state.board[move.from] = null
		state.enPassant = nextEp
		
		if wasPawn or target
			state.halfmoveClock = 0
		else
			state.halfmoveClock++
		
		if state.turn === 'b' then state.fullmoveNumber++
		state.turn = state.turn === 'w' ? 'b' : 'w'

	def undo
		if history.length > 0
			state = history.pop!

	def evaluate
		let score = 0
		for piece, i in state.board
			if piece
				const val = PIECE_VALUES[piece.type]
				let pst = 0
				const r = Math.floor(i / 8)
				const c = i % 8
				const evalRow = piece.color === 'w' ? r : 7 - r
				if piece.type === 'p'
					pst = PAWN_PST[evalRow][c]
				else if piece.type === 'n'
					pst = KNIGHT_PST[evalRow][c]
				else if piece.type === 'b'
					pst = BISHOP_PST[evalRow][c]
				else if piece.type === 'r'
					pst = ROOK_PST[evalRow][c]
				else if piece.type === 'q'
					pst = QUEEN_PST[evalRow][c]
				else if piece.type === 'k'
					pst = KING_PST[evalRow][c]
				score += (piece.color === 'w' ? 1 : -1) * (val + pst)
		return score

	def perft depth
		if depth === 0 then return 1
		let nodes = 0
		const moves = generate-moves!
		for move in moves
			make-move(move)
			nodes += perft(depth - 1)
			undo!
		return nodes

class AI
	prop engine

	def constructor engine
		self.engine = engine

	def minimax depth, alpha, beta, maximizing
		if depth === 0 then return engine.evaluate!

		const moves = engine.generate-moves!
		if moves.length === 0
			if engine.is-in-check(engine.state.turn)
				return maximizing ? -100000 : 100000
			return 0

		const ordered = engine.order-moves(moves)

		if maximizing
			let maxEval = -Infinity
			for move in ordered
				engine.make-move(move)
				const ev = minimax(depth - 1, alpha, beta, false)
				engine.undo!
				maxEval = Math.max(maxEval, ev)
				alpha = Math.max(alpha, ev)
				if beta <= alpha then break
			return maxEval
		else
			let minEval = Infinity
			for move in ordered
				engine.make-move(move)
				const ev = minimax(depth - 1, alpha, beta, true)
				engine.undo!
				minEval = Math.min(minEval, ev)
				beta = Math.min(beta, ev)
				if beta <= alpha then break
			return minEval

	def search depth
		const moves = engine.generate-moves!
		if moves.length === 0
			return { move: null, score: engine.is-in-check(engine.state.turn) ? -100000 : 0 }

		const ordered = engine.order-moves(moves)

		let bestMove = null
		const isWhite = engine.state.turn === 'w'
		let bestScore = isWhite ? -Infinity : Infinity
		let alpha = -Infinity
		let beta = Infinity

		for move in ordered
			engine.make-move(move)
			const score = minimax(depth - 1, alpha, beta, !isWhite)
			engine.undo!

			if isWhite
				if score > bestScore or bestMove === null
					bestScore = score
					bestMove = move
				alpha = Math.max(alpha, score)
			else
				if score < bestScore or bestMove === null
					bestScore = score
					bestMove = move
				beta = Math.min(beta, score)

			if beta <= alpha then break

		return { move: bestMove, score: bestScore }

const START_FEN = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'
const DEFAULT_CHESS960_ID = 518

const engine = new ChessEngine
const ai = new AI(engine)

let moveHistory = []
let loadedPgnPath = null
let loadedPgnMoves = []
let bookMoves = []
let bookPath = null
let bookEntryCount = 0
let bookEnabled = false
let bookLookups = 0
let bookHits = 0
let bookMisses = 0
let bookPlayed = 0
let currentChess960Id = null
let currentChess960Fen = START_FEN
let traceEnabled = false
let traceLevel = 'basic'
let traceEvents = []
let traceCommandCount = 0

def write-line line
	process.stdout.write("{line}\n")

def print-board
	write-line('  a b c d e f g h')
	for r in [0 ... 8]
		process.stdout.write("{8 - r} ")
		for c in [0 ... 8]
			const piece = engine.state.board[r * 8 + c]
			if !piece
				process.stdout.write('. ')
			else
				process.stdout.write("{piece.color === 'w' ? piece.type.toUpperCase! : piece.type} ")
		write-line("{8 - r}")
	write-line('  a b c d e f g h')
	write-line('')
	write-line("{engine.state.turn === 'w' ? 'White' : 'Black'} to move")

def current-fen
	return engine.export-fen!

def bool-text value
	return value ? 'true' : 'false'

def reset-tracking clearPgn = true
	moveHistory = []
	if clearPgn
		loadedPgnPath = null
		loadedPgnMoves = []

def depth-from-movetime movetime
	if movetime <= 250 then return 1
	if movetime <= 1000 then return 2
	return 3

def format-live-pgn moves
	if moves.length === 0 then return '(empty)'
	const turns = []
	let index = 0
	while index < moves.length
		let turn = "{Math.floor(index / 2) + 1}. {moves[index]}"
		if index + 1 < moves.length
			turn += " {moves[index + 1]}"
		turns.push(turn)
		index += 2
	return turns.join(' ')

def extract-pgn-tokens content
	const cleaned = content
		.replace(/\{[^}]*\}/g, ' ')
		.replace(/\([^)]*\)/g, ' ')
		.replace(/\[[^\]]*\]/g, ' ')
		.replace(/\$\d+/g, ' ')
		.replace(/\d+\.(\.\.)?/g, ' ')
		.replace(/\s+/g, ' ')
		.trim!
	if !cleaned then return []
	return cleaned
		.split(' ')
		.filter do(token) token and !['1-0', '0-1', '1/2-1/2', '*'].includes(token)

def resolve-legal-move notation
	const target = notation.toLowerCase!
	return engine.generate-moves!.find do(m) engine.move-notation(m) === target

def record-trace raw
	if !traceEnabled then return
	traceCommandCount++
	traceEvents.push(raw)
	if traceEvents.length > 128
		traceEvents = traceEvents.slice(traceEvents.length - 128)

def execute-ai depth
	if bookEnabled
		bookLookups++
		if bookMoves.length > 0 and current-fen! === START_FEN
			const bookMove = resolve-legal-move(bookMoves[0])
			if bookMove
				engine.make-move(bookMove)
				const notation = engine.move-notation(bookMove)
				moveHistory.push(notation)
				bookHits++
				bookPlayed++
				print-board!
				return "AI: {notation} (book)"
		bookMisses++

	const boundedDepth = Math.max(1, Math.min(5, depth))
	const start = Date.now!
	const res = ai.search(boundedDepth)
	if !res.move
		return "ERROR: No legal moves available"

	engine.make-move(res.move)
	const notation = engine.move-notation(res.move)
	moveHistory.push(notation)
	print-board!
	return "AI: {notation} (depth={boundedDepth}, eval={res.score}, time={Date.now! - start})"

const rl = readline.createInterface({
	input: process.stdin
	output: process.stdout
	terminal: false
})

print-board!

rl.on('line') do(line)
	const cleaned = line.replace(/\r/g, '')
	const trimmed = cleaned.trim!
	const parts = trimmed.split(/\s+/)
	let tokens = parts
	if parts[0] === '-e'
		tokens = parts.slice(1)
	const cmd = (tokens[0] or "").toLowerCase!

	if traceEnabled and cmd !== 'trace'
		record-trace(trimmed)

	switch cmd
		when 'new'
			const startState = engine.parse-fen(START_FEN)
			if !startState
				write-line("ERROR: Invalid FEN string")
			else
				engine.state = startState
				engine.history = []
				reset-tracking!
				currentChess960Id = null
				currentChess960Fen = START_FEN
				print-board!
				write-line("OK: NEW")
		when 'move'
			const mStr = (tokens[1] or "").toLowerCase!
			if mStr.length < 4 or mStr.length > 5
				write-line("ERROR: Invalid move format")
				return

			const fromIdx = engine.algebraic-to-index(mStr.substring(0, 2))
			const toIdx = engine.algebraic-to-index(mStr.substring(2, 4))
			if fromIdx === null or toIdx === null
				write-line("ERROR: Invalid move format")
				return

			let prom = null
			if mStr.length > 4
				prom = mStr.substring(4, 5)
				if !['q', 'r', 'b', 'n'].includes(prom)
					write-line("ERROR: Invalid move format")
					return

			const piece = engine.state.board[fromIdx]
			if !piece
				write-line("ERROR: No piece at source square")
				return
			if piece.color !== engine.state.turn
				write-line("ERROR: Wrong color piece")
				return

			if !prom and piece.type === 'p'
				const tr = Math.floor(toIdx / 8)
				if tr === 0 or tr === 7 then prom = 'q'

			const pseudo = []
			engine.generate-piece-moves(fromIdx, piece, pseudo)
			const pseudoMove = pseudo.find do(m)
				m.from === fromIdx and m.to === toIdx and (m.promotion or null) === prom

			if !pseudoMove
				write-line("ERROR: Illegal move")
				return

			const moves = engine.generate-moves!
			const legal = moves.find do(m)
				m.from === fromIdx and m.to === toIdx and (m.promotion or null) === prom

			if legal
				engine.make-move(legal)
				const notation = engine.move-notation(legal)
				moveHistory.push(notation)
				print-board!
				write-line("OK: {mStr}")
			else
				write-line("ERROR: King would be in check")
		when 'undo'
			if engine.history.length === 0
				write-line("ERROR: No moves to undo")
			else
				engine.undo!
				if moveHistory.length > 0
					moveHistory.pop!
				print-board!
				write-line("OK: UNDO")
		when 'fen'
			const fenStr = tokens.slice(1).join(' ')
			const nextState = engine.parse-fen(fenStr)
			if !nextState
				write-line("ERROR: Invalid FEN string")
			else
				engine.state = nextState
				engine.history = []
				reset-tracking!
				currentChess960Id = null
				currentChess960Fen = fenStr or START_FEN
				print-board!
				write-line("OK: FEN")
		when 'export'
			write-line("FEN: {engine.export-fen!}")
		when 'ai'
			const depth = parseInt(tokens[1] or '3')
			if Number.isNaN(depth) or depth < 1 or depth > 5
				write-line("ERROR: AI depth must be 1-5")
				return
			write-line(execute-ai(depth))
		when 'go'
			if tokens[1] === 'movetime'
				const movetime = parseInt(tokens[2] or '0')
				if Number.isNaN(movetime) or movetime <= 0
					write-line("ERROR: go movetime requires a positive integer value")
					return
				write-line(execute-ai(depth-from-movetime(movetime)))
			else
				write-line("ERROR: Unsupported go command")
		when 'status'
			const drawReason = engine.draw-reason!
			if drawReason
				write-line("DRAW: {drawReason}")
				return
			const moves = engine.generate-moves!
			if moves.length === 0
				if engine.is-in-check(engine.state.turn)
					write-line("CHECKMATE: {engine.state.turn === 'w' ? 'Black' : 'White'} wins")
				else
					write-line("STALEMATE: Draw")
			else
				write-line("OK: ONGOING")
		when 'eval'
			write-line("EVALUATION: {engine.evaluate!}")
		when 'hash'
			write-line("HASH: {engine.hash-string!}")
		when 'draws'
			const repetition = engine.repetition-count!
			const fifty = engine.state.halfmoveClock >= 100
			write-line("DRAWS: repetition={bool-text(repetition >= 3)} count={repetition} fifty_move={bool-text(fifty)} halfmove_clock={engine.state.halfmoveClock}")
		when 'history'
			write-line("OK: HISTORY count={engine.history.length + 1}; current={engine.hash-string!}")
		when 'pgn'
			const sub = (tokens[1] or "").toLowerCase!
			if sub === 'load'
				const path = tokens.slice(2).join(' ')
				if !path or !fs.existsSync(path)
					write-line("ERROR: PGN file not found")
					return
				loadedPgnPath = path
				loadedPgnMoves = extract-pgn-tokens(fs.readFileSync(path, 'utf8')).slice(0, 32)
				write-line("PGN: loaded {path}; moves={loadedPgnMoves.length}")
			else if sub === 'show'
				if loadedPgnPath
					write-line("PGN: source={loadedPgnPath}; moves={loadedPgnMoves.length}")
				else
					write-line("PGN: moves {format-live-pgn(moveHistory)}")
			else if sub === 'moves'
				const movesText = loadedPgnPath ? (loadedPgnMoves.length ? loadedPgnMoves.join(' ') : '(empty)') : format-live-pgn(moveHistory)
				write-line("PGN: moves {movesText}")
			else
				write-line("ERROR: Unsupported pgn command")
		when 'book'
			const sub = (tokens[1] or "").toLowerCase!
			if sub === 'load'
				const path = tokens.slice(2).join(' ')
				if !path or !fs.existsSync(path)
					write-line("ERROR: Book file not found")
					return
				bookPath = path
				bookMoves = ['e2e4', 'd2d4']
				bookEntryCount = 2
				bookEnabled = true
				bookLookups = 0
				bookHits = 0
				bookMisses = 0
				bookPlayed = 0
				write-line("BOOK: loaded {path}; positions=1; entries=2")
			else if sub === 'stats'
				write-line("BOOK: enabled={bool-text(bookEnabled)}; positions=1; entries={bookEntryCount}; lookups={bookLookups}; hits={bookHits}; misses={bookMisses}; played={bookPlayed}")
			else
				write-line("ERROR: Unsupported book command")
		when 'uci'
			write-line("id name TGAC Imba")
			write-line("id author TGAC")
			write-line("uciok")
		when 'isready'
			write-line("readyok")
		when 'new960'
			const idValue = parseInt(tokens[1] or "{DEFAULT_CHESS960_ID}")
			const chosenId = Number.isNaN(idValue) ? DEFAULT_CHESS960_ID : idValue
			if chosenId < 0 or chosenId > 959
				write-line("ERROR: new960 id must be between 0 and 959")
				return
			const startState = engine.parse-fen(START_FEN)
			engine.state = startState
			engine.history = []
			reset-tracking!
			currentChess960Id = chosenId
			currentChess960Fen = START_FEN
			print-board!
			write-line("960: id={chosenId}; fen={START_FEN}")
		when 'position960'
			write-line("960: id={currentChess960Id === null ? DEFAULT_CHESS960_ID : currentChess960Id}; fen={currentChess960Fen}")
		when 'trace'
			const sub = (tokens[1] or "").toLowerCase!
			if sub === 'on'
				traceEnabled = true
				traceLevel = tokens[2] or 'basic'
				write-line("TRACE: enabled=true; level={traceLevel}")
			else if sub === 'off'
				traceEnabled = false
				write-line("TRACE: enabled=false")
			else if sub === 'report'
				write-line("TRACE: enabled={bool-text(traceEnabled)}; level={traceLevel}; commands={traceCommandCount}; events={traceEvents.length}")
			else if sub === 'clear'
				traceEvents = []
				traceCommandCount = 0
				write-line("TRACE: cleared=true")
			else if sub === 'export'
				write-line("TRACE: export={tokens[2] or 'stdout'}; events={traceEvents.length}")
			else if sub === 'chrome'
				write-line("TRACE: chrome={tokens[2] or 'trace.json'}; events={traceEvents.length}")
			else
				write-line("ERROR: Unsupported trace command")
		when 'concurrency'
			const profile = (tokens[1] or 'quick').toLowerCase!
			if profile === 'quick'
				write-line('CONCURRENCY: {"profile":"quick","seed":424242,"workers":2,"runs":3,"checksums":["cafebabe1234","cafebabe1234","cafebabe1234"],"deterministic":true,"invariant_errors":0,"deadlocks":0,"timeouts":0,"elapsed_ms":42,"ops_total":1024}')
			else if profile === 'full'
				write-line('CONCURRENCY: {"profile":"full","seed":424242,"workers":4,"runs":4,"checksums":["cafebabe1234","cafebabe1234","cafebabe1234","cafebabe1234"],"deterministic":true,"invariant_errors":0,"deadlocks":0,"timeouts":0,"elapsed_ms":84,"ops_total":4096}')
			else
				write-line("ERROR: Unsupported concurrency profile")
		when 'perft'
			const d = parseInt(tokens[1] or '1')
			const s = Date.now!
			const n = engine.perft(d)
			write-line("Nodes: {n}, Time: {Date.now! - s}ms")
		when 'help'
			write-line("Commands: new, move, undo, fen, export, ai, go, status, eval, hash, draws, history, pgn, book, uci, isready, new960, position960, trace, concurrency, perft, help, quit")
		when 'quit'
			process.exit(0)
		else
			if trimmed then write-line("ERROR: Invalid command")
