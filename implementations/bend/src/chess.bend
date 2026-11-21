# The chess engine's entry point: a stdin/stdout command loop.
#
# Effects are sequenced in IO `do` blocks. The stdin handle is affine, so
# each read hands it back beside the line. The loop counts down a fuel of
# 2^32 - 1 commands, which keeps it a proven-terminating definition.
import Base
import ./board.bend as B
import ./moves.bend as M
import ./search.bend as S
import ./game.bend as G

# The state the loop carries: the game and whether to keep reading
def say(+s: G.St, text: String) -> IO(G.St & Bool):
  do IO<G.St & Bool>:
    IO.print(text)
    return (s, True{})

def reply(o: G.Out) -> IO(G.St & Bool):
  match o:
    case G.Out{s, text}:
      say(s, text)

def first(xs: List<&2, String>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{h, t}:
      h

# a number argument, 4294967295 when missing or malformed
def num(xs: List<&2, String>) -> U32:
  Maybe.default(&2, U32, U32.read(first(xs)), 4294967295)

# Timed commands
# --------------

def ai.run(ok: Bool, +s: G.St, +d: U32) -> IO(G.St & Bool):
  match ok:
    case False{}:
      say(s, "ERROR: No legal moves available")
    case True{}:
      do IO<G.St & Bool>:
        t0 : Nat <- IO.now()
        b : S.Best = S.best_move(U32.to_nat(d), G.st.p(s))
        t1 : Nat <- IO.now()
        reply(G.ai.text(s, d, b, U32.from_nat(Nat.sub(t1, t0))))

def cmd.ai(ok: Bool, +s: G.St, +d: U32) -> IO(G.St & Bool):
  match ok:
    case False{}:
      say(s, "ERROR: AI depth must be 1-5")
    case True{}:
      ai.run(Bool.not(List.is_empty(&2, U32, M.legal(G.st.p(s)))), s, d)

def cmd.perft(ok: Bool, +s: G.St, +d: U32) -> IO(G.St & Bool):
  match ok:
    case False{}:
      say(s, "ERROR: Perft depth must be 1-6")
    case True{}:
      do IO<G.St & Bool>:
        t0 : Nat <- IO.now()
        n : U32 = S.perft(U32.to_nat(d), G.st.p(s))
        t1 : Nat <- IO.now()
        say(s, G.perft.text(d, n, U32.from_nat(Nat.sub(t1, t0))))

# Dispatch
# --------

def in_range(+x: U32, +lo: U32, +hi: U32) -> Bool:
  Bool.and(U32.is_ge(x, lo), U32.is_le(x, hi))

# command names, numbered in the order the dispatch chain tests them
def code(+c: String) -> U32:
  B.sel(String.eq(c, "new"), 1, B.sel(String.eq(c, "move"), 2,
  B.sel(String.eq(c, "undo"), 3, B.sel(String.eq(c, "ai"), 4,
  B.sel(String.eq(c, "fen"), 5, B.sel(String.eq(c, "export"), 6,
  B.sel(String.eq(c, "eval"), 7, B.sel(String.eq(c, "perft"), 8,
  B.sel(String.eq(c, "status"), 9, B.sel(String.eq(c, "hash"), 10,
  B.sel(String.eq(c, "draws"), 11, B.sel(String.eq(c, "help"), 12,
  B.sel(Bool.or(String.eq(c, "quit"), String.eq(c, "exit")), 13, 0)))))))))))))

def run.c13(c: Bool, +s: G.St) -> IO(G.St & Bool):
  match c:
    case True{}:
      do IO<G.St & Bool>:
        IO.print("Goodbye!")
        return (s, False{})
    case False{}:
      say(s, "ERROR: Invalid command")

def run.c12(c: Bool, +k: U32, +s: G.St) -> IO(G.St & Bool):
  match c:
    case True{}:
      say(s, G.help())
    case False{}:
      run.c13(B.eq(k, 13), s)

def run.c11(c: Bool, +k: U32, +s: G.St) -> IO(G.St & Bool):
  match c:
    case True{}:
      say(s, G.draws(s))
    case False{}:
      run.c12(B.eq(k, 12), k, s)

def run.c10(c: Bool, +k: U32, +s: G.St) -> IO(G.St & Bool):
  match c:
    case True{}:
      say(s, G.hash(G.st.p(s)))
    case False{}:
      run.c11(B.eq(k, 11), k, s)

def run.c9(c: Bool, +k: U32, +s: G.St) -> IO(G.St & Bool):
  match c:
    case True{}:
      say(s, G.status(s))
    case False{}:
      run.c10(B.eq(k, 10), k, s)

def run.c8(c: Bool, +k: U32, args: List<&2, String>, +s: G.St) -> IO(G.St & Bool):
  match c:
    case True{}:
      +d = num(args)
      cmd.perft(in_range(d, 1, 6), s, d)
    case False{}:
      run.c9(B.eq(k, 9), k, s)

def run.c7(c: Bool, +k: U32, args: List<&2, String>, +s: G.St) -> IO(G.St & Bool):
  match c:
    case True{}:
      say(s, "EVALUATION: " ++ B.s.show(S.evaluate(G.st.p(s))))
    case False{}:
      run.c8(B.eq(k, 8), k, args, s)

def run.c6(c: Bool, +k: U32, args: List<&2, String>, +s: G.St) -> IO(G.St & Bool):
  match c:
    case True{}:
      say(s, "FEN: " ++ B.fen.write(G.st.p(s)))
    case False{}:
      run.c7(B.eq(k, 7), k, args, s)

def run.c5(c: Bool, +k: U32, args: List<&2, String>, +s: G.St) -> IO(G.St & Bool):
  match c:
    case True{}:
      reply(G.cmd.fen(B.fen.read(String.join(args, " ")), s))
    case False{}:
      run.c6(B.eq(k, 6), k, args, s)

def run.c4(c: Bool, +k: U32, args: List<&2, String>, +s: G.St) -> IO(G.St & Bool):
  match c:
    case True{}:
      +d = num(args)
      cmd.ai(in_range(d, 1, 5), s, d)
    case False{}:
      run.c5(B.eq(k, 5), k, args, s)

def run.c3(c: Bool, +k: U32, args: List<&2, String>, +s: G.St) -> IO(G.St & Bool):
  match c:
    case True{}:
      reply(G.cmd.undo(G.st.undo(s), s))
    case False{}:
      run.c4(B.eq(k, 4), k, args, s)

def run.c2(c: Bool, +k: U32, args: List<&2, String>, +s: G.St) -> IO(G.St & Bool):
  match c:
    case True{}:
      reply(G.cmd.move(s, first(args)))
    case False{}:
      run.c3(B.eq(k, 3), k, args, s)

def run.c1(c: Bool, +k: U32, args: List<&2, String>, +s: G.St) -> IO(G.St & Bool):
  match c:
    case True{}:
      +n = G.st.new(B.start_pos())
      say(n, G.lines("OK: New game started", B.show(G.st.p(n))))
    case False{}:
      run.c2(B.eq(k, 2), k, args, s)

def dispatch(ws: List<&2, String>, +s: G.St) -> IO(G.St & Bool):
  match ws:
    case Nil{}:
      IO.pure(G.St & Bool, (s, True{}))
    case Con{cmd, args}:
      +k = code(String.to_lower(cmd))
      run.c1(B.eq(k, 1), k, args, s)

# The read loop
# -------------

def on_line(eof: Bool, line: String, +s: G.St) -> IO(G.St & Bool):
  match eof:
    case True{}:
      IO.pure(G.St & Bool, (s, False{}))
    case False{}:
      dispatch(B.drop_empty(String.split(String.trim(line), ' ')), s)

def on_read(r: Result<&1, &1, U32 & String, String>, +s: G.St) -> IO(G.St & Bool):
  match r:
    case Fail{e}:
      IO.pure(G.St & Bool, (s, False{}))
    case Done{+line}:
      on_line(String.is_empty(line), line, s)

def step(p: File & Result<&1, &1, U32 & String, String>, +s: G.St) -> IO(File & (G.St & Bool)):
  (f, r) = p
  do IO<File & (G.St & Bool)>:
    x : G.St & Bool <- on_read(r, s)
    return (f, x)

def loop(fuel: Nat, w: File & (G.St & Bool)) -> IO(Unit):
  match fuel w:
    case 0n Tuple{f, x}:
      File.close(f)
    case 1n+k Tuple{f, Tuple{s, False{}}}:
      File.close(f)
    case 1n+k Tuple{f, Tuple{+s, True{}}}:
      do IO<Unit>:
        p : File & Result<&1, &1, U32 & String, String> <- File.read_line(f, 65536)
        w2 : File & (G.St & Bool) <- step(p, s)
        loop(k, w2)

def main() -> IO(Unit):
  do IO<Unit>:
    f : File <- IO.try(File, File.open("/dev/stdin", "r"))
    loop(4294967295n, (f, (G.st.new(B.start_pos()), True{})))
