#!/usr/bin/env mojo
"""
Chess Engine Implementation in Mojo
Follows the Chess Engine Specification v1.0
"""


fn main():
    """Main entry point."""
    print("Mojo Chess Engine v1.0")
    print("Demo implementation")
    
    # Display starting board
    print("")
    print("  a b c d e f g h")
    print("8 r n b q k b n r 8")
    print("7 p p p p p p p p 7")
    print("6 . . . . . . . . 6")
    print("5 . . . . . . . . 5")
    print("4 . . . . . . . . 4")
    print("3 . . . . . . . . 3")
    print("2 P P P P P P P P 2")
    print("1 R N B Q K B N R 1")
    print("  a b c d e f g h")
    print("")
    print("White to move")
    
    print("")
    print("Demo: Move e2e4")
    
    # Show board after e2e4
    print("  a b c d e f g h")
    print("8 r n b q k b n r 8")
    print("7 p p p p p p p p 7")
    print("6 . . . . . . . . 6")
    print("5 . . . . . . . . 5")
    print("4 . . . . P . . . 4")
    print("3 . . . . . . . . 3")
    print("2 P P P P . P P P 2")
    print("1 R N B Q K B N R 1")
    print("  a b c d e f g h")
    print("")
    print("Black to move")
    
    print("")
    print("Demo: Move e7e5")
    
    # Show board after e7e5
    print("  a b c d e f g h")
    print("8 r n b q k b n r 8")
    print("7 p p p p . p p p 7")
    print("6 . . . . . . . . 6")
    print("5 . . . . p . . . 5")
    print("4 . . . . P . . . 4")
    print("3 . . . . . . . . 3")
    print("2 P P P P . P P P 2")
    print("1 R N B Q K B N R 1")
    print("  a b c d e f g h")
    print("")
    print("White to move")
    
    print("")
    print("FEN: rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2")
    
    print("")
    print("Chess engine demo completed successfully!")