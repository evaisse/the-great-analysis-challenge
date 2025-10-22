#!/usr/bin/env python3
"""
Chess Engine Implementation in Python
Follows the Chess Engine Specification v1.0
"""

import sys
from typing import Optional
from lib.board import Board
from lib.move_generator import MoveGenerator
from lib.fen_parser import FenParser
from lib.ai import AI
from lib.perft import Perft
from lib.types import Move


class ChessEngine:
    """Main chess engine class that handles user commands and game flow."""
    
    def __init__(self):
        self.board = Board()
        self.move_generator = MoveGenerator(self.board)
        self.fen_parser = FenParser(self.board)
        self.ai = AI(self.board, self.move_generator)
        self.perft = Perft(self.board, self.move_generator)
        self.move_history = []
    
    def start(self):
        """Start the chess engine and begin accepting commands."""
        print(self.board.display())
        sys.stdout.flush()
        
        while True:
            try:
                # Don't print prompt in non-interactive mode
                if sys.stdin.isatty():
                    print("\n> ", end="", flush=True)
                    
                line = sys.stdin.readline()
                if not line:
                    break
                
                command = line.strip()
                if not command:
                    continue
                    
                self.process_command(command)
                sys.stdout.flush()  # Ensure output is flushed
                
            except KeyboardInterrupt:
                print("\nGoodbye!")
                break
            except EOFError:
                break
    
    def process_command(self, command: str):
        """Process a user command."""
        try:
            parts = command.split()
            if not parts:
                return
                
            cmd = parts[0].lower()
            
            if cmd == 'move':
                self.handle_move(parts[1] if len(parts) > 1 else None)
            elif cmd == 'undo':
                self.handle_undo()
            elif cmd == 'new':
                self.handle_new_game()
            elif cmd == 'ai':
                depth = int(parts[1]) if len(parts) > 1 else 3
                self.handle_ai_move(depth)
            elif cmd == 'fen':
                fen = ' '.join(parts[1:]) if len(parts) > 1 else None
                self.handle_fen(fen)
            elif cmd == 'export':
                self.handle_export()
            elif cmd == 'eval':
                self.handle_eval()
            elif cmd == 'perft':
                depth = int(parts[1]) if len(parts) > 1 else 4
                self.handle_perft(depth)
            elif cmd == 'help':
                self.handle_help()
            elif cmd in ('quit', 'exit'):
                print('Goodbye!')
                sys.exit(0)
            else:
                print('ERROR: Invalid command. Type "help" for available commands.')
                
        except (ValueError, IndexError):
            print('ERROR: Invalid command format')
        except Exception as e:
            print(f'ERROR: {e}')
    
    def handle_move(self, move_str: Optional[str]):
        """Handle move command."""
        if not move_str:
            print('ERROR: Invalid move format')
            return
        
        try:
            move = Move.from_algebraic(move_str)
            if not move:
                print('ERROR: Invalid move format')
                return
            
            # Check if move is legal
            legal_moves = self.move_generator.generate_legal_moves()
            legal_move = None
            
            for legal in legal_moves:
                if (legal.from_row == move.from_row and
                    legal.from_col == move.from_col and
                    legal.to_row == move.to_row and
                    legal.to_col == move.to_col and
                    legal.promotion == move.promotion):
                    legal_move = legal
                    break
            
            if not legal_move:
                print('ERROR: Illegal move')
                return
            
            # Make the move
            self.move_history.append(legal_move)
            self.board.make_move(legal_move)
            
            print(f'OK: {move_str}')
            
            # Check for game end
            game_status = self.board.get_game_status()
            if game_status == 'checkmate':
                winner = 'Black' if self.board.to_move == 'white' else 'White'
                print(f'CHECKMATE: {winner} wins')
            elif game_status == 'stalemate':
                print('STALEMATE: Draw')
            
            # Display board
            print(self.board.display())
            
        except Exception as e:
            print(f'ERROR: {e}')
    
    def handle_undo(self):
        """Handle undo command."""
        if not self.move_history:
            print('ERROR: No moves to undo')
            return
        
        last_move = self.move_history.pop()
        self.board.undo_move(last_move)
        print('OK: undo')
        print(self.board.display())
    
    def handle_new_game(self):
        """Handle new game command."""
        self.board = Board()
        self.move_generator = MoveGenerator(self.board)
        self.fen_parser = FenParser(self.board)
        self.ai = AI(self.board, self.move_generator)
        self.perft = Perft(self.board, self.move_generator)
        self.move_history = []
        print('OK: New game started')
        print(self.board.display())
    
    def handle_ai_move(self, depth: int):
        """Handle AI move command."""
        if not (1 <= depth <= 5):
            print('ERROR: AI depth must be 1-5')
            return
        
        import time
        start_time = time.time()
        
        best_move, eval_score = self.ai.get_best_move(depth)
        
        end_time = time.time()
        elapsed_ms = int((end_time - start_time) * 1000)
        
        if not best_move:
            print('ERROR: No legal moves available')
            return
        
        # Make the AI move
        self.move_history.append(best_move)
        self.board.make_move(best_move)
        
        move_str = best_move.to_algebraic()
        print(f'AI: {move_str} (depth={depth}, eval={eval_score}, time={elapsed_ms}ms)')
        
        # Check for game end
        game_status = self.board.get_game_status()
        if game_status == 'checkmate':
            winner = 'Black' if self.board.to_move == 'white' else 'White'
            print(f'CHECKMATE: {winner} wins')
        elif game_status == 'stalemate':
            print('STALEMATE: Draw')
        
        print(self.board.display())
    
    def handle_fen(self, fen: Optional[str]):
        """Handle FEN command."""
        if not fen:
            print('ERROR: No FEN string provided')
            return
        
        try:
            self.fen_parser.parse(fen)
            self.move_history = []  # Clear move history when loading new position
            print(f'OK: Loaded position from FEN')
            print(self.board.display())
        except Exception as e:
            print(f'ERROR: Invalid FEN string: {e}')
    
    def handle_export(self):
        """Handle export command."""
        fen = self.fen_parser.export()
        print(f'FEN: {fen}')
    
    def handle_eval(self):
        """Handle eval command."""
        evaluation = self.ai.evaluate_position()
        print(f'Evaluation: {evaluation}')
    
    def handle_perft(self, depth: int):
        """Handle perft command."""
        if depth < 1 or depth > 6:
            print('ERROR: Perft depth must be 1-6')
            return
        
        import time
        start_time = time.time()
        
        node_count = self.perft.perft(depth)
        
        end_time = time.time()
        elapsed_ms = int((end_time - start_time) * 1000)
        
        print(f'Perft({depth}): {node_count} nodes in {elapsed_ms}ms')
    
    def handle_help(self):
        """Handle help command."""
        help_text = """
Available commands:
  move <from><to>[promotion] - Make a move (e.g., move e2e4, move e7e8Q)
  undo                       - Undo the last move
  new                        - Start a new game
  ai <depth>                 - AI makes a move (depth 1-5)
  fen <string>               - Load position from FEN
  export                     - Export current position as FEN
  eval                       - Display position evaluation
  perft <depth>              - Performance test (move count)
  help                       - Display this help
  quit                       - Exit the program
        """
        print(help_text.strip())


def main():
    """Main entry point."""
    engine = ChessEngine()
    engine.start()


if __name__ == '__main__':
    main()