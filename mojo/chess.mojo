#!/usr/bin/env mojo
"""
Chess Engine Implementation in Mojo
Follows the Chess Engine Specification v1.0
"""

from lib.types import Move, Color, parse_move
from lib.board import Board
from lib.move_generator import MoveGenerator
from lib.ai import AI


fn main():
    """Main entry point."""
    print("Mojo Chess Engine v1.0")
    print("Type 'help' for available commands")
    print("")
    
    var board = Board()
    var move_generator = MoveGenerator()
    var ai = AI()
    
    print(board.display())
    
    # Simple command processing for demo
    print("")
    print("Demo: Making a move e2e4")
    var move = parse_move("e2e4")
    
    if move_generator.is_valid_move(board, move):
        if board.make_move(move):
            print("OK: e2e4")
            print(board.display())
        else:
            print("ERROR: Move execution failed")
    else:
        print("ERROR: Illegal move")
    
    print("")
    print("Demo: AI makes a move")
    var best_move = ai.get_best_move(board, 2)
    var move_str = best_move.to_algebraic()
    
    if move_generator.is_valid_move(board, best_move):
        if board.make_move(best_move):
            var eval_score = ai.evaluate_position(board)
            print("AI: " + move_str + " (depth=2, eval=" + str(eval_score) + ")")
            print(board.display())
        else:
            print("ERROR: AI move failed")
    else:
        print("ERROR: AI generated invalid move")
    
    print("")
    print("Chess engine demo completed successfully!")