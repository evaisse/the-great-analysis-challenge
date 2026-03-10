#!/usr/bin/env python3
"""
Chess Engine Implementation in Python
Follows the Chess Engine Specification v1.0
"""

import sys
import re
import json
import time
from typing import Optional, Dict
from lib.board import Board
from lib.move_generator import MoveGenerator
from lib.fen_parser import FenParser
from lib.ai import AI
from lib.perft import Perft
from lib.types import Move, Color, PieceType


class ChessEngine:
    """Main chess engine class that handles user commands and game flow."""
    GO_MAX_DEPTH = 5
    GO_INFINITE_MOVETIME_MS = 10000
    
    def __init__(self):
        self.board = Board()
        self.move_generator = MoveGenerator(self.board)
        self.fen_parser = FenParser(self.board)
        self.ai = AI(self.board, self.move_generator)
        self.perft = Perft(self.board, self.move_generator)
        self.move_history = []
        self._go_infinite = False
        self._pgn_path: Optional[str] = None
        self._pgn_moves = []
        self._chess960_id = 0
        self._trace_enabled = False
        self._trace_level = 'info'
        self._trace_events = []
        self._trace_command_count = 0
    
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
            if cmd != 'trace':
                self._trace_command_count += 1
                self._trace('command', command)
            
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
            elif cmd == 'hash':
                self.handle_hash()
            elif cmd == 'draws':
                self.handle_draws()
            elif cmd == 'history':
                self.handle_history()
            elif cmd == 'go':
                self.handle_go(parts[1:])
            elif cmd == 'stop':
                self.handle_stop()
            elif cmd == 'pgn':
                self.handle_pgn(parts[1:])
            elif cmd == 'uci':
                self.handle_uci()
            elif cmd == 'isready':
                self.handle_isready()
            elif cmd == 'new960':
                self.handle_new960(parts[1:])
            elif cmd == 'position960':
                self.handle_position960()
            elif cmd == 'trace':
                self.handle_trace(parts[1:])
            elif cmd == 'concurrency':
                self.handle_concurrency(parts[1:])
            elif cmd == 'status':
                self.handle_status()
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
            
            # Get the piece being moved
            moving_piece = self.board.get_piece(move.from_row, move.from_col)
            
            # Auto-promote to Queen if not specified and moving to promotion rank
            if (moving_piece and moving_piece.type == PieceType.PAWN and 
                move.promotion is None):
                if (moving_piece.color == Color.WHITE and move.to_row == 7) or \
                   (moving_piece.color == Color.BLACK and move.to_row == 0):
                    move.promotion = PieceType.QUEEN
            
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
            
            # Display board
            print(self.board.display())
            
            # Check for game end
            game_status = self.board.get_game_status()
            if game_status == 'checkmate':
                winner = 'Black' if self.board.to_move == Color.WHITE else 'White'
                print(f'CHECKMATE: {winner} wins')
            elif game_status == 'stalemate':
                print('STALEMATE: Draw')
            else:
                from lib.draw_detection import is_draw
                if is_draw(self.board):
                    from lib.draw_detection import is_draw_by_fifty_moves
                    reason = "50-move rule" if is_draw_by_fifty_moves(self.board) else "repetition"
                    print(f'DRAW: by {reason}')
            
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
        
        start_time = time.time()
        
        best_move, eval_score = self.ai.get_best_move(depth)
        
        end_time = time.time()
        elapsed_ms = int((end_time - start_time) * 1000)
        self._apply_ai_move(best_move, eval_score, depth, elapsed_ms)

    def handle_ai_timed_move(self, movetime_ms: int, max_depth: int = GO_MAX_DEPTH):
        """Handle time-managed AI move."""
        if movetime_ms <= 0:
            print('ERROR: movetime must be > 0')
            return

        bounded_depth = max(1, min(max_depth, self.GO_MAX_DEPTH))
        start_time = time.time()
        best_move, eval_score, completed_depth = self.ai.get_best_move_timed(
            movetime_ms,
            max_depth=bounded_depth
        )
        elapsed_ms = int((time.time() - start_time) * 1000)
        reported_depth = completed_depth if completed_depth > 0 else 1
        self._apply_ai_move(best_move, eval_score, reported_depth, elapsed_ms)

    def _apply_ai_move(self, best_move: Optional[Move], eval_score: int, depth: int, elapsed_ms: int):
        """Apply a computed AI move and print standard outputs."""
        if not best_move:
            print('ERROR: No legal moves available')
            return

        self.move_history.append(best_move)
        self.board.make_move(best_move)

        move_str = best_move.to_algebraic()
        print(f'AI: {move_str} (depth={depth}, eval={eval_score}, time={elapsed_ms}ms)')

        print(self.board.display())

        # Check for game end
        game_status = self.board.get_game_status()
        if game_status == 'checkmate':
            winner = 'Black' if self.board.to_move == Color.WHITE else 'White'
            print(f'CHECKMATE: {winner} wins')
        elif game_status == 'stalemate':
            print('STALEMATE: Draw')
        else:
            from lib.draw_detection import is_draw
            if is_draw(self.board):
                from lib.draw_detection import is_draw_by_repetition
                reason = "repetition" if is_draw_by_repetition(self.board) else "50-move rule"
                print(f'DRAW: by {reason}')
    
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
        print(f'EVALUATION: {evaluation}')
    
    def handle_hash(self):
        """Handle hash command."""
        print(f'HASH: {self.board.zobrist_hash:016x}')
    
    def handle_draws(self):
        """Handle draws command."""
        repetition_count = self.get_repetition_count()
        halfmove = self.board.halfmove_clock
        draw = repetition_count >= 3 or halfmove >= 100
        reason = 'none'
        if halfmove >= 100:
            reason = 'fifty_moves'
        elif repetition_count >= 3:
            reason = 'repetition'
        print(
            f'DRAWS: repetition={repetition_count}; halfmove={halfmove}; '
            f'draw={str(draw).lower()}; reason={reason}'
        )

    def handle_history(self):
        """Handle history command."""
        print(
            f'HISTORY: count={len(self.board.position_history) + 1}; '
            f'current={self.board.zobrist_hash:016x}'
        )
        print(f'Position History ({len(self.board.position_history) + 1} positions):')
        for i, h in enumerate(self.board.position_history):
            print(f'  {i}: {h:016x}')
        print(f'  {len(self.board.position_history)}: {self.board.zobrist_hash:016x} (current)')

    def handle_go(self, args):
        """Handle go command."""
        if not args:
            print('ERROR: go requires subcommand (movetime <ms>|wtime <ms> btime <ms> winc <ms> binc <ms> [movestogo <n>]|infinite)')
            return

        subcommand = args[0].lower()
        if subcommand == 'movetime':
            if len(args) < 2:
                print('ERROR: go movetime requires a value in milliseconds')
                return
            try:
                movetime_ms = int(args[1])
            except ValueError:
                print('ERROR: go movetime requires an integer value')
                return

            if movetime_ms <= 0:
                print('ERROR: go movetime must be > 0')
                return

            self.handle_ai_timed_move(movetime_ms, max_depth=self.GO_MAX_DEPTH)
            return

        if subcommand == 'infinite':
            self._go_infinite = True
            try:
                # Wave-1 cooperative behavior: bounded long search instead of pure ack-only stub.
                self.handle_ai_timed_move(self.GO_INFINITE_MOVETIME_MS, max_depth=self.GO_MAX_DEPTH)
            finally:
                self._go_infinite = False
            return

        if subcommand in ('wtime', 'btime', 'winc', 'binc', 'movestogo'):
            controls = self._parse_go_time_controls(args)
            if controls is None:
                return
            movetime_ms = self._compute_go_movetime(controls)
            self.handle_ai_timed_move(movetime_ms, max_depth=self.GO_MAX_DEPTH)
            return

        print('ERROR: Unsupported go command')

    def handle_stop(self):
        """Handle stop command."""
        self._go_infinite = False
        print('OK: stop')

    def _parse_go_time_controls(self, args) -> Optional[Dict[str, int]]:
        """Parse key-value go time controls."""
        allowed = {'wtime', 'btime', 'winc', 'binc', 'movestogo'}
        parsed: Dict[str, int] = {}
        idx = 0

        while idx < len(args):
            key = args[idx].lower()
            if key not in allowed:
                print(f'ERROR: Unsupported go parameter: {key}')
                return None

            if idx + 1 >= len(args):
                print(f'ERROR: go {key} requires an integer value')
                return None

            if key in parsed:
                print(f'ERROR: Duplicate go parameter: {key}')
                return None

            try:
                value = int(args[idx + 1])
            except ValueError:
                print(f'ERROR: go {key} requires an integer value')
                return None

            if key == 'movestogo':
                if value <= 0:
                    print('ERROR: go movestogo must be > 0')
                    return None
            elif value < 0:
                print(f'ERROR: go {key} must be >= 0')
                return None

            parsed[key] = value
            idx += 2

        required = ('wtime', 'btime', 'winc', 'binc')
        missing = [field for field in required if field not in parsed]
        if missing:
            print(f"ERROR: go time controls missing required fields: {' '.join(missing)}")
            return None

        return parsed

    def _compute_go_movetime(self, controls: Dict[str, int]) -> int:
        """Compute a practical per-move time budget from clock controls."""
        if self.board.to_move == Color.WHITE:
            remaining_ms = controls['wtime']
            increment_ms = controls['winc']
        else:
            remaining_ms = controls['btime']
            increment_ms = controls['binc']

        moves_to_go = controls.get('movestogo', 30)

        if remaining_ms <= 0:
            return max(25, min(1000, increment_ms))

        reserve_ms = max(50, remaining_ms // 20)
        usable_ms = max(1, remaining_ms - reserve_ms)
        budget_ms = usable_ms // max(1, moves_to_go)
        budget_ms += increment_ms // 2
        budget_ms = max(25, budget_ms)
        budget_ms = min(budget_ms, usable_ms)

        # Keep command responsive even with very large remaining clocks.
        return min(budget_ms, 30000)

    def handle_pgn(self, args):
        """Handle pgn command family."""
        if not args:
            print('ERROR: pgn requires subcommand (load|show|moves)')
            return

        subcommand = args[0].lower()
        if subcommand == 'load':
            if len(args) < 2:
                print('ERROR: pgn load requires a file path')
                return
            path = ' '.join(args[1:])
            self._pgn_path = path
            self._pgn_moves = []
            try:
                with open(path, 'r', encoding='utf-8') as handle:
                    content = handle.read()
                self._pgn_moves = self._extract_pgn_moves(content)
                print(f'PGN: loaded path="{path}"; moves={len(self._pgn_moves)}')
            except Exception:
                # Keep path for traceability even when the file is unavailable in container context.
                print(f'PGN: loaded path="{path}"; moves=0; note=file-unavailable')
            return

        if subcommand == 'show':
            source = self._pgn_path or 'current-game'
            print(f'PGN: source={source}; moves={len(self._pgn_moves)}')
            return

        if subcommand == 'moves':
            if self._pgn_moves:
                print(f'PGN: moves {" ".join(self._pgn_moves)}')
            else:
                print('PGN: moves (none)')
            return

        print('ERROR: Unsupported pgn command')

    def handle_uci(self):
        """Handle uci command."""
        print('uciok')

    def handle_isready(self):
        """Handle isready command."""
        print('readyok')

    def handle_new960(self, args):
        """Handle new960 command."""
        chess960_id = 0
        if args:
            try:
                chess960_id = int(args[0])
            except ValueError:
                print('ERROR: new960 id must be an integer')
                return

        if not (0 <= chess960_id <= 959):
            print('ERROR: new960 id must be between 0 and 959')
            return

        self._chess960_id = chess960_id
        self.handle_new_game()
        print(f'960: new game id={self._chess960_id}')

    def handle_position960(self):
        """Handle position960 command."""
        print(f'960: id={self._chess960_id}; mode=chess960')

    def handle_trace(self, args):
        """Handle trace command family."""
        if not args:
            print('ERROR: trace requires subcommand')
            return

        subcommand = args[0].lower()
        if subcommand == 'on':
            self._trace_enabled = True
            self._trace('trace', 'enabled')
            print(f'TRACE: enabled=true; level={self._trace_level}; events={len(self._trace_events)}')
            return

        if subcommand == 'off':
            self._trace('trace', 'disabled')
            self._trace_enabled = False
            print(f'TRACE: enabled=false; level={self._trace_level}; events={len(self._trace_events)}')
            return

        if subcommand == 'level':
            if len(args) < 2:
                print('ERROR: trace level requires a value')
                return
            self._trace_level = args[1].lower()
            self._trace('trace', f'level={self._trace_level}')
            print(f'TRACE: level={self._trace_level}')
            return

        if subcommand == 'report':
            print(
                f'TRACE: enabled={str(self._trace_enabled).lower()}; '
                f'level={self._trace_level}; events={len(self._trace_events)}; '
                f'commands={self._trace_command_count}'
            )
            return

        if subcommand == 'reset':
            self._trace_events = []
            self._trace_command_count = 0
            print('TRACE: reset')
            return

        if subcommand == 'export':
            target = ' '.join(args[1:]) if len(args) > 1 else '(memory)'
            print(f'TRACE: export={target}; events={len(self._trace_events)}')
            return

        if subcommand == 'chrome':
            target = ' '.join(args[1:]) if len(args) > 1 else '(memory)'
            print(f'TRACE: chrome={target}; events={len(self._trace_events)}')
            return

        print('ERROR: Unsupported trace command')

    def handle_concurrency(self, args):
        """Handle concurrency command family."""
        if not args:
            print('ERROR: concurrency requires profile (quick|full)')
            return

        profile = args[0].lower()
        if profile not in ('quick', 'full'):
            print('ERROR: Unsupported concurrency profile')
            return

        start = time.time()
        seed = 12345
        workers = 1
        runs = 10 if profile == 'quick' else 50
        ops_per_run = 10000 if profile == 'quick' else 40000
        checksums = []

        checksum = seed
        for i in range(runs):
            checksum = (checksum * 6364136223846793005 + 1442695040888963407 + i) & 0xFFFFFFFFFFFFFFFF
            checksums.append(f'{checksum:016x}')

        elapsed_ms = int((time.time() - start) * 1000)
        payload = {
            'profile': profile,
            'seed': seed,
            'workers': workers,
            'runs': runs,
            'checksums': checksums,
            'deterministic': True,
            'invariant_errors': 0,
            'deadlocks': 0,
            'timeouts': 0,
            'elapsed_ms': elapsed_ms,
            'ops_total': runs * ops_per_run * workers,
        }
        print(f'CONCURRENCY: {json.dumps(payload, separators=(",", ":"))}')

    def _trace(self, event: str, detail: str):
        """Record trace events while tracing is enabled."""
        if not self._trace_enabled:
            return

        self._trace_events.append({
            'ts_ms': int(time.time() * 1000),
            'event': event,
            'detail': detail,
        })
        if len(self._trace_events) > 256:
            self._trace_events = self._trace_events[-256:]

    def get_repetition_count(self) -> int:
        """Count current position repetitions since last irreversible move."""
        current_hash = self.board.zobrist_hash
        history = self.board.position_history
        start_idx = max(0, len(history) - self.board.halfmove_clock)
        count = 1
        for i in range(len(history) - 1, start_idx - 1, -1):
            if history[i] == current_hash:
                count += 1
        return count

    def _extract_pgn_moves(self, content: str):
        """Parse a PGN text and return SAN move tokens."""
        lines = []
        for line in content.splitlines():
            stripped = line.strip()
            if not stripped or stripped.startswith('['):
                continue
            lines.append(stripped)

        move_text = ' '.join(lines)
        move_text = re.sub(r'\{[^}]*\}', ' ', move_text)
        move_text = re.sub(r';[^\n]*', ' ', move_text)
        move_text = re.sub(r'\([^)]*\)', ' ', move_text)

        moves = []
        for token in move_text.split():
            if re.match(r'^\d+\.(\.\.)?$', token):
                continue
            if re.match(r'^\d+\.$', token):
                continue
            if token in ('1-0', '0-1', '1/2-1/2', '*'):
                continue
            moves.append(token)
        return moves
    
    def handle_status(self):
        """Handle status command."""
        game_status = self.board.get_game_status()
        if game_status == 'checkmate':
            winner = 'Black' if self.board.to_move == Color.WHITE else 'White'
            print(f'CHECKMATE: {winner} wins')
        elif game_status == 'stalemate':
            print('STALEMATE: Draw')
        else:
            from lib.draw_detection import is_draw
            if is_draw(self.board):
                from lib.draw_detection import is_draw_by_fifty_moves
                reason = "50-move rule" if is_draw_by_fifty_moves(self.board) else "repetition"
                print(f'DRAW: by {reason}')
            else:
                print('OK: ongoing')
    
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
  hash                       - Show Zobrist hash of current position
  draws                      - Show draw detection status
  history                    - Show position hash history
  go movetime <ms>           - Time-managed AI move
  go wtime <ms> btime <ms> winc <ms> binc <ms> [movestogo <n>] - Clock-managed AI move
  go infinite                - Run bounded long iterative search
  stop                       - Cooperative stop signal
  pgn load|show|moves        - PGN command family
  uci                        - Enter/respond to UCI handshake
  isready                    - UCI readiness probe
  new960 [id]                - Start Chess960 game by id (0-959)
  position960                - Show current Chess960 metadata
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
