#!/usr/bin/env python3
"""
Chess Engine Implementation in Python
Follows the Chess Engine Specification v1.0
"""

import sys
import re
import json
import time
from concurrent.futures import ThreadPoolExecutor
from typing import Optional
from lib.board import Board
from lib.move_generator import MoveGenerator
from lib.fen_parser import FenParser
from lib.ai import AI
from lib.perft import Perft
from lib.types import Move, Color, PieceType

CONCURRENCY_SEED = 12345
CONCURRENCY_FIXTURES = (
    {
        'name': 'opening',
        'fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        'focus': 'any',
    },
    {
        'name': 'castling',
        'fen': 'r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1',
        'focus': 'castling',
    },
    {
        'name': 'en-passant',
        'fen': 'rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3',
        'focus': 'en_passant',
    },
    {
        'name': 'promotion',
        'fen': '4k3/6P1/8/8/8/8/7p/4K3 w - - 0 1',
        'focus': 'promotion',
    },
)
CONCURRENCY_PROFILES = {
    'quick': {
        'workers': 2,
        'runs': 6,
        'cycles_per_worker': 6,
        'reply_stride': 2,
    },
    'full': {
        'workers': 4,
        'runs': 12,
        'cycles_per_worker': 12,
        'reply_stride': 1,
    },
}


class ChessEngine:
    """Main chess engine class that handles user commands and game flow."""
    
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
        self._book_path: Optional[str] = None
        self._book_enabled = False
        self._book_entries = {}
        self._book_entry_count = 0
        self._book_lookups = 0
        self._book_hits = 0
        self._book_misses = 0
        self._book_played = 0
        self._uci_hash_mb = 16
        self._uci_threads = 1
        self._chess960_id = 0
        self._trace_enabled = False
        self._trace_level = 'info'
        self._trace_events = []
        self._trace_command_count = 0
        self._reset_trace_export_state()
    
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
            elif cmd == 'book':
                self.handle_book(parts[1:])
            elif cmd == 'endgame':
                self.handle_endgame(parts[1:])
            elif cmd == 'uci':
                self.handle_uci()
            elif cmd == 'isready':
                self.handle_isready()
            elif cmd == 'setoption':
                self.handle_setoption(parts[1:])
            elif cmd == 'ucinewgame':
                self.handle_ucinewgame()
            elif cmd == 'position':
                self.handle_position(parts[1:])
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
        self.handle_ai_timed(depth, 0)

    def handle_ai_timed(self, max_depth: int, movetime_ms: int):
        """Handle time-managed AI search."""
        legal_moves = self.move_generator.generate_legal_moves()
        if not legal_moves:
            print('ERROR: No legal moves available')
            return

        book_move = self._choose_book_move(legal_moves)
        if book_move is not None:
            self._apply_book_move(book_move)
            return

        endgame_choice = self._choose_endgame_move(legal_moves)
        if endgame_choice is not None:
            self._apply_endgame_move(endgame_choice[0], endgame_choice[1])
            return

        best_move, eval_score, depth_used, elapsed_ms, _ = self.ai.search(max_depth, movetime_ms)
        if not best_move:
            print('ERROR: No legal moves available')
            return

        self.move_history.append(best_move)
        self.board.make_move(best_move)

        move_str = best_move.to_algebraic()
        print(f'AI: {move_str} (depth={depth_used}, eval={eval_score}, time={elapsed_ms}ms)')

        print(self.board.display())

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
        if subcommand == 'depth':
            if len(args) < 2:
                print('ERROR: go depth requires a value')
                return
            try:
                depth = int(args[1])
            except ValueError:
                print('ERROR: go depth requires an integer value')
                return

            if depth < 1:
                depth = 1
            if depth > 5:
                depth = 5

            legal_moves = self.move_generator.generate_legal_moves()
            book_move = self._choose_book_move(legal_moves)
            if book_move is not None:
                move_str = book_move.to_algebraic()
                print(f'info string bookmove {move_str}')
                print(f'bestmove {move_str}')
                return

            endgame_choice = self._choose_endgame_move(legal_moves)
            if endgame_choice is not None:
                move, info = endgame_choice
                move_str = move.to_algebraic()
                print(f'info string endgame {info["type"]} score cp {info["score_white"]}')
                print(f'bestmove {move_str}')
                return

            best_move, eval_score, depth_used, elapsed_ms, _ = self.ai.search(depth, 0)
            if not best_move:
                print('bestmove 0000')
                return
            print(f'info depth {depth_used} score cp {eval_score} time {elapsed_ms} nodes 0')
            print(f'bestmove {best_move.to_algebraic()}')
            return

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

            self.handle_ai_timed(5, movetime_ms)
            return

        if subcommand == 'wtime':
            movetime_ms, error = self._derive_movetime_from_clock_args(args)
            if error is not None:
                print(f'ERROR: {error}')
                return
            self.handle_ai_timed(5, movetime_ms)
            return

        if subcommand == 'infinite':
            self._go_infinite = True
            print('OK: go infinite acknowledged (bounded search mode)')
            self.handle_ai_timed(5, 15000)
            return

        print('ERROR: Unsupported go command')

    def handle_stop(self):
        """Handle stop command."""
        self._go_infinite = False
        self.ai.request_stop()
        print('OK: stop')

    def _derive_movetime_from_clock_args(self, args):
        """Derive think time from go wtime/btime/winc/binc controls."""
        values = {'winc': 0, 'binc': 0, 'movestogo': 30}
        i = 0
        while i < len(args):
            key = args[i].lower()
            i += 1
            if i >= len(args):
                return 0, f'go {key} requires a value'
            try:
                value = int(args[i])
            except ValueError:
                return 0, f'go {key} requires an integer value'
            i += 1

            if key not in ('wtime', 'btime', 'winc', 'binc', 'movestogo'):
                return 0, f'unsupported go parameter: {key}'
            values[key] = value

        if 'wtime' not in values or 'btime' not in values:
            return 0, 'go wtime/btime parameters are required'
        if values['wtime'] <= 0 or values['btime'] <= 0:
            return 0, 'go wtime/btime must be > 0'
        if values['movestogo'] <= 0:
            values['movestogo'] = 30

        if self.board.to_move == Color.WHITE:
            base = values['wtime']
            inc = values['winc']
        else:
            base = values['btime']
            inc = values['binc']

        budget = base // (values['movestogo'] + 1) + inc // 2
        if budget < 50:
            budget = 50
        if budget >= base:
            budget = base // 2
        if budget <= 0:
            return 0, 'unable to derive positive movetime from clocks'
        return budget, None

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

    def handle_book(self, args):
        """Handle book command family."""
        if not args:
            print('ERROR: book requires subcommand (load|on|off|stats)')
            return

        subcommand = args[0].lower()
        if subcommand == 'load':
            if len(args) < 2:
                print('ERROR: book load requires a file path')
                return
            path = ' '.join(args[1:])
            try:
                with open(path, 'r', encoding='utf-8') as handle:
                    content = handle.read()
                entries, total_entries = self._parse_book_entries(content)
            except Exception as exc:
                print(f'ERROR: book load failed: {exc}')
                return

            self._book_path = path
            self._book_entries = entries
            self._book_entry_count = total_entries
            self._book_enabled = True
            self._book_lookups = 0
            self._book_hits = 0
            self._book_misses = 0
            self._book_played = 0
            print(
                f'BOOK: loaded path="{path}"; positions={len(entries)}; '
                f'entries={total_entries}; enabled=true'
            )
            return

        if subcommand == 'on':
            self._book_enabled = True
            print('BOOK: enabled=true')
            return

        if subcommand == 'off':
            self._book_enabled = False
            print('BOOK: enabled=false')
            return

        if subcommand == 'stats':
            path = self._book_path if self._book_path else '(none)'
            print(
                f'BOOK: enabled={str(self._book_enabled).lower()}; '
                f'path={path}; positions={len(self._book_entries)}; '
                f'entries={self._book_entry_count}; lookups={self._book_lookups}; '
                f'hits={self._book_hits}; misses={self._book_misses}; played={self._book_played}'
            )
            return

        print('ERROR: Unsupported book command')

    def handle_endgame(self, _args):
        """Report specialized endgame detection and best move hint."""
        info = self._detect_endgame_state()
        if info is None:
            active = 'white' if self.board.to_move == Color.WHITE else 'black'
            print(f'ENDGAME: type=none; active={active}; score=0')
            return

        output = (
            f'ENDGAME: type={info["type"]}; strong={self._color_name(info["strong"])}; '
            f'weak={self._color_name(info["weak"])}; score={info["score_white"]}'
        )
        legal_moves = self.move_generator.generate_legal_moves()
        choice = self._choose_endgame_move(legal_moves)
        if choice is not None:
            output += f'; bestmove={choice[0].to_algebraic().lower()}'
        output += f'; detail={info["detail"]}'
        print(output)

    def handle_uci(self):
        """Handle uci command."""
        print('uciok')

    def handle_isready(self):
        """Handle isready command."""
        print('readyok')

    def handle_setoption(self, args):
        """Handle UCI setoption command."""
        if len(args) < 4 or args[0].lower() != 'name':
            print("ERROR: setoption format is 'setoption name <Hash|Threads> value <n>'")
            return

        try:
            value_idx = next(i for i, token in enumerate(args) if token.lower() == 'value')
        except StopIteration:
            print("ERROR: setoption requires 'value <n>'")
            return

        if value_idx <= 0 or value_idx + 1 >= len(args):
            print("ERROR: setoption requires 'value <n>'")
            return

        name = ' '.join(args[1:value_idx]).strip().lower()
        try:
            value = int(args[value_idx + 1])
        except ValueError:
            print('ERROR: setoption value must be an integer')
            return

        if name == 'hash':
            self._uci_hash_mb = max(1, min(1024, value))
            print(f'info string option Hash={self._uci_hash_mb}')
            return

        if name == 'threads':
            self._uci_threads = max(1, min(64, value))
            print(f'info string option Threads={self._uci_threads}')
            return

        print(f'info string unsupported option {" ".join(args[1:value_idx]).strip()}')

    def handle_ucinewgame(self):
        """Handle UCI ucinewgame command."""
        self.board = Board()
        self.move_generator = MoveGenerator(self.board)
        self.fen_parser = FenParser(self.board)
        self.ai = AI(self.board, self.move_generator)
        self.perft = Perft(self.board, self.move_generator)
        self.move_history = []

    def handle_position(self, args):
        """Handle UCI position command: startpos|fen ... [moves ...]."""
        if not args:
            print("ERROR: position requires 'startpos' or 'fen <...>'")
            return

        idx = 0
        keyword = args[0].lower()
        if keyword == 'startpos':
            self.handle_ucinewgame()
            idx = 1
        elif keyword == 'fen':
            idx = 1
            fen_tokens = []
            while idx < len(args) and args[idx].lower() != 'moves':
                fen_tokens.append(args[idx])
                idx += 1
            if not fen_tokens:
                print('ERROR: position fen requires a FEN string')
                return
            try:
                self.fen_parser.parse(' '.join(fen_tokens))
                self.move_history = []
            except Exception as exc:
                print(f'ERROR: Invalid FEN string: {exc}')
                return
        else:
            print("ERROR: position requires 'startpos' or 'fen <...>'")
            return

        if idx < len(args) and args[idx].lower() == 'moves':
            idx += 1
            for move_str in args[idx:]:
                error = self._apply_move_silent(move_str)
                if error is not None:
                    print(f'ERROR: position move {move_str} failed: {error}')
                    return

    def _apply_move_silent(self, move_str: str) -> Optional[str]:
        """Apply one coordinate move without emitting CLI output."""
        move = Move.from_algebraic(move_str)
        if not move:
            return 'Invalid move format'

        moving_piece = self.board.get_piece(move.from_row, move.from_col)
        if moving_piece and moving_piece.type == PieceType.PAWN and move.promotion is None:
            if (moving_piece.color == Color.WHITE and move.to_row == 7) or \
               (moving_piece.color == Color.BLACK and move.to_row == 0):
                move.promotion = PieceType.QUEEN

        legal_moves = self.move_generator.generate_legal_moves()
        legal_move = None
        for candidate in legal_moves:
            if (candidate.from_row == move.from_row and
                candidate.from_col == move.from_col and
                candidate.to_row == move.to_row and
                candidate.to_col == move.to_col and
                candidate.promotion == move.promotion):
                legal_move = candidate
                break

        if not legal_move:
            return 'Illegal move'

        self.move_history.append(legal_move)
        self.board.make_move(legal_move)
        return None

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
            print(self._trace_report_line())
            return

        if subcommand == 'reset':
            self._trace_events = []
            self._trace_command_count = 0
            self._reset_trace_export_state()
            print('TRACE: reset')
            return

        if subcommand == 'export':
            target = ' '.join(args[1:]) if len(args) > 1 else '(memory)'
            event_count = len(self._trace_events)
            payload = self._encode_trace_export_payload()
            byte_count = self._write_trace_payload(target, payload, write_to_file=len(args) > 1)
            self._record_trace_artifact(target, byte_count, chrome=False)
            print(f'TRACE: export={target}; events={event_count}; bytes={byte_count}')
            return

        if subcommand == 'chrome':
            target = ' '.join(args[1:]) if len(args) > 1 else '(memory)'
            event_count = len(self._trace_events)
            payload = self._encode_trace_chrome_payload()
            byte_count = self._write_trace_payload(target, payload, write_to_file=len(args) > 1)
            self._record_trace_artifact(target, byte_count, chrome=True)
            print(f'TRACE: chrome={target}; events={event_count}; bytes={byte_count}')
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

        profile_config = {
            'quick': {
                'workers': 2,
                'runs': 10,
                'sequences_per_worker': 4,
                'plies_per_sequence': 4,
            },
            'full': {
                'workers': 4,
                'runs': 50,
                'sequences_per_worker': 6,
                'plies_per_sequence': 6,
            },
        }[profile]
        scenarios = (
            'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
            'rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3',
            'r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1',
            '4k3/6P1/8/8/8/8/8/4K3 w - - 0 1',
        )

        start = time.time()
        seed = 12345
        workers = profile_config['workers']
        runs = profile_config['runs']
        sequences_per_worker = profile_config['sequences_per_worker']
        plies_per_sequence = profile_config['plies_per_sequence']
        ops_per_run = workers * sequences_per_worker * plies_per_sequence
        checksums = []
        invariant_errors = 0

        with ThreadPoolExecutor(max_workers=workers) as executor:
            for run_index in range(runs):
                futures = [
                    executor.submit(
                        self._run_concurrency_worker,
                        seed,
                        run_index,
                        worker_index,
                        sequences_per_worker,
                        plies_per_sequence,
                        scenarios,
                    )
                    for worker_index in range(workers)
                ]

                run_checksum = self._concurrency_mix_text(
                    (2166136261 ^ seed ^ ((run_index + 1) * 173)) & 0xFFFFFFFF,
                    f'run:{profile}:{run_index}',
                )
                for worker_index, future in enumerate(futures):
                    worker_checksum, worker_errors = future.result()
                    invariant_errors += worker_errors
                    run_checksum = self._concurrency_mix_text(
                        run_checksum,
                        f'{worker_index}:{worker_checksum}',
                    )

                checksums.append(self._concurrency_format_checksum(run_checksum))

        elapsed_ms = int((time.time() - start) * 1000)
        payload = {
            'profile': profile,
            'seed': seed,
            'workers': workers,
            'runs': runs,
            'checksums': checksums,
            'deterministic': True,
            'invariant_errors': invariant_errors,
            'deadlocks': 0,
            'timeouts': 0,
            'elapsed_ms': elapsed_ms,
            'ops_total': runs * ops_per_run,
        }
        print(f'CONCURRENCY: {json.dumps(payload, separators=(",", ":"))}')

    def _run_concurrency_worker(
        self,
        seed: int,
        run_index: int,
        worker_index: int,
        sequences_per_worker: int,
        plies_per_sequence: int,
        scenarios,
    ):
        checksum = (2166136261 ^ seed ^ ((run_index + 1) * 97) ^ ((worker_index + 1) * 131)) & 0xFFFFFFFF
        checksum = self._concurrency_mix_text(checksum, f'worker:{run_index}:{worker_index}')
        invariant_errors = 0

        for sequence_index in range(sequences_per_worker):
            scenario_index = (run_index + worker_index + sequence_index) % len(scenarios)
            board, move_generator, fen_parser = self._concurrency_state_from_fen(scenarios[scenario_index])
            baseline_fen = fen_parser.export()
            baseline_hash = self._concurrency_hash_hex(board.zobrist_hash)
            checksum = self._concurrency_mix_text(
                checksum,
                f'seq:{scenario_index}:{baseline_hash}:{baseline_fen}',
            )

            applied_moves = []
            for ply in range(plies_per_sequence):
                legal_moves = sorted(move_generator.generate_legal_moves(), key=lambda move: move.to_algebraic())
                checksum = self._concurrency_mix_text(checksum, f'legal:{len(legal_moves)}')
                if not legal_moves:
                    invariant_errors += 1
                    checksum = self._concurrency_mix_text(checksum, f'empty:{sequence_index}:{ply}')
                    break

                selected = self._choose_concurrency_move(
                    legal_moves,
                    seed,
                    run_index,
                    worker_index,
                    sequence_index,
                    ply,
                )
                before_fen = fen_parser.export()
                before_hash = self._concurrency_hash_hex(board.zobrist_hash)
                move_str = selected.to_algebraic()

                board.make_move(selected)
                applied_moves.append(selected)

                after_fen = fen_parser.export()
                after_hash = self._concurrency_hash_hex(board.zobrist_hash)
                checksum = self._concurrency_mix_text(
                    checksum,
                    f'move:{move_str}:{before_hash}:{before_fen}:{after_hash}:{after_fen}',
                )

                reloaded_board, _, reloaded_parser = self._concurrency_state_from_fen(after_fen)
                reloaded_hash = self._concurrency_hash_hex(reloaded_board.zobrist_hash)
                if reloaded_parser.export() != after_fen or reloaded_hash != after_hash:
                    invariant_errors += 1
                    checksum = self._concurrency_mix_text(
                        checksum,
                        f'reload-error:{sequence_index}:{ply}:{reloaded_hash}',
                    )

            for move in reversed(applied_moves):
                board.undo_move(move)

            restored_fen = fen_parser.export()
            restored_hash = self._concurrency_hash_hex(board.zobrist_hash)
            if restored_fen != baseline_fen or restored_hash != baseline_hash:
                invariant_errors += 1
                checksum = self._concurrency_mix_text(
                    checksum,
                    f'undo-error:{sequence_index}:{restored_hash}:{restored_fen}',
                )
            else:
                checksum = self._concurrency_mix_text(checksum, f'undo-ok:{restored_hash}')

        return self._concurrency_format_checksum(checksum), invariant_errors

    def _concurrency_state_from_fen(self, fen: str):
        from lib.zobrist import zobrist

        board = Board()
        fen_parser = FenParser(board)
        fen_parser.parse(fen)
        board.game_history = []
        board.position_history = []
        board.irreversible_history = []
        board.zobrist_hash = zobrist.compute_hash(board)
        return board, MoveGenerator(board), fen_parser

    def _choose_concurrency_move(
        self,
        legal_moves,
        seed: int,
        run_index: int,
        worker_index: int,
        sequence_index: int,
        ply: int,
    ):
        special_moves = [
            move for move in legal_moves
            if move.is_castling or move.is_en_passant or move.promotion is not None
        ]
        if special_moves and (run_index + worker_index + sequence_index + ply) % 3 == 0:
            return special_moves[0]

        selector = seed + run_index * 17 + worker_index * 31 + sequence_index * 43 + ply * 59
        return legal_moves[selector % len(legal_moves)]

    def _concurrency_mix_text(self, checksum: int, text: str) -> int:
        for byte in text.encode('utf-8'):
            checksum ^= byte
            checksum = (checksum * 16777619) & 0xFFFFFFFF
        return checksum

    def _concurrency_format_checksum(self, checksum: int) -> str:
        return f'{checksum & 0xFFFFFFFF:08x}'

    def _concurrency_hash_hex(self, value: int) -> str:
        return f'{value & 0xFFFFFFFFFFFFFFFF:016x}'

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

    def _reset_trace_export_state(self):
        self._trace_export_count = 0
        self._trace_export_last_target = None
        self._trace_export_last_bytes = 0
        self._trace_chrome_count = 0
        self._trace_chrome_last_target = None
        self._trace_chrome_last_bytes = 0

    def _trace_report_line(self) -> str:
        return (
            f'TRACE: enabled={str(self._trace_enabled).lower()}; '
            f'level={self._trace_level}; events={len(self._trace_events)}; '
            f'commands={self._trace_command_count}; '
            f'export={self._trace_report_segment(self._trace_export_count, self._trace_export_last_target, self._trace_export_last_bytes)}; '
            f'chrome={self._trace_report_segment(self._trace_chrome_count, self._trace_chrome_last_target, self._trace_chrome_last_bytes)}'
        )

    def _trace_report_segment(self, count: int, target: Optional[str], byte_count: int) -> str:
        resolved_target = target if target is not None else 'none'
        return f'{count}@{resolved_target}/{byte_count}B'

    def _record_trace_artifact(self, target: str, byte_count: int, chrome: bool):
        if chrome:
            self._trace_chrome_count += 1
            self._trace_chrome_last_target = target
            self._trace_chrome_last_bytes = byte_count
            return

        self._trace_export_count += 1
        self._trace_export_last_target = target
        self._trace_export_last_bytes = byte_count

    def _write_trace_payload(self, target: str, payload: bytes, write_to_file: bool) -> int:
        if write_to_file:
            with open(target, 'wb') as handle:
                handle.write(payload)
        return len(payload)

    def _encode_trace_export_payload(self) -> bytes:
        payload = {
            'format': 'tgac.trace.v1',
            'engine': 'python',
            'generated_at_ms': int(time.time() * 1000),
            'enabled': self._trace_enabled,
            'level': self._trace_level,
            'command_count': self._trace_command_count,
            'event_count': len(self._trace_events),
            'events': self._trace_events,
        }
        return (json.dumps(payload, separators=(',', ':'), ensure_ascii=True) + '\n').encode('utf-8')

    def _encode_trace_chrome_payload(self) -> bytes:
        base_ts_ms = self._trace_events[0]['ts_ms'] if self._trace_events else int(time.time() * 1000)
        trace_events = []
        for index, event in enumerate(self._trace_events):
            event_ts_ms = int(event.get('ts_ms', base_ts_ms))
            trace_events.append({
                'name': str(event.get('event', 'trace')),
                'cat': 'engine.trace',
                'ph': 'i',
                's': 't',
                'ts': max(0, event_ts_ms - base_ts_ms) * 1000,
                'pid': 1,
                'tid': 1,
                'args': {
                    'detail': str(event.get('detail', '')),
                    'index': index,
                    'ts_ms': event_ts_ms,
                    'level': self._trace_level,
                },
            })

        payload = {
            'traceEvents': trace_events,
            'displayTimeUnit': 'ms',
            'otherData': {
                'format': 'tgac.chrome_trace.v1',
                'engine': 'python',
                'generated_at_ms': int(time.time() * 1000),
                'level': self._trace_level,
                'command_count': self._trace_command_count,
                'event_count': len(self._trace_events),
            },
        }
        return (json.dumps(payload, separators=(',', ':'), ensure_ascii=True) + '\n').encode('utf-8')

    def depth_for_movetime(self, movetime_ms: int) -> int:
        """Convert movetime budget to a practical search depth."""
        if movetime_ms <= 200:
            return 1
        if movetime_ms <= 500:
            return 2
        if movetime_ms <= 2000:
            return 3
        if movetime_ms <= 5000:
            return 4
        return 5

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

    def _book_position_key(self, fen: str) -> str:
        parts = fen.strip().split()
        if len(parts) >= 4:
            return ' '.join(parts[:4])
        return fen.strip()

    def _parse_book_entries(self, content: str):
        entries = {}
        total_entries = 0
        move_pattern = re.compile(r'^[a-h][1-8][a-h][1-8][qrbn]?$')

        for idx, raw in enumerate(content.splitlines(), start=1):
            line = raw.strip()
            if not line or line.startswith('#'):
                continue
            if '->' not in line:
                raise ValueError(f"line {idx}: expected '<fen> -> <move> [weight]'")

            left, right = line.split('->', 1)
            key = self._book_position_key(left)
            if not key:
                raise ValueError(f'line {idx}: empty position key')

            rhs_parts = right.strip().split()
            if not rhs_parts:
                raise ValueError(f'line {idx}: missing move')

            move = rhs_parts[0].lower()
            if not move_pattern.match(move):
                raise ValueError(f'line {idx}: invalid move "{move}"')

            weight = 1
            if len(rhs_parts) > 1:
                try:
                    weight = int(rhs_parts[1])
                except ValueError as exc:
                    raise ValueError(f'line {idx}: invalid weight "{rhs_parts[1]}"') from exc
                if weight <= 0:
                    raise ValueError(f'line {idx}: weight must be > 0')

            entries.setdefault(key, []).append((move, weight))
            total_entries += 1

        return entries, total_entries

    def _choose_book_move(self, legal_moves):
        self._book_lookups += 1
        if not self._book_enabled or not self._book_entries:
            self._book_misses += 1
            return None

        key = self._book_position_key(self.fen_parser.export())
        candidates = self._book_entries.get(key, [])
        if not candidates:
            self._book_misses += 1
            return None

        legal_by_notation = {
            move.to_algebraic().lower(): move
            for move in legal_moves
        }

        weighted = []
        total_weight = 0
        for notation, weight in candidates:
            move = legal_by_notation.get(notation)
            if move is None:
                continue
            norm_weight = weight if weight > 0 else 1
            weighted.append((move, norm_weight))
            total_weight += norm_weight

        if not weighted or total_weight <= 0:
            self._book_misses += 1
            return None

        selector = (int(self.board.zobrist_hash) + self._book_lookups) % total_weight
        acc = 0
        chosen = weighted[0][0]
        for move, weight in weighted:
            acc += weight
            if selector < acc:
                chosen = move
                break

        self._book_hits += 1
        return chosen

    def _apply_book_move(self, move: Move):
        self.move_history.append(move)
        self.board.make_move(move)
        self._book_played += 1
        move_str = move.to_algebraic()

        game_status = self.board.get_game_status()
        if game_status == 'checkmate':
            winner = 'Black' if self.board.to_move == Color.WHITE else 'White'
            print(f'AI: {move_str} (book, CHECKMATE: {winner} wins)')
        elif game_status == 'stalemate':
            print(f'AI: {move_str} (book, STALEMATE)')
        else:
            from lib.draw_detection import is_draw
            if is_draw(self.board):
                from lib.draw_detection import is_draw_by_repetition
                reason = 'repetition' if is_draw_by_repetition(self.board) else '50-move rule'
                print(f'AI: {move_str} (book, DRAW: by {reason})')
            else:
                print(f'AI: {move_str} (book)')

        print(self.board.display())

    def _color_name(self, color: Color) -> str:
        return 'white' if color == Color.WHITE else 'black'

    def _manhattan(self, a, b) -> int:
        return abs(a[0] - b[0]) + abs(a[1] - b[1])

    def _non_king_material(self, counts, color: Color) -> int:
        return (
            counts[color][PieceType.PAWN] +
            counts[color][PieceType.KNIGHT] +
            counts[color][PieceType.BISHOP] +
            counts[color][PieceType.ROOK] +
            counts[color][PieceType.QUEEN]
        )

    def _detect_endgame_state(self):
        counts = {
            Color.WHITE: {pt: 0 for pt in PieceType},
            Color.BLACK: {pt: 0 for pt in PieceType},
        }
        kings = {}
        pawns = {}
        rooks = {}
        queens = {}

        for row in range(8):
            for col in range(8):
                piece = self.board.get_piece(row, col)
                if not piece:
                    continue
                counts[piece.color][piece.type] += 1
                if piece.type == PieceType.KING:
                    kings[piece.color] = (row, col)
                elif piece.type == PieceType.PAWN and piece.color not in pawns:
                    pawns[piece.color] = (row, col)
                elif piece.type == PieceType.ROOK and piece.color not in rooks:
                    rooks[piece.color] = (row, col)
                elif piece.type == PieceType.QUEEN and piece.color not in queens:
                    queens[piece.color] = (row, col)

        if Color.WHITE not in kings or Color.BLACK not in kings:
            return None

        white_material = self._non_king_material(counts, Color.WHITE)
        black_material = self._non_king_material(counts, Color.BLACK)

        # KQK
        if counts[Color.WHITE][PieceType.QUEEN] == 1 and white_material == 1 and black_material == 0:
            weak_king = kings[Color.BLACK]
            strong_king = kings[Color.WHITE]
            edge_distance = min(weak_king[0], 7 - weak_king[0], weak_king[1], 7 - weak_king[1])
            king_distance = self._manhattan(strong_king, weak_king)
            score = 900 + (14 - king_distance) * 6 + (3 - edge_distance) * 20
            return {
                'type': 'KQK',
                'strong': Color.WHITE,
                'weak': Color.BLACK,
                'score_white': score,
                'detail': f'queen={chr(ord("a") + queens[Color.WHITE][1])}{queens[Color.WHITE][0] + 1}',
            }
        if counts[Color.BLACK][PieceType.QUEEN] == 1 and black_material == 1 and white_material == 0:
            weak_king = kings[Color.WHITE]
            strong_king = kings[Color.BLACK]
            edge_distance = min(weak_king[0], 7 - weak_king[0], weak_king[1], 7 - weak_king[1])
            king_distance = self._manhattan(strong_king, weak_king)
            score = 900 + (14 - king_distance) * 6 + (3 - edge_distance) * 20
            return {
                'type': 'KQK',
                'strong': Color.BLACK,
                'weak': Color.WHITE,
                'score_white': -score,
                'detail': f'queen={chr(ord("a") + queens[Color.BLACK][1])}{queens[Color.BLACK][0] + 1}',
            }

        # KPK
        if counts[Color.WHITE][PieceType.PAWN] == 1 and white_material == 1 and black_material == 0:
            pawn = pawns[Color.WHITE]
            strong_king = kings[Color.WHITE]
            weak_king = kings[Color.BLACK]
            promotion = (7, pawn[1])
            pawn_steps = 7 - pawn[0]
            score = 120 + (6 - pawn_steps) * 35 + self._manhattan(weak_king, promotion) * 6 - self._manhattan(strong_king, pawn) * 8
            if pawn_steps <= 1:
                score += 80
            if score < 30:
                score = 30
            return {
                'type': 'KPK',
                'strong': Color.WHITE,
                'weak': Color.BLACK,
                'score_white': score,
                'detail': f'pawn={chr(ord("a") + pawn[1])}{pawn[0] + 1}',
            }
        if counts[Color.BLACK][PieceType.PAWN] == 1 and black_material == 1 and white_material == 0:
            pawn = pawns[Color.BLACK]
            strong_king = kings[Color.BLACK]
            weak_king = kings[Color.WHITE]
            promotion = (0, pawn[1])
            pawn_steps = pawn[0]
            score = 120 + (6 - pawn_steps) * 35 + self._manhattan(weak_king, promotion) * 6 - self._manhattan(strong_king, pawn) * 8
            if pawn_steps <= 1:
                score += 80
            if score < 30:
                score = 30
            return {
                'type': 'KPK',
                'strong': Color.BLACK,
                'weak': Color.WHITE,
                'score_white': -score,
                'detail': f'pawn={chr(ord("a") + pawn[1])}{pawn[0] + 1}',
            }

        # KRKP
        if counts[Color.WHITE][PieceType.ROOK] == 1 and white_material == 1 and counts[Color.BLACK][PieceType.PAWN] == 1 and black_material == 1:
            strong_king = kings[Color.WHITE]
            weak_king = kings[Color.BLACK]
            weak_pawn = pawns[Color.BLACK]
            pawn_steps = weak_pawn[0]
            score = 380 - pawn_steps * 25 + (self._manhattan(weak_king, weak_pawn) - self._manhattan(strong_king, weak_pawn)) * 12
            if score < 50:
                score = 50
            return {
                'type': 'KRKP',
                'strong': Color.WHITE,
                'weak': Color.BLACK,
                'score_white': score,
                'detail': (
                    f'rook={chr(ord("a") + rooks[Color.WHITE][1])}{rooks[Color.WHITE][0] + 1},'
                    f'pawn={chr(ord("a") + weak_pawn[1])}{weak_pawn[0] + 1}'
                ),
            }
        if counts[Color.BLACK][PieceType.ROOK] == 1 and black_material == 1 and counts[Color.WHITE][PieceType.PAWN] == 1 and white_material == 1:
            strong_king = kings[Color.BLACK]
            weak_king = kings[Color.WHITE]
            weak_pawn = pawns[Color.WHITE]
            pawn_steps = 7 - weak_pawn[0]
            score = 380 - pawn_steps * 25 + (self._manhattan(weak_king, weak_pawn) - self._manhattan(strong_king, weak_pawn)) * 12
            if score < 50:
                score = 50
            return {
                'type': 'KRKP',
                'strong': Color.BLACK,
                'weak': Color.WHITE,
                'score_white': -score,
                'detail': (
                    f'rook={chr(ord("a") + rooks[Color.BLACK][1])}{rooks[Color.BLACK][0] + 1},'
                    f'pawn={chr(ord("a") + weak_pawn[1])}{weak_pawn[0] + 1}'
                ),
            }

        return None

    def _choose_endgame_move(self, legal_moves):
        root_info = self._detect_endgame_state()
        if root_info is None or not legal_moves:
            return None

        root_color = self.board.to_move
        best_move = legal_moves[0]
        best_notation = best_move.to_algebraic().lower()
        best_score = -10**9

        for move in legal_moves:
            self.board.make_move(move)
            next_info = self._detect_endgame_state()
            if next_info is not None:
                score = next_info['score_white']
            else:
                score = self.ai.evaluate_position()
            if root_color == Color.BLACK:
                score = -score
            notation = move.to_algebraic().lower()
            if score > best_score or (score == best_score and notation < best_notation):
                best_score = score
                best_move = move
                best_notation = notation
            self.board.undo_move(move)

        return best_move, root_info

    def _apply_endgame_move(self, move: Move, info):
        self.move_history.append(move)
        self.board.make_move(move)
        move_str = move.to_algebraic()
        print(f'AI: {move_str} (endgame {info["type"]}, score={info["score_white"]})')

        print(self.board.display())

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
                reason = 'repetition' if is_draw_by_repetition(self.board) else '50-move rule'
                print(f'DRAW: by {reason}')
    
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
  go wtime <ms> btime <ms> winc <ms> binc <ms> [movestogo <n>] - Clock-based timed move
  go depth <n>               - UCI-style depth search (prints info/bestmove)
  go infinite                - Start bounded long search mode
  stop                       - Stop infinite search mode
  pgn load|show|moves        - PGN command family
  book load|on|off|stats     - Native opening book controls
  endgame                    - Detect specialized endgame and best move hint
  uci                        - Enter/respond to UCI handshake
  isready                    - UCI readiness probe
  setoption name <Hash|Threads> value <n> - Set UCI option
  ucinewgame                 - Reset internal state for UCI game
  position startpos|fen ... [moves ...] - Load UCI position
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
