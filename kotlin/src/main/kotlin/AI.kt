// AI engine with minimax and alpha-beta pruning

class AI {
    private val moveGenerator = MoveGenerator()
    private var nodesEvaluated = 0L
    
    fun findBestMove(board: Board, depth: Int): SearchResult {
        val startTime = System.currentTimeMillis()
        nodesEvaluated = 0
        
        val gameState = board.getGameState()
        val color = gameState.turn
        val moves = moveGenerator.getLegalMoves(gameState, color)
        
        if (moves.isEmpty()) {
            return SearchResult(null, 0, 0, 0)
        }
        
        var bestMove = moves[0]
        var bestEval = if (color == Color.WHITE) Int.MIN_VALUE else Int.MAX_VALUE
        
        for (move in moves) {
            val newState = gameState.copy()
            makeMove(newState, move)
            
            val evaluation = minimax(newState, depth - 1, Int.MIN_VALUE, Int.MAX_VALUE, color == Color.BLACK)
            
            if ((color == Color.WHITE && evaluation > bestEval) || 
                (color == Color.BLACK && evaluation < bestEval)) {
                bestEval = evaluation
                bestMove = move
            }
        }
        
        val elapsed = System.currentTimeMillis() - startTime
        return SearchResult(bestMove, bestEval, nodesEvaluated.toInt(), elapsed)
    }
    
    private fun minimax(gameState: GameState, depth: Int, alpha: Int, beta: Int, maximizing: Boolean): Int {
        nodesEvaluated++
        
        if (depth == 0) {
            return evaluate(gameState)
        }
        
        val color = gameState.turn
        val moves = moveGenerator.getLegalMoves(gameState, color)
        
        if (moves.isEmpty()) {
            return if (moveGenerator.isInCheck(gameState, color)) {
                if (maximizing) -100000 else 100000
            } else {
                0 // Stalemate
            }
        }
        
        if (maximizing) {
            var maxEval = Int.MIN_VALUE
            var currentAlpha = alpha
            
            for (move in moves) {
                val newState = gameState.copy()
                makeMove(newState, move)
                
                val evaluation = minimax(newState, depth - 1, currentAlpha, beta, false)
                maxEval = maxOf(maxEval, evaluation)
                currentAlpha = maxOf(currentAlpha, evaluation)
                
                if (beta <= currentAlpha) {
                    break // Beta cutoff
                }
            }
            
            return maxEval
        } else {
            var minEval = Int.MAX_VALUE
            var currentBeta = beta
            
            for (move in moves) {
                val newState = gameState.copy()
                makeMove(newState, move)
                
                val evaluation = minimax(newState, depth - 1, alpha, currentBeta, true)
                minEval = minOf(minEval, evaluation)
                currentBeta = minOf(currentBeta, evaluation)
                
                if (currentBeta <= alpha) {
                    break // Alpha cutoff
                }
            }
            
            return minEval
        }
    }
    
    private fun evaluate(gameState: GameState): Int {
        var score = 0
        
        for (square in 0..63) {
            val piece = gameState.board[square]
            if (piece != null) {
                val value = piece.type.value
                val positionBonus = getPositionBonus(square, piece.type, piece.color, gameState)
                val totalValue = value + positionBonus
                
                score += if (piece.color == Color.WHITE) totalValue else -totalValue
            }
        }
        
        return score
    }
    
    private fun getPositionBonus(square: Square, pieceType: PieceType, color: Color, gameState: GameState): Int {
        val file = square % 8
        val rank = square / 8
        var bonus = 0
        
        // Center control bonus
        val centerSquares = listOf(27, 28, 35, 36) // d4, e4, d5, e5
        if (square in centerSquares) {
            bonus += 10
        }
        
        when (pieceType) {
            PieceType.PAWN -> {
                // Pawn advancement bonus
                val advancement = if (color == Color.WHITE) rank else 7 - rank
                bonus += advancement * 5
            }
            PieceType.KING -> {
                // King safety in opening/middlegame
                if (!isEndgame(gameState)) {
                    val safeRank = if (color == Color.WHITE) 0 else 7
                    if (rank == safeRank && (file <= 2 || file >= 5)) {
                        bonus += 20
                    } else {
                        bonus -= 20
                    }
                }
            }
            else -> {}
        }
        
        return bonus
    }
    
    private fun isEndgame(gameState: GameState): Boolean {
        var pieceCount = 0
        var queenCount = 0
        
        for (square in 0..63) {
            val piece = gameState.board[square]
            if (piece != null && piece.type != PieceType.KING && piece.type != PieceType.PAWN) {
                pieceCount++
                if (piece.type == PieceType.QUEEN) {
                    queenCount++
                }
            }
        }
        
        return pieceCount <= 4 || (pieceCount <= 6 && queenCount == 0)
    }
    
    private fun makeMove(gameState: GameState, move: Move) {
        val piece = gameState.board[move.from]!!
        
        // Move piece
        gameState.board[move.to] = piece
        gameState.board[move.from] = null
        
        // Handle special moves
        if (move.isCastling) {
            val rank = if (piece.color == Color.WHITE) 0 else 7
            val (rookFrom, rookTo) = if (move.to == rank * 8 + 6) {
                Pair(rank * 8 + 7, rank * 8 + 5)
            } else {
                Pair(rank * 8, rank * 8 + 3)
            }
            
            val rook = gameState.board[rookFrom]
            if (rook != null) {
                gameState.board[rookTo] = rook
                gameState.board[rookFrom] = null
            }
        }
        
        if (move.isEnPassant) {
            val capturedPawnSquare = if (piece.color == Color.WHITE) {
                move.to - 8
            } else {
                move.to + 8
            }
            gameState.board[capturedPawnSquare] = null
        }
        
        if (move.promotion != null) {
            gameState.board[move.to] = Piece(move.promotion, piece.color)
        }
        
        // Switch turn for next evaluation
        gameState.turn = piece.color.opposite()
    }
}