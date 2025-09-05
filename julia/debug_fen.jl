include("src/types.jl")
include("src/board.jl")
include("src/move_generator.jl")
include("src/fen.jl")

# Test FEN generation
board = Board()
setup_starting_position!(board)

println("Initial: ", board_to_fen(board))

# e2e4
move = parse_move(board, "e2e4")
legal_moves = get_legal_moves(board)
for legal_move in legal_moves
    if legal_move.from == move.from && legal_move.to == move.to
        make_move!(board, legal_move)
        break
    end
end

println("After e2e4: ", board_to_fen(board))
println("En passant square: ", board.state.en_passant_square)
println("Halfmove clock: ", board.state.halfmove_clock)
println("Fullmove number: ", board.state.fullmove_number)

# e7e5  
move = parse_move(board, "e7e5")
legal_moves = get_legal_moves(board)
for legal_move in legal_moves
    if legal_move.from == move.from && legal_move.to == move.to
        make_move!(board, legal_move)
        break
    end
end

println("After e7e5: ", board_to_fen(board))
println("En passant square: ", board.state.en_passant_square)
println("Halfmove clock: ", board.state.halfmove_clock)
println("Fullmove number: ", board.state.fullmove_number)