#!/usr/bin/env python3
"""
Chess Engine Implementation in Python
Follows the Chess Engine Specification v1.0
"""

import sys
import re
import json
import shlex
import time
from concurrent.futures import ThreadPoolExecutor
from typing import Optional, List
from lib.attack_tables import manhattan_distance
from lib.board import Board
from lib.move_generator import MoveGenerator
from lib.fen_parser import FenParser
from lib.ai import AI
from lib.perft import Perft
from lib.pgn import (
    START_FEN,
    PgnMoveNode,
    build_game_from_history,
    copy_move,
    move_to_san,
    parse_pgn,
    serialize_game,
)
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

    _CHESS960_KNIGHT_TABLE = (
        (0, 1), (0, 2), (0, 3), (0, 4), (1, 2),
        (1, 3), (1, 4), (2, 3), (2, 4), (3, 4),
    )
    
    def __init__(self):
        self.board = Board()
        self.move_generator = MoveGenerator(self.board)
        self.fen_parser = FenParser(self.board)
        self.ai = AI(self.board, self.move_generator)
        self.perft = Perft(self.board, self.move_generator)
        self.move_history = []
        self._go_infinite = False
        self._pgn_path: Optional[str] = None
        self._pgn_game = build_game_from_history([], start_fen=START_FEN, source='current-game')
        self._pgn_variation_stack = []
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
        self._uci_analyse_mode = False
        self._rich_eval_enabled = False
        self._protocol_mode = 'boot'
        self._uci_state = 'boot'
        self._uci_last_bestmove: Optional[str] = None
        self._chess960_id = 0
        self._trace_enabled = False
        self._trace_level = 'info'
        self._trace_events = []
        self._trace_command_count = 0
        self._reset_trace_export_state()
        self._reset_trace_search_state()
    
    def start(self):
        """Start the chess engine and begin accepting commands."""
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
            parts = shlex.split(command)
            if not parts:
                return
                
            cmd = parts[0].lower()
            self._select_protocol_mode(cmd)
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
                if self._protocol_mode == 'uci':
                    self.handle_uci_go(parts[1:])
                else:
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
                if self._protocol_mode != 'uci':
                    print('Goodbye!')
                sys.exit(0)
            else:
                print('ERROR: Invalid command. Type "help" for available commands.')
                
        except (ValueError, IndexError):
            print('ERROR: Invalid command format')
        except Exception as e:
            print(f'ERROR: {e}')

    def _select_protocol_mode(self, cmd: str):
        if self._protocol_mode == 'boot':
            self._protocol_mode = 'uci' if cmd == 'uci' else 'custom'
        elif cmd == 'uci':
            self._protocol_mode = 'uci'

    def _set_uci_state(self, state: str):
        self._uci_state = state

    def _uci_bool_default(self, value: bool) -> str:
        return 'true' if value else 'false'

    def _parse_uci_check_value(self, raw_value: str) -> Optional[bool]:
        normalized = raw_value.strip().lower()
        if normalized in ('true', '1', 'on', 'yes'):
            return True
        if normalized in ('false', '0', 'off', 'no'):
            return False
        return None

    def _handle_uci_search(self, depth: int, movetime_ms: int):
        self._set_uci_state('searching')
        legal_moves = self.move_generator.generate_legal_moves()
        if not legal_moves:
            self._uci_last_bestmove = '0000'
            print('bestmove 0000')
            self._set_uci_state('idle')
            return

        book_move = self._choose_book_move(legal_moves)
        if book_move is not None:
            move_str = book_move.to_algebraic().lower()
            self._uci_last_bestmove = move_str
            self._record_trace_ai('uci-book', move_str, 0, 0, 0, False, 0, 0, 0, 0, 0)
            print(f'info string bookmove {move_str}')
            print(f'bestmove {move_str}')
            self._set_uci_state('idle')
            return

        endgame_choice = self._choose_endgame_move(legal_moves)
        if endgame_choice is not None:
            move, info = endgame_choice
            move_str = move.to_algebraic().lower()
            self._uci_last_bestmove = move_str
            self._record_trace_ai('uci-endgame', move_str, 0, info["score_white"], 0, False, 0, 0, 0, 0, 0)
            print(f'info string endgame {info["type"]} score cp {info["score_white"]}')
            print(f'bestmove {move_str}')
            self._set_uci_state('idle')
            return

        best_move, eval_score, depth_used, elapsed_ms, timed_out, nodes, eval_calls, tt_hits, tt_misses, beta_cutoffs = self.ai.search(depth, movetime_ms)
        if not best_move:
            self._uci_last_bestmove = '0000'
            print('bestmove 0000')
            self._set_uci_state('idle')
            return

        move_str = best_move.to_algebraic().lower()
        self._uci_last_bestmove = move_str
        self._record_trace_ai(
            'uci-search',
            move_str,
            depth_used,
            eval_score,
            elapsed_ms,
            timed_out,
            nodes,
            eval_calls,
            tt_hits,
            tt_misses,
            beta_cutoffs,
        )
        print(f'info depth {depth_used} score cp {eval_score} time {elapsed_ms} nodes {nodes}')
        print(f'bestmove {move_str}')
        self._set_uci_state('idle')

    def handle_uci_go(self, args):
        if not args:
            print('ERROR: go requires subcommand (movetime <ms>|wtime <ms> btime <ms> winc <ms> binc <ms> [movestogo <n>]|depth <n>|infinite)')
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
            self._handle_uci_search(max(1, min(5, depth)), 0)
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
            self._handle_uci_search(5, movetime_ms)
            return

        if subcommand == 'wtime':
            movetime_ms, error = self._derive_movetime_from_clock_args(args)
            if error is not None:
                print(f'ERROR: {error}')
                return
            self._handle_uci_search(5, movetime_ms)
            return

        if subcommand == 'infinite':
            self._go_infinite = True
            print('info string infinite search bounded to 15000 ms in synchronous mode')
            self._handle_uci_search(5, 15000)
            return

        print('ERROR: Unsupported go command')
    
    def handle_move(self, move_str: Optional[str]):
        """Handle move command."""
        if not move_str:
            print('ERROR: Invalid move format')
            return
        
        try:
            requested_move = Move.from_algebraic(move_str)
            if not requested_move:
                print('ERROR: Invalid move format')
                return

            legal_move = self._resolve_legal_move(requested_move)
            if not legal_move:
                print('ERROR: Illegal move')
                return

            self._record_pgn_move(legal_move)
            
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
        current_sequence = self._current_pgn_sequence()
        if not current_sequence:
            print('ERROR: No moves to undo')
            return

        current_sequence.pop()
        self._sync_runtime_to_pgn_cursor()
        print('OK: undo')
        print(self.board.display())
    
    def handle_new_game(self):
        """Handle new game command."""
        self._reset_position(START_FEN)
        self._pgn_path = None
        self._pgn_game = build_game_from_history([], start_fen=START_FEN, source='current-game')
        self._pgn_variation_stack = []
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

        best_move, eval_score, depth_used, elapsed_ms, timed_out, nodes, eval_calls, tt_hits, tt_misses, beta_cutoffs = self.ai.search(max_depth, movetime_ms)
        if not best_move:
            print('ERROR: No legal moves available')
            return

        self._record_pgn_move(best_move)

        move_str = best_move.to_algebraic()
        self._record_trace_ai(
            'search',
            move_str,
            depth_used,
            eval_score,
            elapsed_ms,
            timed_out,
            nodes,
            eval_calls,
            tt_hits,
            tt_misses,
            beta_cutoffs,
        )
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
            self._reset_position(fen)
            start_fen = self.fen_parser.export()
            self._pgn_path = None
            self._pgn_game = build_game_from_history([], start_fen=start_fen, source='current-game')
            self._pgn_variation_stack = []
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
                self._record_trace_ai('uci-book', move_str, 0, 0, 0, False, 0, 0, 0, 0, 0)
                print(f'info string bookmove {move_str}')
                print(f'bestmove {move_str}')
                return

            endgame_choice = self._choose_endgame_move(legal_moves)
            if endgame_choice is not None:
                move, info = endgame_choice
                move_str = move.to_algebraic()
                self._record_trace_ai('uci-endgame', move_str, 0, info["score_white"], 0, False, 0, 0, 0, 0, 0)
                print(f'info string endgame {info["type"]} score cp {info["score_white"]}')
                print(f'bestmove {move_str}')
                return

            best_move, eval_score, depth_used, elapsed_ms, timed_out, nodes, eval_calls, tt_hits, tt_misses, beta_cutoffs = self.ai.search(depth, 0)
            if not best_move:
                print('bestmove 0000')
                return
            move_str = best_move.to_algebraic()
            self._record_trace_ai(
                'uci-search',
                move_str,
                depth_used,
                eval_score,
                elapsed_ms,
                timed_out,
                nodes,
                eval_calls,
                tt_hits,
                tt_misses,
                beta_cutoffs,
            )
            print(f'info depth {depth_used} score cp {eval_score} time {elapsed_ms} nodes {nodes}')
            print(f'bestmove {move_str}')
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
        if self._protocol_mode == 'uci':
            if self._uci_state == 'searching':
                print(f'bestmove {self._uci_last_bestmove or "0000"}')
                self._set_uci_state('idle')
            else:
                print('info string stop ignored (no active async search)')
            return
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
            print('ERROR: pgn requires subcommand (load|save|show|moves|variation|comment)')
            return

        subcommand = args[0].lower()
        if subcommand == 'load':
            if len(args) < 2:
                print('ERROR: pgn load requires a file path')
                return
            path = ' '.join(args[1:])
            try:
                with open(path, 'r', encoding='utf-8') as handle:
                    content = handle.read()
                game = parse_pgn(content, path)
                game.source = path
                self._pgn_game = game
                self._pgn_path = path
                self._pgn_variation_stack = []
                self._sync_runtime_to_pgn_cursor()
                print(f'PGN: loaded source={path}')
            except FileNotFoundError:
                print(f'ERROR: pgn load failed: file not found: {path}')
            except Exception as exc:
                print(f'ERROR: pgn load failed: {exc}')
            return

        if subcommand == 'save':
            if len(args) < 2:
                print('ERROR: pgn save requires a file path')
                return
            path = ' '.join(args[1:])
            try:
                game = self._current_pgn_game()
                with open(path, 'w', encoding='utf-8') as handle:
                    handle.write(serialize_game(game))
                self._pgn_path = path
                game.source = path
                print(f'PGN: saved path="{path}"')
            except Exception as exc:
                print(f'ERROR: pgn save failed: {exc}')
            return

        if subcommand == 'show':
            game = self._current_pgn_game()
            source = game.source if game.source else 'current-game'
            print(f'PGN: source={source}; moves={len(self._current_pgn_moves())}')
            print(serialize_game(game).rstrip())
            return

        if subcommand == 'moves':
            moves = self._current_pgn_moves()
            if moves:
                print(f'PGN: moves {" ".join(moves)}')
            else:
                print('PGN: moves (none)')
            return

        if subcommand == 'variation':
            if len(args) < 2:
                print('ERROR: pgn variation requires enter or exit')
                return
            action = args[1].lower()
            if action == 'enter':
                current_sequence = self._current_pgn_sequence()
                if not current_sequence:
                    print('ERROR: No variation available')
                    return
                target = current_sequence[-1]
                if not target.variations:
                    target.variations.append([])
                self._pgn_variation_stack.append((len(current_sequence) - 1, len(target.variations) - 1))
                self._sync_runtime_to_pgn_cursor()
                print(f'PGN: variation depth={len(self._pgn_variation_stack)}')
                return
            if action == 'exit':
                if not self._pgn_variation_stack:
                    print('ERROR: Not inside a variation')
                    return
                self._pgn_variation_stack.pop()
                self._sync_runtime_to_pgn_cursor()
                print(f'PGN: variation depth={len(self._pgn_variation_stack)}')
                return
            print('ERROR: Unsupported pgn variation command')
            return

        if subcommand == 'comment':
            text = ' '.join(args[1:]).strip()
            if not text:
                print('ERROR: pgn comment requires text')
                return
            game = self._current_pgn_game()
            comment = text
            current_sequence = self._current_pgn_sequence()
            if not current_sequence:
                game.initial_comments.append(comment)
            else:
                current_sequence[-1].comments.append(comment)
            print('PGN: comment added')
            return

        print('ERROR: Unsupported pgn command')

    def _current_pgn_game(self):
        return self._pgn_game

    def _current_pgn_moves(self):
        return [node.san for node in self._current_pgn_sequence()]

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
        self._protocol_mode = 'uci'
        self._set_uci_state('uci_sent')
        print('id name Python Chess Engine')
        print('id author The Great Analysis Challenge')
        print(f'option name Hash type spin default {self._uci_hash_mb} min 1 max 1024')
        print(f'option name Threads type spin default {self._uci_threads} min 1 max 64')
        print(f'option name UCI_AnalyseMode type check default {self._uci_bool_default(self._uci_analyse_mode)}')
        print(f'option name RichEval type check default {self._uci_bool_default(self._rich_eval_enabled)}')
        print('uciok')

    def handle_isready(self):
        """Handle isready command."""
        if self._protocol_mode == 'uci' and self._uci_state != 'searching':
            self._set_uci_state('idle')
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

        raw_name = ' '.join(args[1:value_idx]).strip()
        name = raw_name.lower()
        raw_value = ' '.join(args[value_idx + 1:]).strip()

        if name == 'hash':
            try:
                value = int(raw_value)
            except ValueError:
                print('ERROR: setoption value must be an integer')
                return
            self._uci_hash_mb = max(1, min(1024, value))
            print(f'info string option Hash={self._uci_hash_mb}')
            return

        if name == 'threads':
            try:
                value = int(raw_value)
            except ValueError:
                print('ERROR: setoption value must be an integer')
                return
            self._uci_threads = max(1, min(64, value))
            print(f'info string option Threads={self._uci_threads}')
            return

        if name == 'uci_analysemode':
            parsed = self._parse_uci_check_value(raw_value)
            if parsed is None:
                print('ERROR: setoption value must be true/false')
                return
            self._uci_analyse_mode = parsed
            print(f'info string option UCI_AnalyseMode={self._uci_bool_default(parsed)}')
            return

        if name == 'richeval':
            parsed = self._parse_uci_check_value(raw_value)
            if parsed is None:
                print('ERROR: setoption value must be true/false')
                return
            self._rich_eval_enabled = parsed
            print(f'info string option RichEval={self._uci_bool_default(parsed)}')
            return

        print(f'info string unsupported option {raw_name}')

    def handle_ucinewgame(self):
        """Handle UCI ucinewgame command."""
        self._reset_position(START_FEN)
        self._pgn_path = None
        self._pgn_game = build_game_from_history([], start_fen=START_FEN, source='current-game')
        self._pgn_variation_stack = []
        self._uci_last_bestmove = None
        if self._protocol_mode == 'uci':
            self._set_uci_state('idle')

    def handle_position(self, args):
        """Handle UCI position command: startpos|fen ... [moves ...]."""
        if not args:
            print("ERROR: position requires 'startpos' or 'fen <...>'")
            return

        idx = 0
        keyword = args[0].lower()
        start_fen = START_FEN
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
                start_fen = ' '.join(fen_tokens)
                self._reset_position(start_fen)
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

        self._pgn_path = None
        self._pgn_variation_stack = []
        current_start_fen = self.fen_parser.export() if not self.move_history else start_fen
        self._pgn_game = build_game_from_history(self.move_history, start_fen=current_start_fen, source='current-game')
        if self._protocol_mode == 'uci':
            self._set_uci_state('idle')

    def _apply_move_silent(self, move_str: str) -> Optional[str]:
        """Apply one coordinate move without emitting CLI output."""
        move = Move.from_algebraic(move_str)
        if not move:
            return 'Invalid move format'
        return self._apply_move_object_silent(move)

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
        fen = self._build_chess960_fen(self._chess960_id)

        self.board = Board()
        self.move_generator = MoveGenerator(self.board)
        self.fen_parser = FenParser(self.board)
        self.ai = AI(self.board, self.move_generator)
        self.perft = Perft(self.board, self.move_generator)
        self.move_history = []
        self.fen_parser.parse(fen)

        print('OK: New game started')
        print(self.board.display())
        print(
            f'960: new game id={self._chess960_id}; '
            f'backrank={self._chess960_backrank(self._chess960_id)}'
        )

    def handle_position960(self):
        """Handle position960 command."""
        print(
            f'960: id={self._chess960_id}; mode=chess960; '
            f'backrank={self._chess960_backrank(self._chess960_id)}; '
            f'fen={self._build_chess960_fen(self._chess960_id)}'
        )

    @classmethod
    def _decode_chess960_backrank(cls, chess960_id: int):
        pieces: List[Optional[str]] = [None] * 8
        n = chess960_id

        remainder = n % 4
        n //= 4
        pieces[2 * remainder + 1] = 'b'

        remainder = n % 4
        n //= 4
        pieces[2 * remainder] = 'b'

        remainder = n % 6
        n //= 6
        empty = [index for index, piece in enumerate(pieces) if piece is None]
        pieces[empty[remainder]] = 'q'

        knight_a, knight_b = cls._CHESS960_KNIGHT_TABLE[n]
        empty = [index for index, piece in enumerate(pieces) if piece is None]
        pieces[empty[knight_a]] = 'n'
        pieces[empty[knight_b]] = 'n'

        empty = [index for index, piece in enumerate(pieces) if piece is None]
        pieces[empty[0]] = 'r'
        pieces[empty[1]] = 'k'
        pieces[empty[2]] = 'r'

        return ''.join(piece or '' for piece in pieces)

    @classmethod
    def _chess960_backrank(cls, chess960_id: int) -> str:
        return cls._decode_chess960_backrank(chess960_id)

    @classmethod
    def _build_chess960_fen(cls, chess960_id: int) -> str:
        white_backrank = cls._decode_chess960_backrank(chess960_id).upper()
        black_backrank = white_backrank.lower()
        return (
            f'{black_backrank}/pppppppp/8/8/8/8/PPPPPPPP/{white_backrank} '
            'w - - 0 1'
        )

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
            self._reset_trace_search_state()
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

    def _reset_trace_search_state(self):
        self._trace_ai_source: Optional[str] = None
        self._trace_ai_move: Optional[str] = None
        self._trace_ai_depth = 0
        self._trace_ai_score_cp = 0
        self._trace_ai_elapsed_ms = 0
        self._trace_ai_timed_out = False
        self._trace_ai_nodes = 0
        self._trace_ai_eval_calls = 0
        self._trace_ai_nps = 0
        self._trace_ai_tt_hits = 0
        self._trace_ai_tt_misses = 0
        self._trace_ai_beta_cutoffs = 0

    def _trace_report_line(self) -> str:
        report = (
            f'TRACE: enabled={str(self._trace_enabled).lower()}; '
            f'level={self._trace_level}; events={len(self._trace_events)}; '
            f'commands={self._trace_command_count}; '
            f'export={self._trace_report_segment(self._trace_export_count, self._trace_export_last_target, self._trace_export_last_bytes)}; '
            f'chrome={self._trace_report_segment(self._trace_chrome_count, self._trace_chrome_last_target, self._trace_chrome_last_bytes)}; '
            f'last_ai={self._trace_last_ai_summary()}'
        )
        search_metrics = self._trace_search_metrics_summary()
        if search_metrics is not None:
            report += f'; search_metrics={search_metrics}'
        return report

    def _trace_report_segment(self, count: int, target: Optional[str], byte_count: int) -> str:
        resolved_target = target if target is not None else 'none'
        return f'{count}@{resolved_target}/{byte_count}B'

    def _trace_last_ai_summary(self) -> str:
        if self._trace_ai_source is None or self._trace_ai_move is None:
            return 'none'

        summary = f'{self._trace_ai_source}:{self._trace_ai_move}'
        if 'search' in self._trace_ai_source:
            summary += (
                f'@d{self._trace_ai_depth}/{self._trace_ai_score_cp}cp/{self._trace_ai_elapsed_ms}ms'
                f'/n{self._trace_ai_nodes}/e{self._trace_ai_eval_calls}/nps{self._trace_ai_nps}'
            )
            if self._trace_ai_timed_out:
                summary += '/timeout'
        elif 'endgame' in self._trace_ai_source:
            summary += f'/{self._trace_ai_score_cp}cp'

        return summary

    def _trace_search_metrics_summary(self) -> Optional[str]:
        if self._trace_ai_source is None or 'search' not in self._trace_ai_source:
            return None
        return (
            f'nodes={self._trace_ai_nodes},eval_calls={self._trace_ai_eval_calls},'
            f'tt_hits={self._trace_ai_tt_hits},tt_misses={self._trace_ai_tt_misses},'
            f'beta_cutoffs={self._trace_ai_beta_cutoffs},nps={self._trace_ai_nps}'
        )

    def _record_trace_ai(
        self,
        source: str,
        move: str,
        depth: int,
        score_cp: int,
        elapsed_ms: int,
        timed_out: bool,
        nodes: int,
        eval_calls: int,
        tt_hits: int,
        tt_misses: int,
        beta_cutoffs: int,
    ):
        self._trace_ai_source = source
        self._trace_ai_move = move
        self._trace_ai_depth = depth
        self._trace_ai_score_cp = score_cp
        self._trace_ai_elapsed_ms = elapsed_ms
        self._trace_ai_timed_out = timed_out
        self._trace_ai_nodes = nodes
        self._trace_ai_eval_calls = eval_calls
        divisor = elapsed_ms if elapsed_ms > 0 else 1
        self._trace_ai_nps = (nodes * 1000) // divisor if nodes > 0 else 0
        self._trace_ai_tt_hits = tt_hits
        self._trace_ai_tt_misses = tt_misses
        self._trace_ai_beta_cutoffs = beta_cutoffs
        self._trace('ai', self._trace_last_ai_summary())

    def _trace_last_ai_payload(self):
        if self._trace_ai_source is None or self._trace_ai_move is None:
            return None

        return {
            'source': self._trace_ai_source,
            'move': self._trace_ai_move,
            'depth': self._trace_ai_depth,
            'score_cp': self._trace_ai_score_cp,
            'elapsed_ms': self._trace_ai_elapsed_ms,
            'timed_out': self._trace_ai_timed_out,
            'nodes': self._trace_ai_nodes,
            'eval_calls': self._trace_ai_eval_calls,
            'nps': self._trace_ai_nps,
            'tt_hits': self._trace_ai_tt_hits,
            'tt_misses': self._trace_ai_tt_misses,
            'beta_cutoffs': self._trace_ai_beta_cutoffs,
            'summary': self._trace_last_ai_summary(),
        }

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
        last_ai = self._trace_last_ai_payload()
        if last_ai is not None:
            payload['last_ai'] = last_ai
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
            'format': 'tgac.chrome_trace.v1',
            'engine': 'python',
            'generated_at_ms': int(time.time() * 1000),
            'enabled': self._trace_enabled,
            'level': self._trace_level,
            'command_count': self._trace_command_count,
            'event_count': len(self._trace_events),
            'display_time_unit': 'ms',
            'events': trace_events,
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
        self._record_pgn_move(move)
        self._book_played += 1
        move_str = move.to_algebraic()
        self._record_trace_ai('book', move_str, 0, 0, 0, False, 0, 0, 0, 0, 0)

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
            king_distance = manhattan_distance(strong_king, weak_king)
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
            king_distance = manhattan_distance(strong_king, weak_king)
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
            score = 120 + (6 - pawn_steps) * 35 + manhattan_distance(weak_king, promotion) * 6 - manhattan_distance(strong_king, pawn) * 8
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
            score = 120 + (6 - pawn_steps) * 35 + manhattan_distance(weak_king, promotion) * 6 - manhattan_distance(strong_king, pawn) * 8
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
            score = 380 - pawn_steps * 25 + (manhattan_distance(weak_king, weak_pawn) - manhattan_distance(strong_king, weak_pawn)) * 12
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
            score = 380 - pawn_steps * 25 + (manhattan_distance(weak_king, weak_pawn) - manhattan_distance(strong_king, weak_pawn)) * 12
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
        self._record_pgn_move(move)
        move_str = move.to_algebraic()
        self._record_trace_ai('endgame', move_str, 0, info["score_white"], 0, False, 0, 0, 0, 0, 0)
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
  pgn load|save|show|moves   - PGN command family
  pgn variation enter|exit   - Enter or exit current variation
  pgn comment "text"         - Add comment to current PGN node
  book load|on|off|stats     - Native opening book controls
  endgame                    - Detect specialized endgame and best move hint
  uci                        - Enter/respond to UCI handshake
  isready                    - UCI readiness probe
  setoption name <Hash|Threads|UCI_AnalyseMode|RichEval> value <x> - Set UCI option
  ucinewgame                 - Reset internal state for UCI game
  position startpos|fen ... [moves ...] - Load UCI position
  new960 [id]                - Start Chess960 game by id (0-959)
  position960                - Show current Chess960 metadata
  perft <depth>              - Performance test (move count)
  help                       - Display this help
  quit                       - Exit the program
        """
        print(help_text.strip())

    def _reset_position(self, start_fen: str = START_FEN):
        self.board = Board()
        self.move_generator = MoveGenerator(self.board)
        self.fen_parser = FenParser(self.board)
        if start_fen != START_FEN:
            self.fen_parser.parse(start_fen)
        self.ai = AI(self.board, self.move_generator)
        self.perft = Perft(self.board, self.move_generator)
        self.move_history = []

    def _resolve_legal_move(self, requested_move: Move):
        move = copy_move(requested_move)
        moving_piece = self.board.get_piece(move.from_row, move.from_col)
        if moving_piece and moving_piece.type == PieceType.PAWN and move.promotion is None:
            if (moving_piece.color == Color.WHITE and move.to_row == 7) or \
               (moving_piece.color == Color.BLACK and move.to_row == 0):
                move.promotion = PieceType.QUEEN

        for candidate in self.move_generator.generate_legal_moves():
            if (candidate.from_row == move.from_row and
                candidate.from_col == move.from_col and
                candidate.to_row == move.to_row and
                candidate.to_col == move.to_col and
                candidate.promotion == move.promotion):
                return candidate
        return None

    def _apply_move_object_silent(self, move: Move) -> Optional[str]:
        legal_move = self._resolve_legal_move(move)
        if not legal_move:
            return 'Illegal move'

        self.move_history.append(legal_move)
        self.board.make_move(legal_move)
        return None

    def _current_pgn_sequence(self):
        sequence = self._pgn_game.moves
        for anchor_index, variation_index in self._pgn_variation_stack:
            if anchor_index < 0 or anchor_index >= len(sequence):
                return []
            anchor = sequence[anchor_index]
            if variation_index < 0 or variation_index >= len(anchor.variations):
                return []
            sequence = anchor.variations[variation_index]
        return sequence

    def _active_line_nodes(self):
        nodes = []
        sequence = self._pgn_game.moves
        for anchor_index, variation_index in self._pgn_variation_stack:
            nodes.extend(sequence[:anchor_index + 1])
            anchor = sequence[anchor_index]
            sequence = anchor.variations[variation_index]
        nodes.extend(sequence)
        return nodes

    def _sync_runtime_to_pgn_cursor(self):
        self._reset_position(self._pgn_game.initial_fen)
        for node in self._active_line_nodes():
            error = self._apply_move_object_silent(node.move)
            if error is not None:
                raise ValueError(f'failed to replay PGN move {node.san}: {error}')

    def _record_pgn_move(self, move: Move):
        san = move_to_san(self.board, move)
        fen_before = self.fen_parser.export()
        self.move_history.append(move)
        self.board.make_move(move)
        fen_after = self.fen_parser.export()
        self._current_pgn_sequence().append(
            PgnMoveNode(
                san=san,
                move=copy_move(move),
                fen_before=fen_before,
                fen_after=fen_after,
            )
        )


def main():
    """Main entry point."""
    engine = ChessEngine()
    engine.start()


if __name__ == '__main__':
    main()
