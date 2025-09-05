#!/usr/bin/env julia

"""
Chess Engine Main Program
Command-line interface for the Julia chess engine implementation
"""

include("src/types.jl")
include("src/board.jl")
include("src/move_generator.jl")
include("src/fen.jl")
include("src/ai.jl")
include("src/perft.jl")

mutable struct ChessEngine
    board::Board
    
    function ChessEngine()
        board = Board()
        setup_starting_position!(board)
        new(board)
    end
end

function process_command(engine::ChessEngine, command::String)
    parts = split(strip(command))
    
    if isempty(parts)
        return true
    end
    
    cmd = lowercase(parts[1])
    
    if cmd == "quit" || cmd == "exit"
        return false
    elseif cmd == "new"
        setup_starting_position!(engine.board)
        println(engine.board)
    elseif cmd == "move"
        if length(parts) != 2
            println("ERROR: Invalid move format")
            return true
        end
        
        move = parse_move(engine.board, parts[2])
        if move === nothing
            println("ERROR: Invalid move format")
            return true
        end
        
        legal_moves = get_legal_moves(engine.board)
        legal = false
        for legal_move in legal_moves
            if legal_move.from == move.from && legal_move.to == move.to && legal_move.promotion == move.promotion
                move = legal_move  # Use the properly constructed move
                legal = true
                break
            end
        end
        
        if !legal
            piece = get_piece(engine.board, move.from)
            if piece.type == EMPTY
                println("ERROR: No piece at source square")
            elseif piece.color != (engine.board.state.white_to_move ? WHITE : BLACK)
                println("ERROR: Wrong color piece")
            else
                println("ERROR: Illegal move")
            end
            return true
        end
        
        make_move!(engine.board, move)
        println("OK: $(move_to_string(move))")
        
        # Check for checkmate/stalemate
        new_legal_moves = get_legal_moves(engine.board)
        current_color = engine.board.state.white_to_move ? WHITE : BLACK
        
        if isempty(new_legal_moves)
            if is_in_check(engine.board, current_color)
                winner = current_color == WHITE ? "Black" : "White"
                println("CHECKMATE: $winner wins")
            else
                println("STALEMATE: Draw")
            end
        end
        
        println(engine.board)
    elseif cmd == "undo"
        if undo_move!(engine.board)
            println("OK: undo")
            println(engine.board)
        else
            println("ERROR: No move to undo")
        end
    elseif cmd == "fen"
        if length(parts) < 2
            println("ERROR: FEN string required")
            return true
        end
        
        fen_string = join(parts[2:end], " ")
        if parse_fen!(engine.board, fen_string)
            println("OK: FEN loaded")
            println(engine.board)
        else
            println("ERROR: Invalid FEN string")
        end
    elseif cmd == "export"
        fen = board_to_fen(engine.board)
        println("FEN: $fen")
    elseif cmd == "eval"
        evaluation = evaluate_position(engine.board)
        println("Evaluation: $evaluation")
    elseif cmd == "ai"
        if length(parts) != 2
            println("ERROR: AI depth required (1-5)")
            return true
        end
        
        try
            depth = parse(Int, parts[2])
            if depth < 1 || depth > 5
                println("ERROR: AI depth must be 1-5")
                return true
            end
            
            start_time = time()
            best_move, eval_score = find_best_move(engine.board, depth)
            elapsed_ms = round(Int, (time() - start_time) * 1000)
            
            if best_move === nothing
                println("ERROR: No legal moves available")
                return true
            end
            
            make_move!(engine.board, best_move)
            move_str = move_to_string(best_move)
            println("AI: $move_str (depth=$depth, eval=$eval_score, time=$(elapsed_ms)ms)")
            
            # Check for checkmate/stalemate
            new_legal_moves = get_legal_moves(engine.board)
            current_color = engine.board.state.white_to_move ? WHITE : BLACK
            
            if isempty(new_legal_moves)
                if is_in_check(engine.board, current_color)
                    winner = current_color == WHITE ? "Black" : "White"
                    println("CHECKMATE: $winner wins")
                else
                    println("STALEMATE: Draw")
                end
            end
            
            println(engine.board)
        catch
            println("ERROR: Invalid depth")
        end
    elseif cmd == "perft"
        if length(parts) != 2
            println("ERROR: Perft depth required")
            return true
        end
        
        try
            depth = parse(Int, parts[2])
            if depth < 1 || depth > 6
                println("ERROR: Perft depth must be 1-6")
                return true
            end
            
            start_time = time()
            count = perft(engine.board, depth)
            elapsed_ms = round(Int, (time() - start_time) * 1000)
            println("Perft($depth): $count ($(elapsed_ms)ms)")
        catch
            println("ERROR: Invalid depth")
        end
    elseif cmd == "help"
        println("Available commands:")
        println("  new           - Start a new game")
        println("  move <move>   - Make a move (e.g., e2e4)")
        println("  undo          - Undo the last move")
        println("  ai <depth>    - AI makes a move (depth 1-5)")
        println("  fen <string>  - Load position from FEN")
        println("  export        - Export current position as FEN")
        println("  eval          - Display position evaluation")
        println("  perft <depth> - Performance test (move count)")
        println("  help          - Display this help")
        println("  quit          - Exit the program")
    else
        println("ERROR: Invalid command")
    end
    
    return true
end

function main()
    engine = ChessEngine()
    println(engine.board)
    
    while true
        try
            line = readline()
            if !process_command(engine, line)
                break
            end
        catch InterruptException
            break
        catch e
            if isa(e, EOFError)
                break
            else
                rethrow()
            end
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end