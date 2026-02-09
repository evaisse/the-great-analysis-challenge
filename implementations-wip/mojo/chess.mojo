#!/usr/bin/env mojo
"""
Chess Engine Implementation in Mojo
Follows the Chess Engine Specification v1.0
"""

from lib.board import Board
from lib.move_generator import MoveGenerator
from lib.ai import ChessAI
from lib.perft import PerftCalculator
from lib.types import Move, Color


fn parse_command(command: String) -> (String, List[String]):
    """Parse a command line into command and arguments."""
    var parts = command.split()
    if len(parts) == 0:
        return ("", List[String]())
    
    var cmd = parts[0]
    var args = List[String]()
    for i in range(1, len(parts)):
        args.append(parts[i])
    
    return (cmd, args)


fn board_to_string(board: Board) -> String:
    """Convert board to visual string representation."""
    var result = "  a b c d e f g h\n"
    
    for rank in range(8):
        var row = 8 - rank
        result += str(row) + " "
        
        for file in range(8):
            var piece_code = board.get_piece_at(rank, file)
            var piece_char = "."
            
            if piece_code != 0:
                var piece_type = board.get_piece_type(piece_code)
                var is_white = board.get_piece_color(piece_code) == Color.WHITE()
                
                if piece_type == 1:  # Pawn
                    piece_char = "P" if is_white else "p"
                elif piece_type == 2:  # Knight
                    piece_char = "N" if is_white else "n"
                elif piece_type == 3:  # Bishop
                    piece_char = "B" if is_white else "b"
                elif piece_type == 4:  # Rook
                    piece_char = "R" if is_white else "r"
                elif piece_type == 5:  # Queen
                    piece_char = "Q" if is_white else "q"
                elif piece_type == 6:  # King
                    piece_char = "K" if is_white else "k"
            
            result += piece_char + " "
        
        result += str(row) + "\n"
    
    result += "  a b c d e f g h\n"
    return result


fn board_to_fen(board: Board) -> String:
    """Convert board to FEN string."""
    var fen = ""
    
    # Board position
    for rank in range(8):
        var empty_count = 0
        
        for file in range(8):
            var piece_code = board.get_piece_at(rank, file)
            
            if piece_code == 0:
                empty_count += 1
            else:
                if empty_count > 0:
                    fen += str(empty_count)
                    empty_count = 0
                
                var piece_type = board.get_piece_type(piece_code)
                var is_white = board.get_piece_color(piece_code) == Color.WHITE()
                
                var piece_char = "."
                if piece_type == 1:  # Pawn
                    piece_char = "P" if is_white else "p"
                elif piece_type == 2:  # Knight
                    piece_char = "N" if is_white else "n"
                elif piece_type == 3:  # Bishop
                    piece_char = "B" if is_white else "b"
                elif piece_type == 4:  # Rook
                    piece_char = "R" if is_white else "r"
                elif piece_type == 5:  # Queen
                    piece_char = "Q" if is_white else "q"
                elif piece_type == 6:  # King
                    piece_char = "K" if is_white else "k"
                
                fen += piece_char
        
        if empty_count > 0:
            fen += str(empty_count)
        
        if rank < 7:
            fen += "/"
    
    # Active color
    fen += " " + ("w" if board.to_move == Color.WHITE() else "b")
    
    # Castling rights
    var castling = ""
    if board.castling_rights.white_kingside:
        castling += "K"
    if board.castling_rights.white_queenside:
        castling += "Q"
    if board.castling_rights.black_kingside:
        castling += "k"
    if board.castling_rights.black_queenside:
        castling += "q"
    
    if len(castling) == 0:
        castling = "-"
    
    fen += " " + castling
    
    # En passant target
    if board.en_passant_target >= 0:
        var file_char = chr(ord('a') + (board.en_passant_target % 8))
        var rank_char = chr(ord('1') + (board.en_passant_target // 8))
        fen += " " + file_char + rank_char
    else:
        fen += " -"
    
    # Halfmove clock and fullmove number
    fen += " " + str(board.halfmove_clock) + " " + str(board.fullmove_number)
    
    return fen


fn parse_move(move_str: String) -> Move:
    """Parse algebraic notation move (e.g. e2e4, e7e8q)."""
    if len(move_str) < 4:
        return Move(0, 0, 0, 0)  # Invalid move
    
    var from_file = ord(move_str[0]) - ord('a')
    var from_rank = ord(move_str[1]) - ord('1')
    var to_file = ord(move_str[2]) - ord('a')
    var to_rank = ord(move_str[3]) - ord('1')
    
    var move = Move(from_rank, from_file, to_rank, to_file)
    
    # Check for promotion
    if len(move_str) >= 5:
        var promo_char = move_str[4].lower()
        if promo_char == 'n':
            move.promotion = 2  # Knight
        elif promo_char == 'b':
            move.promotion = 3  # Bishop
        elif promo_char == 'r':
            move.promotion = 4  # Rook
        elif promo_char == 'q':
            move.promotion = 5  # Queen
    
    return move


fn main():
    """Main entry point - interactive chess engine."""
    print("Mojo Chess Engine v1.0")
    print("Type 'help' for available commands")
    print("")
    
    var board = Board()
    var move_gen = MoveGenerator()
    var ai = ChessAI()
    var perft_calc = PerftCalculator()
    
    # Main command loop
    while True:
        try:
            var input_line = input("> ")
            var command, args = parse_command(input_line.strip())
            
            if command == "help":
                print("Available commands:")
                print("  help - Show this help message")
                print("  display - Show current board position")
                print("  fen - Output current position in FEN notation")
                print("  move <move> - Make a move (e.g., e2e4, e7e8Q)")
                print("  perft <depth> - Run performance test")
                print("  ai - Make an AI move")
                print("  quit - Exit the program")
                print("")
            
            elif command == "display":
                print(board_to_string(board))
            
            elif command == "fen":
                print(board_to_fen(board))
                print("")
            
            elif command == "move":
                if len(args) == 0:
                    print("ERROR: Move required")
                    print("")
                    continue
                
                var move = parse_move(args[0])
                if move_gen.is_valid_move(board, move):
                    if board.make_move(move):
                        print("OK: " + args[0])
                        print(board_to_string(board))
                    else:
                        print("ERROR: Failed to make move " + args[0])
                        print("")
                else:
                    print("ERROR: Invalid move " + args[0])
                    print("")
            
            elif command == "perft":
                if len(args) == 0:
                    print("ERROR: Depth required")
                    print("")
                    continue
                
                try:
                    var depth = int(args[0])
                    if depth < 0 or depth > 6:
                        print("ERROR: Depth must be between 0 and 6")
                        print("")
                        continue
                    
                    print("Running perft " + str(depth) + "...")
                    var nodes = perft_calc.perft(board, depth)
                    print("Perft " + str(depth) + ": " + str(nodes) + " nodes")
                    print("")
                
                except:
                    print("ERROR: Invalid depth")
                    print("")
            
            elif command == "ai":
                var best_move = ai.get_best_move(board, move_gen, 3)
                if best_move.from_row >= 0:  # Valid move found
                    var move_str = ""
                    move_str += chr(ord('a') + best_move.from_col)
                    move_str += chr(ord('1') + best_move.from_rank)
                    move_str += chr(ord('a') + best_move.to_col)
                    move_str += chr(ord('1') + best_move.to_rank)
                    
                    if board.make_move(best_move):
                        print("AI: " + move_str)
                        print(board_to_string(board))
                    else:
                        print("ERROR: AI move failed")
                        print("")
                else:
                    print("ERROR: No AI move available")
                    print("")
            
            elif command == "quit":
                print("Goodbye!")
                break
            
            elif command == "":
                continue  # Empty line
            
            else:
                print("ERROR: Unknown command '" + command + "'. Type 'help' for available commands.")
                print("")
        
        except:
            print("ERROR: Input error")
            print("")