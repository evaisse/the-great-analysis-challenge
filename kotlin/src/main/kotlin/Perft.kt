// Performance testing utilities

class Perft {
    private val moveGenerator = MoveGenerator()
    
    fun perft(gameState: GameState, depth: Int): Long {
        if (depth == 0) {
            return 1L
        }
        
        val color = gameState.turn
        val moves = moveGenerator.getLegalMoves(gameState, color)
        var nodes = 0L
        
        for (move in moves) {
            val newState = gameState.copy()
            makeMove(newState, move)
            nodes += perft(newState, depth - 1)
        }
        
        return nodes
    }
    
    fun perftDivide(gameState: GameState, depth: Int): Map<String, Long> {
        val results = mutableMapOf<String, Long>()
        val color = gameState.turn
        val moves = moveGenerator.getLegalMoves(gameState, color)
        
        for (move in moves) {
            val moveStr = moveToString(move)
            val newState = gameState.copy()
            makeMove(newState, move)
            val count = perft(newState, depth - 1)
            results[moveStr] = count
        }
        
        return results
    }
    
    private fun moveToString(move: Move): String {
        val fromStr = squareToAlgebraic(move.from)
        val toStr = squareToAlgebraic(move.to)
        val promotionStr = move.promotion?.symbol?.toString() ?: ""
        return fromStr + toStr + promotionStr
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
        
        // Switch turn
        gameState.turn = piece.color.opposite()
    }
}