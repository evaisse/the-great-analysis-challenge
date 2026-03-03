"""
Perft (Performance Test) function for move generation validation
"""


function perft(board::Board, depth::Int)
    if depth == 0
        return 1
    end
    
    moves = get_legal_moves(board)
    count = 0
    
    for move in moves
        make_move!(board, move)
        count += perft(board, depth - 1)
        undo_move!(board)
    end
    
    return count
end

function perft_divide(board::Board, depth::Int)
    moves = get_legal_moves(board)
    total_count = 0
    
    for move in moves
        make_move!(board, move)
        count = perft(board, depth - 1)
        undo_move!(board)
        
        move_str = move_to_string(move)
        println("$move_str: $count")
        total_count += count
    end
    
    println("Total: $total_count")
    return total_count
end
