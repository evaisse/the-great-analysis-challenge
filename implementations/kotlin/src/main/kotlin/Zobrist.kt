// Zobrist hashing for position detection

object Zobrist {
    private val pieceKeys = Array(64 * 12) { 0L }
    private var turnKey = 0L
    private val castlingKeys = Array(16) { 0L }
    private val enPassantKeys = Array(64) { 0L }
    private var initialized = false

    private class Xorshift64(private var state: Long) {
        fun next(): Long {
            state = state xor (state shl 13)
            state = state xor (state ushr 7)
            state = state xor (state shl 17)
            return state
        }
    }

    fun init() {
        if (initialized) return
        val rng = Xorshift64(0x123456789ABCDEF0L)

        for (i in pieceKeys.indices) pieceKeys[i] = rng.next()
        turnKey = rng.next()
        for (i in castlingKeys.indices) castlingKeys[i] = rng.next()
        for (i in enPassantKeys.indices) enPassantKeys[i] = rng.next()
        
        initialized = true
    }

    private fun getPieceIndex(type: PieceType, color: Color): Int {
        val base = when (type) {
            PieceType.PAWN -> 0
            PieceType.KNIGHT -> 1
            PieceType.BISHOP -> 2
            PieceType.ROOK -> 3
            PieceType.QUEEN -> 4
            PieceType.KING -> 5
        }
        return if (color == Color.WHITE) base else base + 6
    }

    fun computeHash(gameState: GameState): Long {
        init()
        var h = 0L
        
        for (i in 0..63) {
            val piece = gameState.board[i]
            if (piece != null) {
                h = h xor pieceKeys[i * 12 + getPieceIndex(piece.type, piece.color)]
            }
        }
        
        if (gameState.turn == Color.BLACK) {
            h = h xor turnKey
        }
        
        var castlingIndex = 0
        if (gameState.castlingRights.whiteKingside) castlingIndex = castlingIndex or 1
        if (gameState.castlingRights.whiteQueenside) castlingIndex = castlingIndex or 2
        if (gameState.castlingRights.blackKingside) castlingIndex = castlingIndex or 4
        if (gameState.castlingRights.blackQueenside) castlingIndex = castlingIndex or 8
        h = h xor castlingKeys[castlingIndex]
        
        val ep = gameState.enPassantTarget
        if (ep != null) {
            h = h xor enPassantKeys[ep]
        }
        
        return h
    }
}
