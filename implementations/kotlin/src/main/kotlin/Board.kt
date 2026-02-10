// Board representation and game state management

class Board {
    private var gameState: GameState = createInitialGameState()
    private val gameStateStack = mutableListOf<GameState>()
    
    private fun createInitialGameState(): GameState {
        val board = Array<Piece?>(64) { null }
        
        // White pieces
        board[0] = Piece(PieceType.ROOK, Color.WHITE)
        board[1] = Piece(PieceType.KNIGHT, Color.WHITE)
        board[2] = Piece(PieceType.BISHOP, Color.WHITE)
        board[3] = Piece(PieceType.QUEEN, Color.WHITE)
        board[4] = Piece(PieceType.KING, Color.WHITE)
        board[5] = Piece(PieceType.BISHOP, Color.WHITE)
        board[6] = Piece(PieceType.KNIGHT, Color.WHITE)
        board[7] = Piece(PieceType.ROOK, Color.WHITE)
        
        for (i in 8..15) {
            board[i] = Piece(PieceType.PAWN, Color.WHITE)
        }
        
        // Black pieces
        for (i in 48..55) {
            board[i] = Piece(PieceType.PAWN, Color.BLACK)
        }
        
        board[56] = Piece(PieceType.ROOK, Color.BLACK)
        board[57] = Piece(PieceType.KNIGHT, Color.BLACK)
        board[58] = Piece(PieceType.BISHOP, Color.BLACK)
        board[59] = Piece(PieceType.QUEEN, Color.BLACK)
        board[60] = Piece(PieceType.KING, Color.BLACK)
        board[61] = Piece(PieceType.BISHOP, Color.BLACK)
        board[62] = Piece(PieceType.KNIGHT, Color.BLACK)
        board[63] = Piece(PieceType.ROOK, Color.BLACK)
        
        return GameState(
            board = board,
            turn = Color.WHITE,
            castlingRights = CastlingRights()
        )
    }
    
    fun reset() {
        gameState = createInitialGameState()
        gameStateStack.clear()
    }
    
    fun getPiece(square: Square): Piece? = gameState.board[square]
    
    fun getTurn(): Color = gameState.turn
    
    fun getGameState(): GameState = gameState
    
    fun setGameState(newState: GameState) {
        gameState = newState
    }
    
    fun makeMove(move: Move): Boolean {
        val piece = getPiece(move.from) ?: return false
        
        if (piece.color != gameState.turn) return false
        
        val newState = gameState.copy()
        gameStateStack.add(gameState) // Save current state before modifying
        
        // Record current position hash in history before moving
        newState.positionHistory.add(gameState.zobristHash)

        // Move the piece
        newState.board[move.to] = piece
        newState.board[move.from] = null
        
        // Handle special moves
        handleCastling(newState, move, piece)
        handleEnPassant(newState, move, piece)
        handlePromotion(newState, move, piece)
        
        // Update castling rights
        updateCastlingRights(newState, move, piece)
        
        // Update en passant target
        updateEnPassantTarget(newState, move, piece)
        
        // Update move counters
        updateMoveCounters(newState, move, piece)
        
        // Switch turn
        newState.turn = piece.color.opposite()
        newState.moveHistory.add(move)
        
        // Update hash
        newState.zobristHash = Zobrist.computeHash(newState)

        gameState = newState
        return true
    }

    fun isDraw(): Boolean {
        return isDrawByRepetition() || isDrawByFiftyMoveRule()
    }

    fun isDrawByRepetition(): Boolean {
        var count = 1
        for (h in gameState.positionHistory) {
            if (h == gameState.zobristHash) {
                count++
                if (count >= 3) return true
            }
        }
        return false
    }

    fun isDrawByFiftyMoveRule(): Boolean {
        return gameState.halfmoveClock >= 100
    }

    fun getDrawInfo(): String? {
        if (isDrawByFiftyMoveRule()) return "50-move rule"
        if (isDrawByRepetition()) return "repetition"
        return null
    }
    
    private fun handleCastling(state: GameState, move: Move, piece: Piece) {
        if (!move.isCastling) return
        
        val rank = if (piece.color == Color.WHITE) 0 else 7
        val (rookFrom, rookTo) = if (move.to == rank * 8 + 6) {
            // Kingside
            Pair(rank * 8 + 7, rank * 8 + 5)
        } else {
            // Queenside
            Pair(rank * 8, rank * 8 + 3)
        }
        
        val rook = state.board[rookFrom]
        if (rook != null) {
            state.board[rookTo] = rook
            state.board[rookFrom] = null
        }
    }
    
    private fun handleEnPassant(state: GameState, move: Move, piece: Piece) {
        if (!move.isEnPassant) return
        
        val capturedPawnSquare = if (piece.color == Color.WHITE) {
            move.to - 8
        } else {
            move.to + 8
        }
        state.board[capturedPawnSquare] = null
    }
    
    private fun handlePromotion(state: GameState, move: Move, piece: Piece) {
        if (move.promotion != null) {
            state.board[move.to] = Piece(move.promotion, piece.color)
        }
    }
    
    private fun updateCastlingRights(state: GameState, move: Move, piece: Piece) {
        var rights = state.castlingRights
        
        when (piece.type) {
            PieceType.KING -> {
                rights = if (piece.color == Color.WHITE) {
                    rights.copy(whiteKingside = false, whiteQueenside = false)
                } else {
                    rights.copy(blackKingside = false, blackQueenside = false)
                }
            }
            PieceType.ROOK -> {
                rights = when (piece.color to move.from) {
                    Color.WHITE to 0 -> rights.copy(whiteQueenside = false)
                    Color.WHITE to 7 -> rights.copy(whiteKingside = false)
                    Color.BLACK to 56 -> rights.copy(blackQueenside = false)
                    Color.BLACK to 63 -> rights.copy(blackKingside = false)
                    else -> rights
                }
            }
            else -> {}
        }
        
        state.castlingRights = rights
    }
    
    private fun updateEnPassantTarget(state: GameState, move: Move, piece: Piece) {
        state.enPassantTarget = if (piece.type == PieceType.PAWN && 
                                    kotlin.math.abs(move.to - move.from) == 16) {
            (move.from + move.to) / 2
        } else {
            null
        }
    }
    
    private fun updateMoveCounters(state: GameState, move: Move, piece: Piece) {
        state.halfmoveClock = if (piece.type == PieceType.PAWN || move.captured != null) {
            0
        } else {
            state.halfmoveClock + 1
        }
        
        if (piece.color == Color.BLACK) {
            state.fullmoveNumber += 1
        }
    }
    
    fun undoMove(): Move? {
        if (gameStateStack.isEmpty()) return null
        
        val lastMove = gameState.moveHistory.lastOrNull() ?: return null
        gameState = gameStateStack.removeAt(gameStateStack.size - 1)
        
        return lastMove
    }
    
    override fun toString(): String {
        val sb = StringBuilder()
        sb.append("  a b c d e f g h\n")
        
        for (rank in 7 downTo 0) {
            sb.append("${rank + 1} ")
            for (file in 0..7) {
                val square = rank * 8 + file
                val piece = getPiece(square)
                sb.append("${piece?.toChar() ?: '.'} ")
            }
            sb.append("${rank + 1}\n")
        }
        
        sb.append("  a b c d e f g h\n\n")
        sb.append("${if (getTurn() == Color.WHITE) "White" else "Black"} to move")
        
        return sb.toString()
    }
}