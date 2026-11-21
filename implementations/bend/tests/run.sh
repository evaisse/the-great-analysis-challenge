#!/bin/sh
# Scripted engine tests: each case feeds commands on stdin and expects a
# substring in the output. Usage: sh tests/run.sh ./chess
BIN=${1:-./chess}
fails=0
total=0

check() {
  name=$1 input=$2 want=$3
  total=$((total + 1))
  out=$(printf "%b" "$input" | "$BIN")
  if printf '%s' "$out" | grep -qF -- "$want"; then
    echo "PASS $name"
  else
    echo "FAIL $name: expected '$want'"
    fails=$((fails + 1))
  fi
}

check start_fen 'export\nquit\n' 'FEN: rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'
check basic_moves 'new\nmove e2e4\nmove e7e5\nmove g1f3\nmove b8c6\nexport\n' 'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3'
check double_push_ep 'new\nmove e2e4\nmove e7e5\nexport\n' 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2'
check illegal 'new\nmove e2e5\n' 'ERROR: Illegal move'
check turn_order 'new\nmove e7e5\n' 'ERROR: Wrong color piece'
check bad_format 'move zz\n' 'ERROR: Invalid move format'
check pinned 'fen 4k3/4r3/8/8/8/8/4B3/4K3 w - - 0 1\nmove e2d3\n' 'ERROR: King would be in check'
check castle_k 'fen r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1\nmove e1g1\nexport\n' 'r3k2r/8/8/8/8/8/8/R4RK1 b kq - 1 1'
check castle_q 'fen r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1\nmove e1c1\nexport\n' '2KR3R b kq'
check castle_through_check 'fen r3k2r/8/8/8/8/8/5r2/R3K2R w KQkq - 0 1\nmove e1g1\n' 'ERROR'
check en_passant 'fen rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 3\nmove e5f6\nexport\n' 'rnbqkbnr/ppp1p1pp/5P2/3p4/8/8/PPPP1PPP/RNBQKBNR b KQkq - 0 3'
check promotion 'fen 8/P7/8/8/8/8/8/8 w - - 0 1\nmove a7a8\nexport\n' 'FEN: Q7/'
check under_promotion 'fen 4k3/P7/8/8/8/8/8/4K3 w - - 0 1\nmove a7a8n\nexport\n' 'FEN: N3k3/'
check fools_mate 'new\nmove f2f3\nmove e7e5\nmove g2g4\nmove d8h4\nstatus\n' 'CHECKMATE: Black wins'
check stalemate 'fen 7k/5Q2/8/8/8/8/8/7K w - - 0 1\nmove f7g6\nstatus\n' 'STALEMATE: Draw'
check undo 'new\nmove e2e4\nundo\nexport\n' 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'
check undo_empty 'new\nundo\n' 'ERROR: No moves to undo'
check bad_fen 'fen 8/8/8 w - - 0 1\n' 'ERROR: Invalid FEN string'
check eval_start 'eval\n' 'EVALUATION: 0'
check repetition 'move g1f3\nmove g8f6\nmove f3g1\nmove f6g8\nmove g1f3\nmove g8f6\nmove f3g1\nmove f6g8\nstatus\n' 'DRAW: REPETITION'
check fifty 'fen rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 99 1\nmove g1f3\nstatus\n' 'DRAW: 50-MOVE'
check perft3 'perft 3\n' 'Perft(3): 8902 nodes'
check perft4 'perft 4\n' 'Perft(4): 197281 nodes'
check perft_kiwipete 'fen r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1\nperft 3\n' 'Perft(3): 97862 nodes'
check perft_pos3 'fen 8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1\nperft 4\n' 'Perft(4): 43238 nodes'
check perft_pos4 'fen r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1\nperft 3\n' 'Perft(3): 9467 nodes'
check ai_capture 'fen rnbqkbnr/pppp1ppp/8/4p3/3P4/8/PPP1PPPP/RNBQKBNR w KQkq - 0 2\nai 2\n' 'AI: d4e5'
check ai_mate 'fen 6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1\nai 2\n' 'AI: a1a8 (depth=2, eval=100000'
check ai_promotion 'fen 4k3/P7/8/8/8/8/8/4K3 w - - 0 1\nai 2\n' 'AI: a7a8q'
check ai_depth 'ai 6\n' 'ERROR: AI depth must be 1-5'
check unknown 'frobnicate\n' 'ERROR: Invalid command'

echo "$((total - fails))/$total passed"
[ "$fails" -eq 0 ]
