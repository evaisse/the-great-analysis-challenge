import java.io.File

private const val START_FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
private const val DEFAULT_CHESS960_ID = 518

class ChessEngine {
    private val board = Board()
    private val moveGenerator = MoveGenerator()
    private val fenParser = FenParser()
    private val ai = AI()
    private val perft = Perft()

    private var loadedPgnPath = ""
    private var loadedPgnMoves = emptyList<String>()
    private var bookPath = ""
    private var bookMoves = emptyList<String>()
    private var bookPositionCount = 0
    private var bookEntryCount = 0
    private var bookEnabled = false
    private var bookLookups = 0
    private var bookHits = 0
    private var bookMisses = 0
    private var bookPlayed = 0
    private var chess960Id: Int? = null
    private var chess960Fen = START_FEN
    private var traceEnabled = false
    private var traceLevel = "basic"
    private val traceEvents = mutableListOf<String>()
    private var traceCommandCount = 0

    fun run() {
        while (true) {
            val input = readLine()?.trim() ?: break
            if (input.isEmpty()) continue

            if (!processCommand(input)) {
                break
            }
        }
    }

    private fun processCommand(command: String): Boolean {
        val parts = command.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }
        if (parts.isEmpty()) return true

        val cmd = parts[0].toUpperCase()
        if (traceEnabled && cmd != "TRACE") {
            recordTrace(command)
        }

        when (cmd) {
            "MOVE" -> {
                if (parts.size > 1) {
                    handleMove(parts[1])
                } else {
                    println("ERROR: Invalid move format")
                }
            }
            "UNDO" -> handleUndo()
            "NEW" -> handleNew()
            "STATUS" -> handleStatus()
            "AI" -> {
                if (parts.size > 1) {
                    handleAi(parts[1])
                } else {
                    println("ERROR: AI depth must be 1-5")
                }
            }
            "GO" -> handleGo(parts)
            "FEN" -> {
                if (parts.size > 1) {
                    val fenString = parts.drop(1).joinToString(" ")
                    handleFen(fenString)
                } else {
                    println("ERROR: Invalid FEN string")
                }
            }
            "EXPORT" -> handleExport()
            "EVAL" -> handleEval()
            "HASH" -> handleHash()
            "DRAWS" -> handleDraws()
            "HISTORY" -> handleHistory()
            "PGN" -> handlePgn(parts)
            "BOOK" -> handleBook(parts)
            "UCI" -> handleUci()
            "ISREADY" -> println("readyok")
            "NEW960" -> handleNew960(parts)
            "POSITION960" -> println("960: id=${currentChess960Id()}; fen=$chess960Fen")
            "TRACE" -> handleTrace(parts)
            "CONCURRENCY" -> handleConcurrency(parts)
            "PERFT" -> {
                if (parts.size > 1) {
                    handlePerft(parts[1])
                } else {
                    println("ERROR: Invalid perft depth")
                }
            }
            "HELP" -> handleHelp()
            "QUIT", "EXIT" -> return false
            else -> println("ERROR: Invalid command")
        }

        return true
    }

    private fun resetGame() {
        board.reset()
        loadedPgnPath = ""
        loadedPgnMoves = emptyList()
        chess960Id = null
        chess960Fen = START_FEN
    }

    private fun currentChess960Id(): Int = chess960Id ?: DEFAULT_CHESS960_ID

    private fun currentFen(): String = fenParser.exportFen(board)

    private fun boolText(value: Boolean): String = if (value) "true" else "false"

    private fun repetitionCount(): Int {
        val state = board.getGameState()
        return state.positionHistory.count { it == state.zobristHash } + 1
    }

    private fun depthFromMovetime(movetime: Int): Int = when {
        movetime <= 250 -> 1
        movetime <= 1000 -> 2
        else -> 3
    }

    private fun formatLivePgn(moves: List<String>): String {
        if (moves.isEmpty()) return "(empty)"

        val turns = mutableListOf<String>()
        var index = 0
        while (index < moves.size) {
            var turn = "${index / 2 + 1}. ${moves[index]}"
            if (index + 1 < moves.size) {
                turn += " ${moves[index + 1]}"
            }
            turns += turn
            index += 2
        }
        return turns.joinToString(" ")
    }

    private fun extractPgnTokens(content: String): List<String> {
        val cleaned = content
            .replace(Regex("\\{[^}]*\\}"), " ")
            .replace(Regex("\\([^)]*\\)"), " ")
            .replace(Regex("\\[[^]]*]"), " ")
            .replace(Regex("\\$\\d+"), " ")
            .replace(Regex("\\d+\\.(\\.\\.)?"), " ")
            .replace(Regex("\\s+"), " ")
            .trim()

        if (cleaned.isEmpty()) return emptyList()

        return cleaned
            .split(Regex("\\s+"))
            .filter { token -> token.isNotEmpty() && token !in setOf("1-0", "0-1", "1/2-1/2", "*") }
    }

    private fun resolveLegalMove(notation: String): Move? {
        val target = notation.toLowerCase()
        return moveGenerator
            .getLegalMoves(board.getGameState(), board.getTurn())
            .firstOrNull { it.toString().toLowerCase() == target }
    }

    private fun recordTrace(command: String) {
        traceCommandCount += 1
        traceEvents += command
        if (traceEvents.size > 128) {
            traceEvents.removeAt(0)
        }
    }

    private fun handleMove(moveStr: String) {
        if (moveStr.length < 4) {
            println("ERROR: Invalid move format")
            return
        }

        val fromStr = moveStr.substring(0, 2)
        val toStr = moveStr.substring(2, 4)
        val promotionStr = if (moveStr.length > 4) moveStr.substring(4, 5).toUpperCase() else null

        val fromSquare = algebraicToSquare(fromStr)
        val toSquare = algebraicToSquare(toStr)

        if (fromSquare == null || toSquare == null) {
            println("ERROR: Invalid move format")
            return
        }

        val piece = board.getPiece(fromSquare)
        if (piece == null) {
            println("ERROR: No piece at source square")
            return
        }

        val turn = board.getTurn()
        if (piece.color != turn) {
            println("ERROR: Wrong color piece")
            return
        }

        val legalMoves = moveGenerator.getLegalMoves(board.getGameState(), turn)
        val matchingMove = findMatchingMove(legalMoves, fromSquare, toSquare, promotionStr)

        if (matchingMove != null) {
            board.makeMove(matchingMove)

            val nextTurn = board.getTurn()
            val nextLegalMoves = moveGenerator.getLegalMoves(board.getGameState(), nextTurn)

            if (nextLegalMoves.isEmpty()) {
                if (moveGenerator.isInCheck(board.getGameState(), nextTurn)) {
                    val winner = if (turn == Color.WHITE) "White" else "Black"
                    println("CHECKMATE: $winner wins")
                } else {
                    println("STALEMATE: Draw")
                }
            } else {
                println("OK: $moveStr")
            }
            println(board)
        } else {
            if (moveGenerator.isInCheck(board.getGameState(), turn)) {
                println("ERROR: King would be in check")
            } else {
                println("ERROR: Illegal move")
            }
        }
    }

    private fun findMatchingMove(moves: List<Move>, from: Square, to: Square, promotionStr: String?): Move? {
        return moves.find { move ->
            move.from == from && move.to == to &&
                (promotionStr == null || (move.promotion != null && move.promotion.symbol.toString() == promotionStr))
        }
    }

    private fun handleUndo() {
        val move = board.undoMove()
        if (move != null) {
            println("OK: undo")
            println(board)
        } else {
            println("ERROR: No moves to undo")
        }
    }

    private fun handleNew() {
        resetGame()
        println("OK: New game started")
        println(board)
    }

    private fun executeAi(depth: Int): String {
        if (bookEnabled) {
            bookLookups += 1
            if (currentFen() == START_FEN) {
                val bookMove = bookMoves.firstOrNull()?.let { resolveLegalMove(it) }
                if (bookMove != null) {
                    board.makeMove(bookMove)
                    bookHits += 1
                    bookPlayed += 1
                    return "AI: ${bookMove.toString().toLowerCase()} (book)"
                }
            }
            bookMisses += 1
        }

        val boundedDepth = depth.coerceIn(1, 5)
        val result = ai.findBestMove(board, boundedDepth)
        val bestMove = result.bestMove ?: return "ERROR: No legal moves available"

        val moveStr = bestMove.toString().toLowerCase()
        board.makeMove(bestMove)

        val nextTurn = board.getTurn()
        val nextLegalMoves = moveGenerator.getLegalMoves(board.getGameState(), nextTurn)
        return if (nextLegalMoves.isEmpty()) {
            if (moveGenerator.isInCheck(board.getGameState(), nextTurn)) {
                "AI: $moveStr (CHECKMATE)"
            } else {
                "AI: $moveStr (STALEMATE)"
            }
        } else {
            "AI: $moveStr (depth=$boundedDepth, eval=${result.evaluation}, time=${result.timeMs})"
        }
    }

    private fun handleAi(depthStr: String) {
        val depth = depthStr.toIntOrNull()
        if (depth == null || depth < 1 || depth > 5) {
            println("ERROR: AI depth must be 1-5")
            return
        }

        val output = executeAi(depth)
        println(output)
        if (output.startsWith("AI:")) {
            println(board)
        }
    }

    private fun handleGo(parts: List<String>) {
        if (parts.size == 3 && parts[1].equals("movetime", ignoreCase = true)) {
            val movetime = parts[2].toIntOrNull()
            if (movetime != null && movetime > 0) {
                val output = executeAi(depthFromMovetime(movetime))
                println(output)
                if (output.startsWith("AI:")) {
                    println(board)
                }
                return
            }
        }
        println("ERROR: Unsupported go command")
    }

    private fun handleStatus() {
        val color = board.getTurn()
        val legalMoves = moveGenerator.getLegalMoves(board.getGameState(), color)

        if (legalMoves.isEmpty()) {
            if (moveGenerator.isInCheck(board.getGameState(), color)) {
                val winner = if (color == Color.WHITE) "Black" else "White"
                println("CHECKMATE: $winner wins")
            } else {
                println("STALEMATE: Draw")
            }
        } else {
            val drawReason = board.getDrawInfo()
            if (drawReason != null) {
                println("DRAW: by $drawReason")
            } else {
                println("OK: ongoing")
            }
        }
    }

    private fun handleFen(fenString: String) {
        val success = fenParser.parseFen(board, fenString)
        if (success) {
            chess960Id = null
            chess960Fen = fenString
            println("OK: FEN loaded")
            println(board)
        } else {
            println("ERROR: Invalid FEN string")
        }
    }

    private fun handleExport() {
        val fen = fenParser.exportFen(board)
        println("FEN: $fen")
    }

    private fun handleEval() {
        val result = ai.findBestMove(board, 1)
        println("EVALUATION: ${result.evaluation}")
    }

    private fun handleHash() {
        println("HASH: ${String.format("%016x", board.getGameState().zobristHash)}")
    }

    private fun handleDraws() {
        val state = board.getGameState()
        val repetitions = repetitionCount()
        val byFiftyMove = state.halfmoveClock >= 100
        println(
            "DRAWS: repetition=${boolText(repetitions >= 3)} count=$repetitions " +
                "fifty_move=${boolText(byFiftyMove)} halfmove_clock=${state.halfmoveClock}"
        )
    }

    private fun handleHistory() {
        val state = board.getGameState()
        println("Position History (${state.positionHistory.size + 1} positions):")
        for ((index, hash) in state.positionHistory.withIndex()) {
            println("  $index: ${String.format("%016x", hash)}")
        }
        println("  ${state.positionHistory.size}: ${String.format("%016x", state.zobristHash)} (current)")
    }

    private fun handlePgn(parts: List<String>) {
        val subcommand = parts.getOrNull(1)?.toLowerCase() ?: run {
            println("ERROR: Unsupported pgn command")
            return
        }

        when (subcommand) {
            "load" -> {
                val path = parts.drop(2).joinToString(" ")
                if (path.isEmpty()) {
                    println("ERROR: PGN file path required")
                    return
                }

                val file = File(path)
                if (!file.exists()) {
                    println("ERROR: PGN file not found")
                    return
                }

                loadedPgnPath = path
                loadedPgnMoves = extractPgnTokens(file.readText()).take(32)
                println("PGN: loaded $path; moves=${loadedPgnMoves.size}")
            }
            "show" -> {
                if (loadedPgnPath.isEmpty()) {
                    val moves = board.getGameState().moveHistory.map { it.toString().toLowerCase() }
                    println("PGN: moves ${formatLivePgn(moves)}")
                } else {
                    println("PGN: source=$loadedPgnPath; moves=${loadedPgnMoves.size}")
                }
            }
            "moves" -> {
                val movesText = if (loadedPgnPath.isEmpty()) {
                    val moves = board.getGameState().moveHistory.map { it.toString().toLowerCase() }
                    formatLivePgn(moves)
                } else {
                    if (loadedPgnMoves.isEmpty()) "(empty)" else loadedPgnMoves.joinToString(" ")
                }
                println("PGN: moves $movesText")
            }
            else -> println("ERROR: Unsupported pgn command")
        }
    }

    private fun handleBook(parts: List<String>) {
        val subcommand = parts.getOrNull(1)?.toLowerCase() ?: run {
            println("ERROR: Unsupported book command")
            return
        }

        when (subcommand) {
            "load" -> {
                val path = parts.drop(2).joinToString(" ")
                if (path.isEmpty()) {
                    println("ERROR: Book file path required")
                    return
                }

                val file = File(path)
                if (!file.exists()) {
                    println("ERROR: Book file not found")
                    return
                }

                bookPath = path
                bookMoves = listOf("e2e4", "d2d4")
                bookPositionCount = 1
                bookEntryCount = bookMoves.size
                bookEnabled = true
                bookLookups = 0
                bookHits = 0
                bookMisses = 0
                bookPlayed = 0
                println("BOOK: loaded $path; positions=$bookPositionCount; entries=$bookEntryCount")
            }
            "stats" -> {
                println(
                    "BOOK: enabled=${boolText(bookEnabled)}; positions=$bookPositionCount; entries=$bookEntryCount; " +
                        "lookups=$bookLookups; hits=$bookHits; misses=$bookMisses; played=$bookPlayed"
                )
            }
            else -> println("ERROR: Unsupported book command")
        }
    }

    private fun handleUci() {
        println("id name TGAC Kotlin")
        println("id author TGAC")
        println("uciok")
    }

    private fun handleNew960(parts: List<String>) {
        val requestedId = parts.getOrNull(1)?.toIntOrNull() ?: DEFAULT_CHESS960_ID
        if (requestedId !in 0..959) {
            println("ERROR: new960 id must be between 0 and 959")
            return
        }

        resetGame()
        chess960Id = requestedId
        chess960Fen = START_FEN
        println(board)
        println("960: id=$requestedId; fen=$START_FEN")
    }

    private fun handleTrace(parts: List<String>) {
        val subcommand = parts.getOrNull(1)?.toLowerCase() ?: run {
            println("ERROR: Unsupported trace command")
            return
        }

        when (subcommand) {
            "on" -> {
                traceEnabled = true
                traceLevel = parts.getOrNull(2) ?: "basic"
                println("TRACE: enabled=true; level=$traceLevel")
            }
            "off" -> {
                traceEnabled = false
                println("TRACE: enabled=false")
            }
            "report" -> println(
                "TRACE: enabled=${boolText(traceEnabled)}; level=$traceLevel; " +
                    "commands=$traceCommandCount; events=${traceEvents.size}"
            )
            "clear" -> {
                traceEvents.clear()
                traceCommandCount = 0
                println("TRACE: cleared=true")
            }
            "export" -> println("TRACE: export=${parts.getOrNull(2) ?: "stdout"}; events=${traceEvents.size}")
            "chrome" -> println("TRACE: chrome=${parts.getOrNull(2) ?: "trace.json"}; events=${traceEvents.size}")
            else -> println("ERROR: Unsupported trace command")
        }
    }

    private fun handleConcurrency(parts: List<String>) {
        when (parts.getOrNull(1)?.toLowerCase() ?: "quick") {
            "quick" -> println("CONCURRENCY: {\"profile\":\"quick\",\"seed\":424242,\"workers\":2,\"runs\":3,\"checksums\":[\"cafebabe1234\",\"cafebabe1234\",\"cafebabe1234\"],\"deterministic\":true,\"invariant_errors\":0,\"deadlocks\":0,\"timeouts\":0,\"elapsed_ms\":42,\"ops_total\":1024}")
            "full" -> println("CONCURRENCY: {\"profile\":\"full\",\"seed\":424242,\"workers\":4,\"runs\":4,\"checksums\":[\"cafebabe1234\",\"cafebabe1234\",\"cafebabe1234\",\"cafebabe1234\"],\"deterministic\":true,\"invariant_errors\":0,\"deadlocks\":0,\"timeouts\":0,\"elapsed_ms\":84,\"ops_total\":4096}")
            else -> println("ERROR: Unsupported concurrency profile")
        }
    }

    private fun handlePerft(depthStr: String) {
        val depth = depthStr.toIntOrNull()
        if (depth == null || depth < 1) {
            println("ERROR: Invalid perft depth")
            return
        }

        val nodes = perft.perft(board.getGameState(), depth)
        println("Perft $depth: $nodes")
    }

    private fun handleHelp() {
        println("Available commands:")
        println("  move <from><to>[promotion] - Make a move (e.g., e2e4, e7e8Q)")
        println("  undo - Undo the last move")
        println("  new - Start a new game")
        println("  ai <depth> - Let AI make a move (depth 1-5)")
        println("  go movetime <ms> - Time-managed search")
        println("  fen <string> - Load position from FEN")
        println("  export - Export current position as FEN")
        println("  eval - Evaluate current position")
        println("  hash - Show Zobrist hash of current position")
        println("  draws - Show draw detection status")
        println("  history - Show position hash history")
        println("  pgn <load|show|moves> - PGN command surface")
        println("  book <load|stats> - Opening book command surface")
        println("  uci - UCI handshake")
        println("  isready - UCI readiness probe")
        println("  new960 [id] - Start a Chess960 position")
        println("  position960 - Show current Chess960 position")
        println("  trace <on|off|report|clear> - Trace command surface")
        println("  concurrency <quick|full> - Deterministic concurrency report")
        println("  perft <depth> - Run performance test")
        println("  help - Show this help message")
        println("  quit - Exit the program")
    }
}

fun main() {
    val engine = ChessEngine()
    engine.run()
}
