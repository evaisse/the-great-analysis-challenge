// Core chess types and data structures

enum class Color {
    WHITE, BLACK;
    
    fun opposite(): Color = if (this == WHITE) BLACK else WHITE
}

enum class PieceType(val value: Int, val symbol: Char) {
    PAWN(100, 'P'),
    KNIGHT(320, 'N'),
    BISHOP(330, 'B'),
    ROOK(500, 'R'),
    QUEEN(900, 'Q'),
    KING(20000, 'K');
    
    companion object {
        fun fromChar(char: Char): PieceType? {
            return values().find { it.symbol == char.toUpperCase() }
        }
    }
}

data class Piece(val type: PieceType, val color: Color) {
    fun toChar(): Char {
        return if (color == Color.WHITE) type.symbol else type.symbol.toLowerCase()
    }
    
    companion object {
        fun fromChar(char: Char): Piece? {
            val pieceType = PieceType.fromChar(char) ?: return null
            val color = if (char.isUpperCase()) Color.WHITE else Color.BLACK
            return Piece(pieceType, color)
        }
    }
}

typealias Square = Int

data class Move(
    val from: Square,
    val to: Square,
    val piece: PieceType,
    val captured: PieceType? = null,
    val promotion: PieceType? = null,
    val isCastling: Boolean = false,
    val isEnPassant: Boolean = false
) {
    override fun toString(): String {
        val fromStr = squareToAlgebraic(from)
        val toStr = squareToAlgebraic(to)
        val promotionStr = promotion?.symbol?.toString() ?: ""
        return fromStr + toStr + promotionStr
    }
}

data class CastlingRights(
    val whiteKingside: Boolean = true,
    val whiteQueenside: Boolean = true,
    val blackKingside: Boolean = true,
    val blackQueenside: Boolean = true
) {
    companion object {
        fun none() = CastlingRights(false, false, false, false)
    }
}

data class GameState(
    var board: Array<Piece?>,
    var turn: Color,
    var castlingRights: CastlingRights,
    var enPassantTarget: Square? = null,
    var halfmoveClock: Int = 0,
    var fullmoveNumber: Int = 1,
    var moveHistory: MutableList<Move> = mutableListOf(),
    var zobristHash: Long = 0L,
    var positionHistory: MutableList<Long> = mutableListOf()
) {
    init {
        if (zobristHash == 0L) {
            zobristHash = Zobrist.computeHash(this)
        }
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is GameState) return false
        
        return board.contentEquals(other.board) &&
               turn == other.turn &&
               castlingRights == other.castlingRights &&
               enPassantTarget == other.enPassantTarget &&
               halfmoveClock == other.halfmoveClock &&
               fullmoveNumber == other.fullmoveNumber
    }
    
    override fun hashCode(): Int {
        return zobristHash.toInt()
    }
    
    fun copy(): GameState {
        return GameState(
            board = board.copyOf(),
            turn = turn,
            castlingRights = castlingRights,
            enPassantTarget = enPassantTarget,
            halfmoveClock = halfmoveClock,
            fullmoveNumber = fullmoveNumber,
            moveHistory = moveHistory.toMutableList(),
            zobristHash = zobristHash,
            positionHistory = positionHistory.toMutableList()
        )
    }
}

data class SearchResult(
    val bestMove: Move?,
    val evaluation: Int,
    val nodes: Int,
    val timeMs: Long
)

// Utility functions
fun squareToAlgebraic(square: Square): String {
    val file = square % 8
    val rank = square / 8
    return "${('a' + file)}${rank + 1}"
}

fun algebraicToSquare(algebraic: String): Square? {
    if (algebraic.length != 2) return null
    val file = algebraic[0] - 'a'
    val rank = algebraic[1] - '1'
    if (file !in 0..7 || rank !in 0..7) return null
    return rank * 8 + file
}

fun isValidSquare(square: Square): Boolean {
    return square in 0..63
}

// Files and ranks for display
val FILES = "abcdefgh"
val RANKS = "12345678"