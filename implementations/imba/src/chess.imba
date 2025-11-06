# Chess Engine Implementation in Imba

import * as readline from 'readline'

# Piece types and colors
const PAWN = 'P'
const KNIGHT = 'N'
const BISHOP = 'B'
const ROOK = 'R'
const QUEEN = 'Q'
const KING = 'K'
const EMPTY = '.'

const WHITE = 'white'
const BLACK = 'black'

# Material values for evaluation
const PIECE_VALUES = {
	P: 100, N: 320, B: 330, R: 500, Q: 900, K: 20000,
	p: -100, n: -320, b: -330, r: -500, q: -900, k: -20000
}

# Chess Board class
class Board
	prop board\any
	prop turn\string
	prop castlingRights\object
	prop enPassantTarget\string
	prop halfmoveClock\number
	prop fullmoveNumber\number
	prop moveHistory\Array

	def constructor
		reset!

	def reset
		board = [
			['r', 'n', 'b', 'q', 'k', 'b', 'n', 'r'],
			['p', 'p', 'p', 'p', 'p', 'p', 'p', 'p'],
			['.', '.', '.', '.', '.', '.', '.', '.'],
			['.', '.', '.', '.', '.', '.', '.', '.'],
			['.', '.', '.', '.', '.', '.', '.', '.'],
			['.', '.', '.', '.', '.', '.', '.', '.'],
			['P', 'P', 'P', 'P', 'P', 'P', 'P', 'P'],
			['R', 'N', 'B', 'Q', 'K', 'B', 'N', 'R']
		]
		turn = WHITE
		castlingRights = { K: true, Q: true, k: true, q: true }
		enPassantTarget = '-'
		halfmoveClock = 0
		fullmoveNumber = 1
		moveHistory = []

	def getPiece row\number, col\number
		return board[row][col] if row >= 0 and row < 8 and col >= 0 and col < 8
		return null

	def setPiece row\number, col\number, piece\string
		board[row][col] = piece if row >= 0 and row < 8 and col >= 0 and col < 8

	def isWhitePiece piece\string
		return piece === piece.toUpperCase! and piece !== '.'

	def isBlackPiece piece\string
		return piece === piece.toLowerCase! and piece !== '.' and piece !== piece.toUpperCase!

	def getPieceColor piece\string
		return null if piece === '.'
		return WHITE if isWhitePiece(piece)
		return BLACK

	# Convert algebraic notation to array indices
	def algebraicToIndices square\string
		const col = square.charCodeAt(0) - 'a'.charCodeAt(0)
		const row = 8 - parseInt(square[1])
		return { row: row, col: col }

	# Convert array indices to algebraic notation
	def indicesToAlgebraic row\number, col\number
		return String.fromCharCode('a'.charCodeAt(0) + col) + String(8 - row)

	# Display the board
	def display
		console.log "  a b c d e f g h"
		for row, i in board
			let line = (8 - i) + " "
			for piece in row
				line += piece + " "
			line += (8 - i)
			console.log line
		console.log "  a b c d e f g h"
		console.log ""
		console.log (turn === WHITE ? "White" : "Black") + " to move"

	# Generate all legal moves
	def generateMoves
		const moves = []
		for row in [0...8]
			for col in [0...8]
				const piece = getPiece(row, col)
				if piece !== '.' and getPieceColor(piece) === turn
					const pieceMoves = generatePieceMoves(row, col, piece)
					moves.push(...pieceMoves)
		return moves

	# Generate moves for a specific piece
	def generatePieceMoves row\number, col\number, piece\string
		const pieceType = piece.toUpperCase!
		const moves = []

		if pieceType === PAWN
			generatePawnMoves(row, col, piece, moves)
		elif pieceType === KNIGHT
			generateKnightMoves(row, col, piece, moves)
		elif pieceType === BISHOP
			generateSlidingMoves(row, col, piece, moves, [[-1, -1], [-1, 1], [1, -1], [1, 1]])
		elif pieceType === ROOK
			generateSlidingMoves(row, col, piece, moves, [[-1, 0], [1, 0], [0, -1], [0, 1]])
		elif pieceType === QUEEN
			generateSlidingMoves(row, col, piece, moves, [[-1, -1], [-1, 1], [1, -1], [1, 1], [-1, 0], [1, 0], [0, -1], [0, 1]])
		elif pieceType === KING
			generateKingMoves(row, col, piece, moves)

		return moves

	# Pawn moves
	def generatePawnMoves row\number, col\number, piece\string, moves\Array
		const direction = isWhitePiece(piece) ? -1 : 1
		const startRow = isWhitePiece(piece) ? 6 : 1

		# Forward move
		const newRow = row + direction
		if newRow >= 0 and newRow < 8 and getPiece(newRow, col) === '.'
			moves.push { from: { row: row, col: col }, to: { row: newRow, col: col } }
			
			# Double move from start
			if row === startRow
				const doubleRow = row + (direction * 2)
				if getPiece(doubleRow, col) === '.'
					moves.push { from: { row: row, col: col }, to: { row: doubleRow, col: col } }

		# Captures
		for dc in [-1, 1]
			const newCol = col + dc
			if newRow >= 0 and newRow < 8 and newCol >= 0 and newCol < 8
				const target = getPiece(newRow, newCol)
				if target !== '.' and getPieceColor(target) !== getPieceColor(piece)
					moves.push { from: { row: row, col: col }, to: { row: newRow, col: newCol } }
				# En passant
				elif enPassantTarget !== '-'
					const epPos = algebraicToIndices(enPassantTarget)
					if epPos.row === newRow and epPos.col === newCol
						moves.push { from: { row: row, col: col }, to: { row: newRow, col: newCol } }

	# Knight moves
	def generateKnightMoves row\number, col\number, piece\string, moves\Array
		const offsets = [[-2, -1], [-2, 1], [-1, -2], [-1, 2], [1, -2], [1, 2], [2, -1], [2, 1]]
		for offset in offsets
			const newRow = row + offset[0]
			const newCol = col + offset[1]
			if newRow >= 0 and newRow < 8 and newCol >= 0 and newCol < 8
				const target = getPiece(newRow, newCol)
				if target === '.' or getPieceColor(target) !== getPieceColor(piece)
					moves.push { from: { row: row, col: col }, to: { row: newRow, col: newCol } }

	# Sliding pieces (Bishop, Rook, Queen)
	def generateSlidingMoves row\number, col\number, piece\string, moves\Array, directions\Array
		for dir in directions
			let newRow = row + dir[0]
			let newCol = col + dir[1]
			while newRow >= 0 and newRow < 8 and newCol >= 0 and newCol < 8
				const target = getPiece(newRow, newCol)
				if target === '.'
					moves.push { from: { row: row, col: col }, to: { row: newRow, col: newCol } }
				else
					if getPieceColor(target) !== getPieceColor(piece)
						moves.push { from: { row: row, col: col }, to: { row: newRow, col: newCol } }
					break
				newRow += dir[0]
				newCol += dir[1]

	# King moves (including castling)
	def generateKingMoves row\number, col\number, piece\string, moves\Array
		const offsets = [[-1, -1], [-1, 0], [-1, 1], [0, -1], [0, 1], [1, -1], [1, 0], [1, 1]]
		for offset in offsets
			const newRow = row + offset[0]
			const newCol = col + offset[1]
			if newRow >= 0 and newRow < 8 and newCol >= 0 and newCol < 8
				const target = getPiece(newRow, newCol)
				if target === '.' or getPieceColor(target) !== getPieceColor(piece)
					moves.push { from: { row: row, col: col }, to: { row: newRow, col: newCol } }

		# Castling
		if isWhitePiece(piece) and row === 7 and col === 4
			if castlingRights.K and getPiece(7, 5) === '.' and getPiece(7, 6) === '.'
				moves.push { from: { row: 7, col: 4 }, to: { row: 7, col: 6 }, castling: 'K' }
			if castlingRights.Q and getPiece(7, 3) === '.' and getPiece(7, 2) === '.' and getPiece(7, 1) === '.'
				moves.push { from: { row: 7, col: 4 }, to: { row: 7, col: 2 }, castling: 'Q' }
		elif isBlackPiece(piece) and row === 0 and col === 4
			if castlingRights.k and getPiece(0, 5) === '.' and getPiece(0, 6) === '.'
				moves.push { from: { row: 0, col: 4 }, to: { row: 0, col: 6 }, castling: 'k' }
			if castlingRights.q and getPiece(0, 3) === '.' and getPiece(0, 2) === '.' and getPiece(0, 1) === '.'
				moves.push { from: { row: 0, col: 4 }, to: { row: 0, col: 2 }, castling: 'q' }

	# Check if a square is under attack
	def isSquareUnderAttack row\number, col\number, byColor\string
		# Save current turn
		const savedTurn = turn
		turn = byColor
		
		# Generate all moves for the attacking color
		const moves = []
		for r in [0...8]
			for c in [0...8]
				const piece = getPiece(r, c)
				if piece !== '.' and getPieceColor(piece) === byColor
					const pieceMoves = generatePieceMoves(r, c, piece)
					moves.push(...pieceMoves)
		
		# Restore turn
		turn = savedTurn
		
		# Check if any move targets the square
		for move in moves
			if move.to.row === row and move.to.col === col
				return true
		return false

	# Find king position
	def findKing color\string
		const kingPiece = color === WHITE ? 'K' : 'k'
		for row in [0...8]
			for col in [0...8]
				if getPiece(row, col) === kingPiece
					return { row: row, col: col }
		return null

	# Check if current player is in check
	def isInCheck
		const kingPos = findKing(turn)
		return false if !kingPos
		const opponentColor = turn === WHITE ? BLACK : WHITE
		return isSquareUnderAttack(kingPos.row, kingPos.col, opponentColor)

	# Make a move
	def makeMove moveStr\string
		# Parse move string (e.g., "e2e4" or "e7e8Q")
		if moveStr.length < 4
			return { success: false, error: "Invalid move format" }

		const fromSquare = moveStr.substring(0, 2)
		const toSquare = moveStr.substring(2, 4)
		const promotion = moveStr.length > 4 ? moveStr[4].toUpperCase! : 'Q'

		const from = algebraicToIndices(fromSquare)
		const to = algebraicToIndices(toSquare)

		const piece = getPiece(from.row, from.col)
		
		# Validate piece exists
		if piece === '.'
			return { success: false, error: "No piece at source square" }

		# Validate piece color
		if getPieceColor(piece) !== turn
			return { success: false, error: "Wrong color piece" }

		# Validate move is legal
		const legalMoves = generateMoves!
		let validMove = null
		for move in legalMoves
			if move.from.row === from.row and move.from.col === from.col and move.to.row === to.row and move.to.col === to.col
				validMove = move
				break

		if !validMove
			return { success: false, error: "Illegal move" }

		# Save move for undo
		const moveRecord = {
			from: from,
			to: to,
			piece: piece,
			capturedPiece: getPiece(to.row, to.col),
			castling: validMove.castling,
			enPassantTarget: enPassantTarget,
			castlingRights: { ...castlingRights },
			halfmoveClock: halfmoveClock,
			fullmoveNumber: fullmoveNumber
		}

		# Execute move
		setPiece(to.row, to.col, piece)
		setPiece(from.row, from.col, '.')

		# Handle castling
		if validMove.castling
			if validMove.castling === 'K'
				setPiece(7, 5, 'R')
				setPiece(7, 7, '.')
			elif validMove.castling === 'Q'
				setPiece(7, 3, 'R')
				setPiece(7, 0, '.')
			elif validMove.castling === 'k'
				setPiece(0, 5, 'r')
				setPiece(0, 7, '.')
			elif validMove.castling === 'q'
				setPiece(0, 3, 'r')
				setPiece(0, 0, '.')

		# Handle en passant capture
		if piece.toUpperCase! === PAWN and enPassantTarget !== '-'
			const epPos = algebraicToIndices(enPassantTarget)
			if to.row === epPos.row and to.col === epPos.col
				const captureRow = turn === WHITE ? to.row + 1 : to.row - 1
				setPiece(captureRow, to.col, '.')

		# Handle pawn promotion
		if piece.toUpperCase! === PAWN and (to.row === 0 or to.row === 7)
			const promotedPiece = turn === WHITE ? promotion : promotion.toLowerCase!
			setPiece(to.row, to.col, promotedPiece)

		# Update en passant target
		enPassantTarget = '-'
		if piece.toUpperCase! === PAWN and Math.abs(to.row - from.row) === 2
			const epRow = turn === WHITE ? from.row - 1 : from.row + 1
			enPassantTarget = indicesToAlgebraic(epRow, from.col)

		# Update castling rights
		if piece === 'K'
			castlingRights.K = false
			castlingRights.Q = false
		elif piece === 'k'
			castlingRights.k = false
			castlingRights.q = false
		elif piece === 'R'
			castlingRights.K = false if from.row === 7 and from.col === 7
			castlingRights.Q = false if from.row === 7 and from.col === 0
		elif piece === 'r'
			castlingRights.k = false if from.row === 0 and from.col === 7
			castlingRights.q = false if from.row === 0 and from.col === 0

		# Update move counters
		halfmoveClock = piece.toUpperCase! === PAWN or moveRecord.capturedPiece !== '.' ? 0 : halfmoveClock + 1
		fullmoveNumber += 1 if turn === BLACK

		# Check if move leaves king in check
		if isInCheck!
			# Undo move
			undoMove(moveRecord)
			return { success: false, error: "King would be in check" }

		# Switch turn
		turn = turn === WHITE ? BLACK : WHITE

		# Store move
		moveHistory.push(moveRecord)

		return { success: true }

	# Undo last move
	def undoMove moveRecord\any = null
		if !moveRecord and moveHistory.length > 0
			moveRecord = moveHistory.pop!
		
		if moveRecord
			# Restore piece positions
			setPiece(moveRecord.from.row, moveRecord.from.col, moveRecord.piece)
			setPiece(moveRecord.to.row, moveRecord.to.col, moveRecord.capturedPiece)

			# Restore castling if it happened
			if moveRecord.castling
				if moveRecord.castling === 'K'
					setPiece(7, 7, 'R')
					setPiece(7, 5, '.')
				elif moveRecord.castling === 'Q'
					setPiece(7, 0, 'R')
					setPiece(7, 3, '.')
				elif moveRecord.castling === 'k'
					setPiece(0, 7, 'r')
					setPiece(0, 5, '.')
				elif moveRecord.castling === 'q'
					setPiece(0, 0, 'r')
					setPiece(0, 3, '.')

			# Restore en passant capture
			if moveRecord.piece.toUpperCase! === PAWN and moveRecord.enPassantTarget !== '-'
				const epPos = algebraicToIndices(moveRecord.enPassantTarget)
				if moveRecord.to.row === epPos.row and moveRecord.to.col === epPos.col
					const captureRow = isWhitePiece(moveRecord.piece) ? moveRecord.to.row + 1 : moveRecord.to.row - 1
					const capturedPawn = isWhitePiece(moveRecord.piece) ? 'p' : 'P'
					setPiece(captureRow, moveRecord.to.col, capturedPawn)

			# Restore state
			enPassantTarget = moveRecord.enPassantTarget
			castlingRights = moveRecord.castlingRights
			halfmoveClock = moveRecord.halfmoveClock
			fullmoveNumber = moveRecord.fullmoveNumber
			turn = turn === WHITE ? BLACK : WHITE

			return true
		return false

	# Export to FEN
	def toFEN
		let fen = ""

		# Board position
		for row in board
			let emptyCount = 0
			for piece in row
				if piece === '.'
					emptyCount++
				else
					fen += String(emptyCount) if emptyCount > 0
					emptyCount = 0
					fen += piece
			fen += String(emptyCount) if emptyCount > 0
			fen += "/"
		fen = fen.substring(0, fen.length - 1)

		# Active color
		fen += " " + (turn === WHITE ? "w" : "b")

		# Castling rights
		let castling = ""
		castling += "K" if castlingRights.K
		castling += "Q" if castlingRights.Q
		castling += "k" if castlingRights.k
		castling += "q" if castlingRights.q
		fen += " " + (castling || "-")

		# En passant
		fen += " " + enPassantTarget

		# Halfmove clock and fullmove number
		fen += " " + String(halfmoveClock) + " " + String(fullmoveNumber)

		return fen

	# Load from FEN
	def fromFEN fen\string
		const parts = fen.split(" ")
		if parts.length < 4
			return false

		# Parse board
		const rows = parts[0].split("/")
		if rows.length !== 8
			return false

		for row, i in rows
			let col = 0
			for char in row
				if char >= '1' and char <= '8'
					const emptyCount = parseInt(char)
					for j in [0...emptyCount]
						board[i][col++] = '.'
				else
					board[i][col++] = char

		# Parse turn
		turn = parts[1] === 'w' ? WHITE : BLACK

		# Parse castling rights
		castlingRights = { K: false, Q: false, k: false, q: false }
		if parts[2] !== '-'
			for char in parts[2]
				castlingRights[char] = true

		# Parse en passant
		enPassantTarget = parts[3]

		# Parse move counters
		halfmoveClock = parts.length > 4 ? parseInt(parts[4]) : 0
		fullmoveNumber = parts.length > 5 ? parseInt(parts[5]) : 1

		return true

	# Evaluate position
	def evaluate
		let score = 0
		for row in [0...8]
			for col in [0...8]
				const piece = getPiece(row, col)
				if piece !== '.'
					score += PIECE_VALUES[piece] || 0
					# Center control bonus
					if (row === 3 or row === 4) and (col === 3 or col === 4)
						score += isWhitePiece(piece) ? 10 : -10
		return score

	# Perft (performance test)
	def perft depth\number
		return 1 if depth === 0

		const moves = generateMoves!
		let nodes = 0

		for move in moves
			const moveStr = indicesToAlgebraic(move.from.row, move.from.col) + indicesToAlgebraic(move.to.row, move.to.col)
			const result = makeMove(moveStr)
			if result.success
				nodes += perft(depth - 1)
				undoMove!
		
		return nodes

	# Check if game is over
	def isGameOver
		const moves = generateMoves!
		if moves.length === 0
			return { over: true, result: isInCheck! ? "CHECKMATE" : "STALEMATE" }
		return { over: false }

# AI class with minimax algorithm
class AI
	prop board\Board

	def constructor b\Board
		board = b

	# Minimax with alpha-beta pruning
	def minimax depth\number, alpha\number, beta\number, maximizing\boolean
		const gameOver = board.isGameOver!
		if depth === 0 or gameOver.over
			return board.evaluate!

		const moves = board.generateMoves!

		if maximizing
			let maxEval = -999999
			for move in moves
				const moveStr = board.indicesToAlgebraic(move.from.row, move.from.col) + board.indicesToAlgebraic(move.to.row, move.to.col)
				const result = board.makeMove(moveStr)
				if result.success
					const evaluation = minimax(depth - 1, alpha, beta, false)
					board.undoMove!
					maxEval = Math.max(maxEval, evaluation)
					alpha = Math.max(alpha, evaluation)
					break if beta <= alpha
			return maxEval
		else
			let minEval = 999999
			for move in moves
				const moveStr = board.indicesToAlgebraic(move.from.row, move.from.col) + board.indicesToAlgebraic(move.to.row, move.to.col)
				const result = board.makeMove(moveStr)
				if result.success
					const evaluation = minimax(depth - 1, alpha, beta, true)
					board.undoMove!
					minEval = Math.min(minEval, evaluation)
					beta = Math.min(beta, evaluation)
					break if beta <= alpha
			return minEval

	# Find best move
	def findBestMove depth\number
		const moves = board.generateMoves!
		let bestMove = null
		let bestEval = board.turn === 'white' ? -999999 : 999999

		const startTime = Date.now!

		for move in moves
			const moveStr = board.indicesToAlgebraic(move.from.row, move.from.col) + board.indicesToAlgebraic(move.to.row, move.to.col)
			const result = board.makeMove(moveStr)
			if result.success
				const evaluation = minimax(depth - 1, -999999, 999999, board.turn === 'black')
				board.undoMove!

				if board.turn === 'white'
					if evaluation > bestEval
						bestEval = evaluation
						bestMove = moveStr
				else
					if evaluation < bestEval
						bestEval = evaluation
						bestMove = moveStr

		const time = Date.now! - startTime
		return { move: bestMove, eval: bestEval, time: time }

# Main game loop
class ChessGame
	prop board\Board
	prop ai\AI

	def constructor
		board = new Board
		ai = new AI(board)

	def run
		const rl = readline.createInterface({
			input: process.stdin,
			output: process.stdout,
			terminal: false
		})

		console.log "Chess Engine in Imba"
		console.log "Type 'help' for available commands"
		console.log ""

		rl.on 'line', do(line)
			const input = line.trim!
			handleCommand(input)

		rl.on 'close', do
			console.log "Goodbye!"
			process.exit(0)

	def handleCommand cmd\string
		const parts = cmd.split(" ")
		const command = parts[0].toLowerCase!

		if command === 'new'
			board.reset!
			console.log "New game started"
			board.display!

		elif command === 'move'
			if parts.length < 2
				console.log "ERROR: Move requires a move string (e.g., move e2e4)"
				return
			const result = board.makeMove(parts[1])
			if result.success
				console.log "OK: {parts[1]}"
				board.display!
				const gameOver = board.isGameOver!
				if gameOver.over
					if gameOver.result === "CHECKMATE"
						const winner = board.turn === 'white' ? 'Black' : 'White'
						console.log "CHECKMATE: {winner} wins"
					else
						console.log "STALEMATE: Draw"
			else
				console.log "ERROR: {result.error}"

		elif command === 'undo'
			if board.undoMove!
				console.log "Move undone"
				board.display!
			else
				console.log "ERROR: No moves to undo"

		elif command === 'display'
			board.display!

		elif command === 'export'
			console.log "FEN: {board.toFEN!}"

		elif command === 'fen'
			if parts.length < 2
				console.log "ERROR: FEN requires a FEN string"
				return
			const fenStr = parts.slice(1).join(" ")
			if board.fromFEN(fenStr)
				console.log "Position loaded"
				board.display!
			else
				console.log "ERROR: Invalid FEN string"

		elif command === 'ai'
			const depth = parts.length > 1 ? parseInt(parts[1]) : 3
			if depth < 1 or depth > 5
				console.log "ERROR: AI depth must be 1-5"
				return
			console.log "AI thinking at depth {depth}..."
			const result = ai.findBestMove(depth)
			if result.move
				board.makeMove(result.move)
				console.log "AI: {result.move} (depth={depth}, eval={result.eval}, time={result.time}ms)"
				board.display!
				const gameOver = board.isGameOver!
				if gameOver.over
					if gameOver.result === "CHECKMATE"
						const winner = board.turn === 'white' ? 'Black' : 'White'
						console.log "CHECKMATE: {winner} wins"
					else
						console.log "STALEMATE: Draw"
			else
				console.log "ERROR: No legal moves available"

		elif command === 'eval'
			const evaluation = board.evaluate!
			console.log "Position evaluation: {evaluation}"

		elif command === 'perft'
			const depth = parts.length > 1 ? parseInt(parts[1]) : 4
			console.log "Running perft({depth})..."
			const startTime = Date.now!
			const nodes = board.perft(depth)
			const time = Date.now! - startTime
			console.log "Nodes: {nodes} (time: {time}ms)"

		elif command === 'help'
			console.log "Available commands:"
			console.log "  new              - Start a new game"
			console.log "  move <move>      - Make a move (e.g., move e2e4)"
			console.log "  undo             - Undo the last move"
			console.log "  display          - Display the board"
			console.log "  export           - Export position as FEN"
			console.log "  fen <string>     - Load position from FEN"
			console.log "  ai <depth>       - AI makes a move (depth 1-5)"
			console.log "  eval             - Evaluate current position"
			console.log "  perft <depth>    - Run performance test"
			console.log "  help             - Show this help message"
			console.log "  quit             - Exit the program"

		elif command === 'quit' or command === 'exit'
			console.log "Goodbye!"
			process.exit(0)

		else
			console.log "ERROR: Invalid command. Type 'help' for available commands."

# Start the game
const game = new ChessGame
game.run!
