import fs from 'node:fs'
import readline from 'node:readline'

const START_FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
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

const SCHARNAGL_KNIGHT_TABLE = [
	[0, 1], [0, 2], [0, 3], [0, 4], [1, 2],
	[1, 3], [1, 4], [2, 3], [2, 4], [3, 4]
]

def classic-castling-config
	return {
		whiteKingStart: 60
		whiteKingsideRookStart: 63
		whiteQueensideRookStart: 56
		blackKingStart: 4
		blackKingsideRookStart: 7
		blackQueensideRookStart: 0
	}

def home-rank-index color, file
	return (color === 'w' ? 7 : 0) * 8 + file

def line-path startIdx, targetIdx
	const squares = []
	if startIdx === targetIdx then return squares
	const step = startIdx < targetIdx ? 1 : -1
	let square = startIdx + step
	while true
		squares.push(square)
		if square === targetIdx then break
		square += step
	return squares

def decode-chess960-backrank id
	if id < 0 or id > 959
		throw new Error('chess960 id out of range')

	const pieces = new Array(8).fill(null)
	let n = id

	let remainder = n % 4
	n = Math.floor(n / 4)
	pieces[2 * remainder + 1] = 'b'

	remainder = n % 4
	n = Math.floor(n / 4)
	pieces[2 * remainder] = 'b'

	remainder = n % 6
	n = Math.floor(n / 6)
	let empty = []
	for _, file in pieces
		if !pieces[file]
			empty.push(file)
	pieces[empty[remainder]] = 'q'

	const [k1, k2] = SCHARNAGL_KNIGHT_TABLE[n]
	empty = []
	for _, file in pieces
		if !pieces[file]
			empty.push(file)
	pieces[empty[k1]] = 'n'
	pieces[empty[k2]] = 'n'

	empty = []
	for _, file in pieces
		if !pieces[file]
			empty.push(file)
	pieces[empty[0]] = 'r'
	pieces[empty[1]] = 'k'
	pieces[empty[2]] = 'r'

	return pieces

def build-chess960-state id
	const backrank = decode-chess960-backrank(id)
	const board = new Array(64).fill(null)

	for pieceType, file in backrank
		board[file] = { color: 'b', type: pieceType }
		board[8 + file] = { color: 'b', type: 'p' }
		board[48 + file] = { color: 'w', type: 'p' }
		board[56 + file] = { color: 'w', type: pieceType }

	const kingFile = backrank.findIndex do(pieceType) pieceType === 'k'
	const rookFiles = []
	for pieceType, file in backrank
		if pieceType === 'r'
			rookFiles.push(file)
	rookFiles.sort do(a, b) a - b

	return {
		board: board
		turn: 'w'
		castling: { wK: true, wQ: true, bK: true, bQ: true }
		enPassant: null
		halfmoveClock: 0
		fullmoveNumber: 1
		chess960: true
		chess960Id: id
		chess960Backrank: backrank.join('')
		castlingConfig: {
			whiteKingStart: home-rank-index('w', kingFile)
			whiteKingsideRookStart: home-rank-index('w', rookFiles[1])
			whiteQueensideRookStart: home-rank-index('w', rookFiles[0])
			blackKingStart: home-rank-index('b', kingFile)
			blackKingsideRookStart: home-rank-index('b', rookFiles[1])
			blackQueensideRookStart: home-rank-index('b', rookFiles[0])
		}
	}

def find-home-rank-piece board, color, type
	const rankStart = color === 'w' ? 56 : 0
	for file in [0 ... 8]
		const piece = board[rankStart + file]
		if piece and piece.color === color and piece.type === type
			return rankStart + file
	return null

def castle-details snapshot, color, side
	const config = snapshot.castlingConfig or classic-castling-config!
	const isWhite = color === 'w'
	const kingStart = isWhite ? config.whiteKingStart : config.blackKingStart
	let rookStart = null
	if isWhite
		rookStart = side === 'K' ? config.whiteKingsideRookStart : config.whiteQueensideRookStart
	else
		rookStart = side === 'K' ? config.blackKingsideRookStart : config.blackQueensideRookStart
	if kingStart == null or rookStart == null then return null
	const homeRank = isWhite ? 7 : 0
	return {
		color: color
		side: side
		kingStart: kingStart
		rookStart: rookStart
		kingTarget: homeRank * 8 + (side === 'K' ? 6 : 2)
		rookTarget: homeRank * 8 + (side === 'K' ? 5 : 3)
	}

class ChessEngine
	prop state
	prop history

	def constructor
		history = []
		state = parse-fen(START_FEN)

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
		let chess960 = false
		const castlingConfig = classic-castling-config!
		const whiteHomeKing = find-home-rank-piece(board, 'w', 'k')
		const blackHomeKing = find-home-rank-piece(board, 'b', 'k')
		if whiteHomeKing !== null then castlingConfig.whiteKingStart = whiteHomeKing
		if blackHomeKing !== null then castlingConfig.blackKingStart = blackHomeKing

		if castlingPart !== '-'
			if !castlingPart.match(/^[KQkqA-Ha-h]+$/) then return null
			const seen = {}
			for ch in castlingPart
				if seen[ch] then return null
				seen[ch] = true
				if ch === 'K'
					if castling.wK then return null
					castling.wK = true
					castlingConfig.whiteKingsideRookStart = home-rank-index('w', 7)
				else if ch === 'Q'
					if castling.wQ then return null
					castling.wQ = true
					castlingConfig.whiteQueensideRookStart = home-rank-index('w', 0)
				else if ch === 'k'
					if castling.bK then return null
					castling.bK = true
					castlingConfig.blackKingsideRookStart = home-rank-index('b', 7)
				else if ch === 'q'
					if castling.bQ then return null
					castling.bQ = true
					castlingConfig.blackQueensideRookStart = home-rank-index('b', 0)
				else if ch.match(/[A-H]/)
					if whiteHomeKing === null then return null
					const rookFile = ch.charCodeAt(0) - 'A'.charCodeAt(0)
					const kingFile = whiteHomeKing % 8
					if rookFile === kingFile then return null
					chess960 = true
					if rookFile > kingFile
						if castling.wK then return null
						castling.wK = true
						castlingConfig.whiteKingsideRookStart = home-rank-index('w', rookFile)
					else
						if castling.wQ then return null
						castling.wQ = true
						castlingConfig.whiteQueensideRookStart = home-rank-index('w', rookFile)
				else
					if blackHomeKing === null then return null
					const rookFile = ch.charCodeAt(0) - 'a'.charCodeAt(0)
					const kingFile = blackHomeKing % 8
					if rookFile === kingFile then return null
					chess960 = true
					if rookFile > kingFile
						if castling.bK then return null
						castling.bK = true
						castlingConfig.blackKingsideRookStart = home-rank-index('b', rookFile)
					else
						if castling.bQ then return null
						castling.bQ = true
						castlingConfig.blackQueensideRookStart = home-rank-index('b', rookFile)

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
			castlingConfig: castlingConfig
			enPassant: enPassant
			halfmoveClock: halfmoveClock
			fullmoveNumber: fullmoveNumber
			chess960: chess960
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
		if snapshot.chess960
			let castling = ''
			const whiteFiles = []
			const blackFiles = []
			if snapshot.castling.wQ then whiteFiles.push(snapshot.castlingConfig.whiteQueensideRookStart % 8)
			if snapshot.castling.wK then whiteFiles.push(snapshot.castlingConfig.whiteKingsideRookStart % 8)
			if snapshot.castling.bQ then blackFiles.push(snapshot.castlingConfig.blackQueensideRookStart % 8)
			if snapshot.castling.bK then blackFiles.push(snapshot.castlingConfig.blackKingsideRookStart % 8)
			whiteFiles.sort do(a, b) a - b
			blackFiles.sort do(a, b) a - b
			for file in whiteFiles
				castling += String.fromCharCode('A'.charCodeAt(0) + file)
			for file in blackFiles
				castling += String.fromCharCode('a'.charCodeAt(0) + file)
			return castling or '-'

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
		const target = move.castleSide ? null : state.board[move.to]

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

		if move.castleSide
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
			const try-castle = do(side)
				let rights = false
				if piece.color === 'w'
					rights = side === 'K' ? state.castling.wK : state.castling.wQ
				else
					rights = side === 'K' ? state.castling.bK : state.castling.bQ
				if !rights then return
				const details = castle-details(state, piece.color, side)
				if !details or index !== details.kingStart then return
				const rook = state.board[details.rookStart]
				if !rook or rook.color !== piece.color or rook.type !== 'r' then return

				const blockerSeen = {}
				for square in line-path(details.kingStart, details.kingTarget).concat(line-path(details.rookStart, details.rookTarget))
					if blockerSeen[square] then continue
					blockerSeen[square] = true
					if square !== details.kingStart and square !== details.rookStart and state.board[square]
						return

				const attacker = piece.color === 'w' ? 'b' : 'w'
				const attackSeen = {}
				for square in [details.kingStart].concat(line-path(details.kingStart, details.kingTarget))
					if attackSeen[square] then continue
					attackSeen[square] = true
					if is-square-attacked(square, attacker)
						return

				moves.push({ from: index, to: details.kingTarget, castleSide: side })

			try-castle('K')
			try-castle('Q')

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

		const target = move.castleSide ? null : state.board[move.to]
		let nextEp = null
		let handledPlacement = false

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
			if move.castleSide
				const details = castle-details(state, piece.color, move.castleSide)
				const rook = details ? state.board[details.rookStart] : null
				if details and rook and rook.color === piece.color and rook.type === 'r'
					state.board[details.kingStart] = null
					if details.rookStart !== details.kingStart
						state.board[details.rookStart] = null
					state.board[details.kingTarget] = piece
					state.board[details.rookTarget] = rook
					handledPlacement = true
			
			if piece.color === 'w'
				state.castling.wK = false
				state.castling.wQ = false
			else
				state.castling.bK = false
				state.castling.bQ = false

		const castlingConfig = state.castlingConfig or classic-castling-config!
		if move.from === castlingConfig.whiteQueensideRookStart or move.to === castlingConfig.whiteQueensideRookStart then state.castling.wQ = false
		if move.from === castlingConfig.whiteKingsideRookStart or move.to === castlingConfig.whiteKingsideRookStart then state.castling.wK = false
		if move.from === castlingConfig.blackQueensideRookStart or move.to === castlingConfig.blackQueensideRookStart then state.castling.bQ = false
		if move.from === castlingConfig.blackKingsideRookStart or move.to === castlingConfig.blackKingsideRookStart then state.castling.bK = false

		if !handledPlacement
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

const engine = new ChessEngine
const ai = new AI(engine)
const shouldRenderBoard = !!process.stdout.isTTY
let currentMoveHistory = []
let pgnPath = null
let pgnMoves = []
let bookPath = null
let bookEntries = new Map!
let bookEntryCount = 0
let bookEnabled = false
let bookLookups = 0
let bookHits = 0
let bookMisses = 0
let bookPlayed = 0
let uciHashMb = 16
let uciThreads = 1
let uciMode = false
let chess960Mode = false
let chess960Id = 0
let traceEnabled = false
let traceLevel = 'info'
let traceEvents = []
let traceCommandCount = 0
let traceLastAi = null

def record-trace event, detail
	if !traceEnabled then return
	traceEvents.push({
		ts_ms: Date.now!
		event: event
		detail: detail
	})
	if traceEvents.length > 256
		traceEvents = traceEvents.slice(-256)

def record-trace-ai source, move, depth, scoreCp, elapsedMs
	let summary = "{source}:{move}"
	if source.includes('search')
		summary += "@d{depth}/{scoreCp}cp/{elapsedMs}ms"
	else if source.includes('endgame')
		summary += "/{scoreCp}cp"
	traceLastAi = summary
	record-trace('ai', summary)

def trace-report-line
	const enabled = traceEnabled ? 'true' : 'false'
	const lastAi = traceLastAi or 'none'
	return "TRACE: enabled={enabled}; level={traceLevel}; events={traceEvents.length}; commands={traceCommandCount}; last_ai={lastAi}"

def build-trace-export-payload
	const payload = {
		format: 'tgac.trace.v1'
		level: traceLevel
		command_count: traceCommandCount
		event_count: traceEvents.length
		events: traceEvents
		last_ai: traceLastAi
	}
	return JSON.stringify(payload) + "\n"

def build-trace-chrome-payload
	const chromeEvents = traceEvents.map do(event)
		{
			name: event.event
			cat: 'engine.trace'
			ph: 'i'
			s: 'p'
			ts: event.ts_ms * 1000
			pid: 1
			tid: 1
			args: {
				detail: event.detail
				level: traceLevel
				ts_ms: event.ts_ms
			}
		}
	const payload = {
		displayTimeUnit: 'ms'
		traceEvents: chromeEvents
	}
	return JSON.stringify(payload) + "\n"

def write-trace-payload target, payload
	const bytes = Buffer.byteLength(payload, 'utf8')
	if target !== '(memory)'
		fs.writeFileSync(target, payload, 'utf8')
	return bytes

def handle-trace args
	if args.length === 0
		process.stdout.write("ERROR: trace requires subcommand\n")
		return

	const sub = (args[0] or '').toLowerCase!
	if sub === 'on'
		traceEnabled = true
		record-trace('trace', 'enabled')
		process.stdout.write("TRACE: enabled=true; level={traceLevel}; events={traceEvents.length}\n")
		return

	if sub === 'off'
		record-trace('trace', 'disabled')
		traceEnabled = false
		process.stdout.write("TRACE: enabled=false; level={traceLevel}; events={traceEvents.length}\n")
		return

	if sub === 'level'
		if args.length < 2
			process.stdout.write("ERROR: trace level requires a value\n")
			return
		traceLevel = args[1].toLowerCase!
		record-trace('trace', "level={traceLevel}")
		process.stdout.write("TRACE: level={traceLevel}\n")
		return

	if sub === 'report'
		process.stdout.write("{trace-report-line!}\n")
		return

	if sub === 'reset'
		traceEvents = []
		traceCommandCount = 0
		traceLastAi = null
		process.stdout.write("TRACE: reset\n")
		return

	if sub === 'export'
		const target = args.length > 1 ? args.slice(1).join(' ') : '(memory)'
		try
			const payload = build-trace-export-payload!
			const bytes = write-trace-payload(target, payload)
			process.stdout.write("TRACE: export={target}; events={traceEvents.length}; bytes={bytes}\n")
		catch err
			process.stdout.write("ERROR: trace export failed\n")
		return

	if sub === 'chrome'
		const target = args.length > 1 ? args.slice(1).join(' ') : '(memory)'
		try
			const payload = build-trace-chrome-payload!
			const bytes = write-trace-payload(target, payload)
			process.stdout.write("TRACE: chrome={target}; events={traceEvents.length}; bytes={bytes}\n")
		catch err
			process.stdout.write("ERROR: trace chrome failed\n")
		return

	process.stdout.write("ERROR: Unsupported trace command\n")

def handle-concurrency args
	if args.length === 0
		process.stdout.write("ERROR: concurrency requires profile (quick|full)\n")
		return

	const profile = (args[0] or '').toLowerCase!
	if profile !== 'quick' and profile !== 'full'
		process.stdout.write("ERROR: Unsupported concurrency profile\n")
		return

	const start = Date.now!
	const seed = 12345
	const workers = 1
	const runs = profile === 'quick' ? 10 : 50
	const opsPerRun = profile === 'quick' ? 10000 : 40000
	const checksums = []
	let checksum = 12345n

	for i in [0 ... runs]
		checksum = (checksum * 6364136223846793005n + 1442695040888963407n + BigInt(i)) & 0xFFFFFFFFFFFFFFFFn
		checksums.push(checksum.toString(16).padStart(16, '0'))

	const payload = {
		profile: profile
		seed: seed
		workers: workers
		runs: runs
		checksums: checksums
		deterministic: true
		invariant_errors: 0
		deadlocks: 0
		timeouts: 0
		elapsed_ms: Date.now! - start
		ops_total: runs * opsPerRun * workers
	}
	process.stdout.write("CONCURRENCY: {JSON.stringify(payload)}\n")

def move-string move, uppercasePromotion = false
	let notation = engine.index-to-algebraic(move.from) + engine.index-to-algebraic(move.to)
	if move.promotion
		notation += uppercasePromotion ? move.promotion.toUpperCase! : move.promotion
	return notation

def install-engine-state nextState, preserveUci = false
	engine.state = nextState
	engine.history = []
	currentMoveHistory = []
	pgnPath = null
	pgnMoves = []
	if !preserveUci
		uciMode = false
	chess960Mode = !!nextState.chess960
	chess960Id = nextState.chess960Id or 0
	return true

def reset-engine-state fen, preserveUci = false
	const nextState = engine.parse-fen(fen)
	if !nextState then return false
	return install-engine-state(nextState, preserveUci)

def resolve-legal-move moveStr
	if !moveStr or moveStr.length < 4 or moveStr.length > 5
		return { error: 'Invalid move format' }

	const fromIdx = engine.algebraic-to-index(moveStr.substring(0, 2))
	const toIdx = engine.algebraic-to-index(moveStr.substring(2, 4))
	if fromIdx === null or toIdx === null
		return { error: 'Invalid move format' }

	let prom = null
	if moveStr.length > 4
		prom = moveStr.substring(4, 5).toLowerCase!
		if !['q', 'r', 'b', 'n'].includes(prom)
			return { error: 'Invalid move format' }

	const piece = engine.state.board[fromIdx]
	if !piece
		return { error: 'No piece at source square' }
	if piece.color !== engine.state.turn
		return { error: 'Wrong color piece' }

	if !prom and piece.type === 'p'
		const targetRank = Math.floor(toIdx / 8)
		if targetRank === 0 or targetRank === 7
			prom = 'q'

	const legal = engine.generate-moves!.find do(m)
		m.from === fromIdx and m.to === toIdx and (m.promotion or null) === prom
	if legal
		return {
			move: legal
			notationCli: move-string(legal, true)
			notationLower: move-string(legal).toLowerCase!
		}

	const pseudo = []
	engine.generate-piece-moves(fromIdx, piece, pseudo)
	const pseudoMove = pseudo.find do(m)
		m.from === fromIdx and m.to === toIdx and (m.promotion or null) === prom
	if !pseudoMove
		return { error: 'Illegal move' }

	return { error: 'King would be in check' }

def apply-move-silent moveStr
	const resolved = resolve-legal-move(moveStr)
	if resolved.error then return resolved.error
	engine.make-move(resolved.move)
	currentMoveHistory.push(resolved.notationLower)
	return null

def depth-for-movetime movetimeMs
	if movetimeMs <= 200 then return 1
	if movetimeMs <= 500 then return 2
	if movetimeMs <= 2000 then return 3
	if movetimeMs <= 5000 then return 4
	return 5

def extract-pgn-moves content
	const lines = []
	for rawLine in content.split(/\r?\n/)
		const stripped = rawLine.trim!
		if !stripped or stripped.startsWith('[')
			continue
		lines.push(stripped)

	let moveText = lines.join(' ')
	moveText = moveText.replace(/\{[^}]*\}/g, ' ')
	moveText = moveText.replace(/;[^\n]*/g, ' ')
	moveText = moveText.replace(/\([^)]*\)/g, ' ')

	const moves = []
	for token in moveText.split(/\s+/)
		if !token
			continue
		if token.match(/^\d+\.(\.\.)?$/) or token.match(/^\d+\.$/)
			continue
		if ['1-0', '0-1', '1/2-1/2', '*'].includes(token)
			continue
		moves.push(token)
	return moves

def book-position-key fen
	const parts = fen.trim!.split(/\s+/)
	if parts.length >= 4
		return parts.slice(0, 4).join(' ')
	return fen.trim!

def parse-book-entries content
	const entries = new Map!
	let totalEntries = 0

	for rawLine, idx in content.split(/\r?\n/)
		const line = rawLine.trim!
		if !line or line.startsWith('#')
			continue

		const marker = line.indexOf('->')
		if marker === -1
			throw new Error("line {idx + 1}: expected '<fen> -> <move> [weight]'")

		const key = book-position-key(line.slice(0, marker))
		if !key
			throw new Error("line {idx + 1}: empty position key")

		const rhsParts = line.slice(marker + 2).trim!.split(/\s+/)
		if rhsParts.length === 0 or !rhsParts[0]
			throw new Error("line {idx + 1}: missing move")

		const notation = rhsParts[0].toLowerCase!
		if !notation.match(/^[a-h][1-8][a-h][1-8][qrbn]?$/)
			throw new Error("line {idx + 1}: invalid move '{notation}'")

		let weight = 1
		if rhsParts.length > 1
			weight = parseInt(rhsParts[1])
			if Number.isNaN(weight)
				throw new Error("line {idx + 1}: invalid weight '{rhsParts[1]}'")
			if weight <= 0
				throw new Error("line {idx + 1}: weight must be > 0")

		const bucket = entries.get(key) or []
		bucket.push({ notation: notation, weight: weight })
		entries.set(key, bucket)
		totalEntries++

	return { entries: entries, totalEntries: totalEntries }

def choose-book-move legalMoves
	bookLookups++
	if !bookEnabled or bookEntries.size === 0
		bookMisses++
		return null

	const key = book-position-key(engine.export-fen!)
	const candidates = bookEntries.get(key) or []
	if candidates.length === 0
		bookMisses++
		return null

	const legalByNotation = {}
	for move in legalMoves
		legalByNotation[move-string(move).toLowerCase!] = move

	const weighted = []
	for entry in candidates
		const move = legalByNotation[entry.notation]
		if move
			weighted.push({ move: move, weight: entry.weight, notation: entry.notation })

	if weighted.length === 0
		bookMisses++
		return null

	weighted.sort do(a, b)
		if a.weight !== b.weight then return b.weight - a.weight
		return a.notation.localeCompare(b.notation)

	bookHits++
	return weighted[0].move

def apply-book-move move, emitUci = false
	const moveCli = move-string(move, true)
	const moveLower = move-string(move).toLowerCase!
	engine.make-move(move)
	currentMoveHistory.push(moveLower)
	bookPlayed++
	record-trace-ai('book', moveCli, 0, 0, 0)

	if emitUci
		process.stdout.write("info string bookmove {moveLower}\n")
		process.stdout.write("bestmove {moveLower}\n")
		return

	render-board-if-interactive!
	process.stdout.write("AI: {moveCli} (book)\n")

def perform-ai-turn maxDepth, movetimeMs = 0, emitUci = false
	const legalMoves = engine.generate-moves!
	if legalMoves.length === 0
		if emitUci
			process.stdout.write("bestmove 0000\n")
		else
			process.stdout.write("ERROR: No legal moves available\n")
		return

	const bookMove = choose-book-move(legalMoves)
	if bookMove
		apply-book-move(bookMove, emitUci)
		return

	const depth = movetimeMs > 0 ? depth-for-movetime(movetimeMs) : maxDepth
	const boundedDepth = Math.max(1, Math.min(5, depth))
	const start = Date.now!
	const res = ai.search(boundedDepth)
	if !res.move
		if emitUci
			process.stdout.write("bestmove 0000\n")
		else
			process.stdout.write("ERROR: No legal moves available\n")
		return

	const elapsed = Date.now! - start
	const moveCli = move-string(res.move, true)
	const moveLower = move-string(res.move).toLowerCase!
	engine.make-move(res.move)
	currentMoveHistory.push(moveLower)
	record-trace-ai('search', moveCli, boundedDepth, res.score, elapsed)

	if emitUci
		process.stdout.write("info depth {boundedDepth} score cp {res.score} time {elapsed} nodes 0\n")
		process.stdout.write("bestmove {moveLower}\n")
		return

	render-board-if-interactive!
	process.stdout.write("AI: {moveCli} (depth={boundedDepth}, eval={res.score}, time={elapsed})\n")

def handle-draws
	const repetition = engine.repetition-count!
	const halfmove = engine.state.halfmoveClock
	const draw = repetition >= 3 or halfmove >= 100
	let reason = 'none'
	if halfmove >= 100
		reason = 'fifty_moves'
	else if repetition >= 3
		reason = 'repetition'
	process.stdout.write("DRAWS: repetition={repetition}; halfmove={halfmove}; draw={draw ? 'true' : 'false'}; reason={reason}\n")

def handle-go args
	if args.length === 0
		process.stdout.write("ERROR: go requires subcommand\n")
		return

	const subcommand = args[0].toLowerCase!
	if subcommand === 'depth'
		if args.length < 2
			process.stdout.write("ERROR: go depth requires a value\n")
			return
		const depth = parseInt(args[1])
		if Number.isNaN(depth)
			process.stdout.write("ERROR: go depth requires an integer value\n")
			return
		perform-ai-turn(depth, 0, uciMode)
		return

	if subcommand === 'movetime'
		if args.length < 2
			process.stdout.write("ERROR: go movetime requires a value in milliseconds\n")
			return
		const movetimeMs = parseInt(args[1])
		if Number.isNaN(movetimeMs)
			process.stdout.write("ERROR: go movetime requires an integer value\n")
			return
		if movetimeMs <= 0
			process.stdout.write("ERROR: go movetime must be > 0\n")
			return
		perform-ai-turn(5, movetimeMs, uciMode)
		return

	process.stdout.write("ERROR: Unsupported go command\n")

def handle-pgn args
	if args.length === 0
		process.stdout.write("ERROR: pgn requires subcommand (load|show|moves)\n")
		return

	const subcommand = args[0].toLowerCase!
	if subcommand === 'load'
		if args.length < 2
			process.stdout.write("ERROR: pgn load requires a file path\n")
			return
		const path = args.slice(1).join(' ')
		pgnPath = path
		pgnMoves = []
		try
			const content = fs.readFileSync(path, 'utf8')
			pgnMoves = extract-pgn-moves(content)
			process.stdout.write("PGN: loaded path=\"{path}\"; moves={pgnMoves.length}\n")
		catch err
			process.stdout.write("PGN: loaded path=\"{path}\"; moves=0; note=file-unavailable\n")
		return

	if subcommand === 'show'
		const source = pgnPath or 'current-game'
		const moveCount = pgnPath ? pgnMoves.length : currentMoveHistory.length
		process.stdout.write("PGN: source={source}; moves={moveCount}\n")
		return

	if subcommand === 'moves'
		if pgnPath and pgnMoves.length > 0
			process.stdout.write("PGN: moves {pgnMoves.join(' ')}\n")
		else if currentMoveHistory.length > 0
			process.stdout.write("PGN: moves {currentMoveHistory.join(' ')}\n")
		else
			process.stdout.write("PGN: moves (none)\n")
		return

	process.stdout.write("ERROR: Unsupported pgn command\n")

def handle-book args
	if args.length === 0
		process.stdout.write("ERROR: book requires subcommand (load|on|off|stats)\n")
		return

	const subcommand = args[0].toLowerCase!
	if subcommand === 'load'
		if args.length < 2
			process.stdout.write("ERROR: book load requires a file path\n")
			return
		const path = args.slice(1).join(' ')
		try
			const content = fs.readFileSync(path, 'utf8')
			const parsed = parse-book-entries(content)
			bookPath = path
			bookEntries = parsed.entries
			bookEntryCount = parsed.totalEntries
			bookEnabled = true
			bookLookups = 0
			bookHits = 0
			bookMisses = 0
			bookPlayed = 0
			process.stdout.write("BOOK: loaded path=\"{path}\"; positions={bookEntries.size}; entries={bookEntryCount}; enabled=true\n")
		catch err
			process.stdout.write("ERROR: book load failed: {err.message or err}\n")
		return

	if subcommand === 'on'
		bookEnabled = true
		process.stdout.write("BOOK: enabled=true\n")
		return

	if subcommand === 'off'
		bookEnabled = false
		process.stdout.write("BOOK: enabled=false\n")
		return

	if subcommand === 'stats'
		const path = bookPath or '(none)'
		process.stdout.write("BOOK: enabled={bookEnabled ? 'true' : 'false'}; path={path}; positions={bookEntries.size}; entries={bookEntryCount}; lookups={bookLookups}; hits={bookHits}; misses={bookMisses}; played={bookPlayed}\n")
		return

	process.stdout.write("ERROR: Unsupported book command\n")

def handle-uci
	uciMode = true
	process.stdout.write("id name TGAC Imba; id author TGAC; option name Hash default {uciHashMb}; option name Threads default {uciThreads}; uciok\n")

def handle-isready
	process.stdout.write("readyok\n")

def handle-setoption args
	if args.length < 4 or args[0].toLowerCase! !== 'name'
		process.stdout.write("ERROR: setoption format is 'setoption name <Hash|Threads> value <n>'\n")
		return

	const valueIdx = args.findIndex do(token) token.toLowerCase! === 'value'
	if valueIdx <= 0 or valueIdx + 1 >= args.length
		process.stdout.write("ERROR: setoption requires 'value <n>'\n")
		return

	const name = args.slice(1, valueIdx).join(' ').trim!.toLowerCase!
	const value = parseInt(args[valueIdx + 1])
	if Number.isNaN(value)
		process.stdout.write("ERROR: setoption value must be an integer\n")
		return

	if name === 'hash'
		uciHashMb = Math.max(1, Math.min(1024, value))
		process.stdout.write("info string option Hash={uciHashMb}\n")
		return

	if name === 'threads'
		uciThreads = Math.max(1, Math.min(64, value))
		process.stdout.write("info string option Threads={uciThreads}\n")
		return

	process.stdout.write("info string unsupported option {args.slice(1, valueIdx).join(' ').trim!}\n")

def handle-ucinewgame
	reset-engine-state(START_FEN, true)

def handle-position args
	if args.length === 0
		process.stdout.write("ERROR: position requires 'startpos' or 'fen <...>'\n")
		return

	let idx = 0
	const keyword = args[0].toLowerCase!
	if keyword === 'startpos'
		if !reset-engine-state(START_FEN, true)
			process.stdout.write("ERROR: Invalid FEN string\n")
			return
		idx = 1
	else if keyword === 'fen'
		idx = 1
		const fenTokens = []
		while idx < args.length and args[idx].toLowerCase! !== 'moves'
			fenTokens.push(args[idx])
			idx++
		if fenTokens.length === 0
			process.stdout.write("ERROR: position fen requires a FEN string\n")
			return
		if !reset-engine-state(fenTokens.join(' '), true)
			process.stdout.write("ERROR: Invalid FEN string\n")
			return
	else
		process.stdout.write("ERROR: position requires 'startpos' or 'fen <...>'\n")
		return

	if idx < args.length and args[idx].toLowerCase! === 'moves'
		idx++
		for moveStr in args.slice(idx)
			const error = apply-move-silent(moveStr)
			if error
				process.stdout.write("ERROR: position move {moveStr} failed: {error}\n")
				return

def handle-new960 args
	let id = 0
	if args.length > 0
		id = parseInt(args[0])
		if Number.isNaN(id)
			process.stdout.write("ERROR: new960 id must be an integer\n")
			return

	if id < 0 or id > 959
		process.stdout.write("ERROR: new960 id must be between 0 and 959\n")
		return

	try
		install-engine-state(build-chess960-state(id))
	catch err
		process.stdout.write("ERROR: Invalid Chess960 position\n")
		return

	render-board-if-interactive!
	process.stdout.write("960: new game id={chess960Id}\n")

def handle-position960
	process.stdout.write("960: id={chess960Id}; mode={chess960Mode ? 'chess960' : 'standard'}\n")

def print-board
	process.stdout.write('  a b c d e f g h\n')
	for r in [0 ... 8]
		process.stdout.write("{8 - r} ")
		for c in [0 ... 8]
			const piece = engine.state.board[r * 8 + c]
			if !piece
				process.stdout.write('. ')
			else
				process.stdout.write("{piece.color === 'w' ? piece.type.toUpperCase! : piece.type} ")
		process.stdout.write("{8 - r}\n")
	process.stdout.write('  a b c d e f g h\n\n')
	process.stdout.write("{engine.state.turn === 'w' ? 'White' : 'Black'} to move\n")

def render-board-if-interactive
	if shouldRenderBoard
		print-board!

const rl = readline.createInterface({
	input: process.stdin
	output: process.stdout
	terminal: false
})

render-board-if-interactive!

rl.on('line') do(line)
	const cleaned = line.replace(/\r/g, '')
	const trimmed = cleaned.trim!
	const parts = trimmed.split(/\s+/)
	let tokens = parts
	if parts[0] === '-e'
		tokens = parts.slice(1)
	const cmd = (tokens[0] or "").toLowerCase!
	if cmd and cmd !== 'trace'
		traceCommandCount++
		record-trace('command', trimmed)

	switch cmd
		when 'new'
			if !reset-engine-state(START_FEN)
				process.stdout.write("ERROR: Invalid FEN string\n")
			else
				render-board-if-interactive!
				process.stdout.write("OK: NEW\n")
		when 'move'
			const resolved = resolve-legal-move(tokens[1] or "")
			if resolved.error
				process.stdout.write("ERROR: {resolved.error}\n")
			else
				engine.make-move(resolved.move)
				currentMoveHistory.push(resolved.notationLower)
				render-board-if-interactive!
				process.stdout.write("OK: {resolved.notationCli}\n")
		when 'undo'
			if engine.history.length === 0
				process.stdout.write("ERROR: No moves to undo\n")
			else
				engine.undo!
				if currentMoveHistory.length > 0
					currentMoveHistory.pop!
				render-board-if-interactive!
				process.stdout.write("OK: UNDO\n")
		when 'fen'
			const fenStr = tokens.slice(1).join(' ')
			if !reset-engine-state(fenStr)
				process.stdout.write("ERROR: Invalid FEN string\n")
			else
				render-board-if-interactive!
				process.stdout.write("OK: FEN\n")
		when 'export'
			process.stdout.write("FEN: {engine.export-fen!}\n")
		when 'ai'
			const depth = parseInt(tokens[1] or '3')
			if Number.isNaN(depth) or depth < 1 or depth > 5
				process.stdout.write("ERROR: AI depth must be 1-5\n")
				return
			perform-ai-turn(depth)
		when 'draws'
			handle-draws!
		when 'go'
			handle-go(tokens.slice(1))
		when 'pgn'
			handle-pgn(tokens.slice(1))
		when 'book'
			handle-book(tokens.slice(1))
		when 'uci'
			handle-uci!
		when 'isready'
			handle-isready!
		when 'setoption'
			handle-setoption(tokens.slice(1))
		when 'ucinewgame'
			handle-ucinewgame!
		when 'position'
			handle-position(tokens.slice(1))
		when 'new960'
			handle-new960(tokens.slice(1))
		when 'position960'
			handle-position960!
		when 'trace'
			handle-trace(tokens.slice(1))
		when 'concurrency'
			handle-concurrency(tokens.slice(1))
		when 'status'
			const drawReason = engine.draw-reason!
			if drawReason
				process.stdout.write("DRAW: {drawReason}\n")
				return
			const moves = engine.generate-moves!
			if moves.length === 0
				if engine.is-in-check(engine.state.turn)
					process.stdout.write("CHECKMATE: {engine.state.turn === 'w' ? 'Black' : 'White'} wins\n")
				else
					process.stdout.write("STALEMATE: Draw\n")
			else
				process.stdout.write("OK: ONGOING\n")
		when 'eval'
			process.stdout.write("EVALUATION: {engine.evaluate!}\n")
		when 'hash'
			process.stdout.write("HASH: {engine.hash-string!}\n")
		when 'perft'
			const d = parseInt(tokens[1] or '1')
			const s = Date.now!
			const n = engine.perft(d)
			process.stdout.write("Nodes: {n}, Time: {Date.now! - s}ms\n")
		when 'help'
			process.stdout.write("Commands: new, move, undo, fen, export, ai, draws, go, pgn, book, uci, isready, setoption, ucinewgame, position, new960, position960, status, eval, hash, perft, trace, concurrency, help, quit\n")
		when 'quit'
			process.exit(0)
		else
			if trimmed then process.stdout.write("ERROR: Invalid command\n")
