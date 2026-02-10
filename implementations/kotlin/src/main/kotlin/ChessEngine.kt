// Main chess engine with CLI interface

class ChessEngine {
    private val board = Board()
    private val moveGenerator = MoveGenerator()
    private val fenParser = FenParser()
    private val ai = AI()
    private val perft = Perft()
    
    fun run() {
        // println(board) // Removed to avoid duplicate display when 'new' is received
        
        while (true) {
            val input = readLine()?.trim() ?: break
            
            if (input.isEmpty()) continue
            
            if (!processCommand(input)) {
                break
            }
        }
    }
    
    private fun processCommand(command: String): Boolean {
        val parts = command.trim().split(Regex("\\s+"))
        if (parts.isEmpty() || parts[0].isEmpty()) return true
        
        val cmd = parts[0].toUpperCase()
        
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
        board.reset()
        println("OK: New game started")
        println(board)
    }
    
    private fun handleAi(depthStr: String) {
        val depth = depthStr.toIntOrNull()
        if (depth == null || depth < 1 || depth > 5) {
            println("ERROR: AI depth must be 1-5")
            return
        }
        
        val turn = board.getTurn()
        val result = ai.findBestMove(board, depth)
        
        if (result.bestMove != null) {
            val moveStr = result.bestMove.toString().toLowerCase()
            board.makeMove(result.bestMove)
            
            val nextTurn = board.getTurn()
            val nextLegalMoves = moveGenerator.getLegalMoves(board.getGameState(), nextTurn)
            
            if (nextLegalMoves.isEmpty()) {
                if (moveGenerator.isInCheck(board.getGameState(), nextTurn)) {
                    println("AI: $moveStr (CHECKMATE)")
                } else {
                    println("AI: $moveStr (STALEMATE)")
                }
            } else {
                println("AI: $moveStr (depth=$depth, eval=${result.evaluation}, time=${result.timeMs})")
            }
            println(board)
        } else {
            println("ERROR: No legal moves available")
        }
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
        println("REPETITION: ${board.isDrawByRepetition()}")
        println("50-MOVE RULE: ${board.isDrawByFiftyMoveRule()}")
        println("OK: clock=${board.getGameState().halfmoveClock}")
    }

    private fun handleHistory() {
        val state = board.getGameState()
        println("Position History (${state.positionHistory.size + 1} positions):")
        for ((index, hash) in state.positionHistory.withIndex()) {
            println("  $index: ${String.format("%016x", hash)}")
        }
        println("  ${state.positionHistory.size}: ${String.format("%016x", state.zobristHash)} (current)")
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
        println("  fen <string> - Load position from FEN")
        println("  export - Export current position as FEN")
        println("  eval - Evaluate current position")
        println("  perft <depth> - Run performance test")
        println("  help - Show this help message")
        println("  quit - Exit the program")
    }
}

fun main() {
    val engine = ChessEngine()
    engine.run()
}