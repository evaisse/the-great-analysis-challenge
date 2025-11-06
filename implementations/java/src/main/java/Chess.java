import java.util.Scanner;

public class Chess {
    private Board board;
    private Scanner scanner;

    public Chess() {
        this.board = new Board();
        this.scanner = new Scanner(System.in);
    }

    public static void main(String[] args) {
        Chess chess = new Chess();
        chess.run();
    }

    public void run() {
        board.display();
        
        while (true) {
            String line = scanner.nextLine().trim();
            if (line.isEmpty()) continue;
            
            String[] parts = line.split("\\s+");
            String command = parts[0].toLowerCase();
            
            try {
                switch (command) {
                    case "new":
                        board = new Board();
                        board.display();
                        break;
                        
                    case "move":
                        if (parts.length < 2) {
                            System.out.println("ERROR: Invalid move format");
                            break;
                        }
                        handleMove(parts[1]);
                        break;
                        
                    case "undo":
                        if (board.undo()) {
                            board.display();
                        } else {
                            System.out.println("ERROR: No moves to undo");
                        }
                        break;
                        
                    case "export":
                        System.out.println("FEN: " + board.toFEN());
                        break;
                        
                    case "fen":
                        if (parts.length < 2) {
                            System.out.println("ERROR: Invalid FEN string");
                            break;
                        }
                        String fen = line.substring(4).trim();
                        if (board.fromFEN(fen)) {
                            board.display();
                        } else {
                            System.out.println("ERROR: Invalid FEN string");
                        }
                        break;
                        
                    case "ai":
                        if (parts.length < 2) {
                            System.out.println("ERROR: AI depth must be 1-5");
                            break;
                        }
                        try {
                            int depth = Integer.parseInt(parts[1]);
                            if (depth < 1 || depth > 5) {
                                System.out.println("ERROR: AI depth must be 1-5");
                                break;
                            }
                            handleAI(depth);
                        } catch (NumberFormatException e) {
                            System.out.println("ERROR: AI depth must be 1-5");
                        }
                        break;
                        
                    case "eval":
                        int eval = board.evaluate();
                        System.out.println("Evaluation: " + eval);
                        break;
                        
                    case "perft":
                        if (parts.length < 2) {
                            System.out.println("ERROR: Invalid perft depth");
                            break;
                        }
                        try {
                            int depth = Integer.parseInt(parts[1]);
                            long startTime = System.currentTimeMillis();
                            long nodes = board.perft(depth);
                            long elapsed = System.currentTimeMillis() - startTime;
                            System.out.println(nodes + " (time=" + elapsed + "ms)");
                        } catch (NumberFormatException e) {
                            System.out.println("ERROR: Invalid perft depth");
                        }
                        break;
                        
                    case "help":
                        showHelp();
                        break;
                        
                    case "quit":
                    case "exit":
                        return;
                        
                    default:
                        System.out.println("ERROR: Invalid command");
                        break;
                }
            } catch (Exception e) {
                System.out.println("ERROR: " + e.getMessage());
            }
        }
    }

    private void handleMove(String moveStr) {
        Move move = board.parseMove(moveStr);
        if (move == null) {
            System.out.println("ERROR: Invalid move format");
            return;
        }
        
        if (board.makeMove(move)) {
            System.out.println("OK: " + moveStr);
            board.display();
            
            GameState state = board.getGameState();
            if (state == GameState.CHECKMATE) {
                String winner = board.isWhiteTurn() ? "Black" : "White";
                System.out.println("CHECKMATE: " + winner + " wins");
            } else if (state == GameState.STALEMATE) {
                System.out.println("STALEMATE: Draw");
            }
        } else {
            System.out.println("ERROR: Illegal move");
        }
    }

    private void handleAI(int depth) {
        long startTime = System.currentTimeMillis();
        Move bestMove = AI.findBestMove(board, depth);
        long elapsed = System.currentTimeMillis() - startTime;
        
        if (bestMove == null) {
            System.out.println("ERROR: No legal moves available");
            return;
        }
        
        int eval = board.evaluate();
        board.makeMove(bestMove);
        
        System.out.println("AI: " + bestMove.toString() + " (depth=" + depth + ", eval=" + eval + ", time=" + elapsed + "ms)");
        board.display();
        
        GameState state = board.getGameState();
        if (state == GameState.CHECKMATE) {
            String winner = board.isWhiteTurn() ? "Black" : "White";
            System.out.println("CHECKMATE: " + winner + " wins");
        } else if (state == GameState.STALEMATE) {
            System.out.println("STALEMATE: Draw");
        }
    }

    private void showHelp() {
        System.out.println("Available commands:");
        System.out.println("  new                 - Start a new game");
        System.out.println("  move <from><to>     - Make a move (e.g., move e2e4)");
        System.out.println("  move <from><to><p>  - Make a move with promotion (e.g., move e7e8Q)");
        System.out.println("  undo                - Undo the last move");
        System.out.println("  export              - Export current position as FEN");
        System.out.println("  fen <string>        - Load position from FEN");
        System.out.println("  ai <depth>          - AI makes a move (depth 1-5)");
        System.out.println("  eval                - Display position evaluation");
        System.out.println("  perft <depth>       - Performance test (move count)");
        System.out.println("  help                - Display this help message");
        System.out.println("  quit                - Exit the program");
    }
}
