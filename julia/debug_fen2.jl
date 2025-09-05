include("src/types.jl")
include("src/board.jl")
include("src/move_generator.jl")
include("src/fen.jl")

# Test FEN generation step by step
board = Board()
setup_starting_position!(board)

println("Initial state:")
println("  White to move: ", board.state.white_to_move)
println("  Fullmove: ", board.state.fullmove_number)
println("  Halfmove: ", board.state.halfmove_clock)
println("  FEN: ", board_to_fen(board))
println()

# Make e2e4 manually
from_square = algebraic_to_square("e2")  # 12
to_square = algebraic_to_square("e4")    # 28
piece = get_piece(board, from_square)
move = Move(from_square, to_square, piece, EMPTY_PIECE)

println("Making move e2e4:")
println("  From square: ", from_square, " (", square_to_algebraic(from_square), ")")
println("  To square: ", to_square, " (", square_to_algebraic(to_square), ")")

make_move!(board, move)

println("After e2e4:")
println("  White to move: ", board.state.white_to_move)
println("  Fullmove: ", board.state.fullmove_number)
println("  Halfmove: ", board.state.halfmove_clock)
println("  En passant: ", board.state.en_passant_square)
println("  FEN: ", board_to_fen(board))
println()

# Make e7e5 manually
from_square = algebraic_to_square("e7")  # 52
to_square = algebraic_to_square("e5")    # 36
piece = get_piece(board, from_square)
move = Move(from_square, to_square, piece, EMPTY_PIECE)

println("Making move e7e5:")
println("  From square: ", from_square, " (", square_to_algebraic(from_square), ")")
println("  To square: ", to_square, " (", square_to_algebraic(to_square), ")")

make_move!(board, move)

println("After e7e5:")
println("  White to move: ", board.state.white_to_move)
println("  Fullmove: ", board.state.fullmove_number)
println("  Halfmove: ", board.state.halfmove_clock)
println("  En passant: ", board.state.en_passant_square)
println("  FEN: ", board_to_fen(board))