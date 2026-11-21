# Game state and the pure side of the command interface: move parsing,
# game-end detection, draw detection, hashing and the reply texts.
import Base
import ./board.bend as B
import ./moves.bend as M
import ./search.bend as S

# the current position and every earlier one, most recent first
type St is Data:
  St{p: B.Pos, hist: List<&2, B.Pos>}

def st.p(+s: St) -> B.Pos:
  match s:
    case St{p, h}:
      p

def st.hist(+s: St) -> List<&2, B.Pos>:
  match s:
    case St{p, h}:
      h

def st.new(+p: B.Pos) -> St:
  St{p, Nil{}}

def st.push(+s: St, +q: B.Pos) -> St:
  match s:
    case St{+p, h}:
      St{q, p <> h}

def st.undo(+s: St) -> Maybe<&2, St>:
  match s:
    case St{p, Nil{}}:
      None{}
    case St{p, Con{+q, t}}:
      Some{St{q, t}}

# Text helpers
# ------------

def lines(+a: String, +b: String) -> String:
  B.sel.s(String.is_empty(b), a, a ++ "\n" ++ b)

def hex.digit(+d: U32) -> String:
  B.chr(B.sel(U32.is_lt(d, 10), U32.add(d, 48), U32.add(d, 87)))

def hex8(n: Nat, +x: U32) -> String:
  match n:
    case 0n:
      ""
    case 1n+k:
      hex8(k, U32.shrn(x, 4n)) ++ hex.digit(U32.and(x, 15))

def winner(+p: B.Pos) -> String:
  B.sel.s(B.eq(B.p.side(p), 0), "Black", "White")

# Game end and draws
# ------------------

def same(+a: B.Pos, +b: B.Pos) -> Bool:
  match a b:
    case B.Pos{B.Board{a0, a1, a2, a3, a4, a5, a6, a7}, sa, ca, ea, ha, fa} B.Pos{B.Board{b0, b1, b2, b3, b4, b5, b6, b7}, sb, cb, eb, hb, fb}:
      Bool.and(Bool.and(Bool.and(B.eq(a0, b0), B.eq(a1, b1)), Bool.and(B.eq(a2, b2), B.eq(a3, b3))),
        Bool.and(Bool.and(Bool.and(B.eq(a4, b4), B.eq(a5, b5)), Bool.and(B.eq(a6, b6), B.eq(a7, b7))),
          Bool.and(B.eq(sa, sb), Bool.and(B.eq(ca, cb), B.eq(ea, eb)))))

def occurrences(+p: B.Pos, hs: List<&2, B.Pos>) -> U32:
  match hs:
    case Nil{}:
      0
    case Con{+h, t}:
      U32.add(Bool.to_u32(same(p, h)), occurrences(p, t))

def repetitions(+s: St) -> U32:
  U32.inc(occurrences(st.p(s), st.hist(s)))

# "" while the game goes on
def game_end(+p: B.Pos) -> String:
  +none = List.is_empty(&2, U32, M.legal(p))
  B.sel.s(none, B.sel.s(M.in_check(p), "CHECKMATE: " ++ winner(p) ++ " wins", "STALEMATE: Draw"), "")

def draw_reason(+s: St) -> String:
  +fifty = U32.is_ge(B.p.half(st.p(s)), 100)
  +rep = U32.is_ge(repetitions(s), 3)
  B.sel.s(rep, "REPETITION", B.sel.s(fifty, "50-MOVE", ""))

def status(+s: St) -> String:
  +end = game_end(st.p(s))
  +draw = draw_reason(s)
  B.sel.s(String.is_empty(end), B.sel.s(String.is_empty(draw), "OK: ONGOING", "DRAW: " ++ draw), end)

def draws(+s: St) -> String:
  +rep = U32.is_ge(repetitions(s), 3)
  +fifty = U32.is_ge(B.p.half(st.p(s)), 100)
  "DRAWS: repetition=" ++ U32.show(repetitions(s)) ++ "; halfmove=" ++
    U32.show(B.p.half(st.p(s))) ++ "; draw=" ++ B.sel.s(Bool.or(rep, fifty), "true", "false") ++
    "; reason=" ++ B.sel.s(rep, "repetition", B.sel.s(fifty, "fifty_moves", "none"))

# FNV-1a over the position's words, in two independent 32-bit lanes
def fnv(+h: U32, +x: U32) -> U32:
  U32.mul(U32.xor(h, x), 16777619)

def hash.lane(+seed: U32, +p: B.Pos) -> U32:
  match p:
    case B.Pos{B.Board{a0, a1, a2, a3, a4, a5, a6, a7}, s, c, e, h, f}:
      fnv(fnv(fnv(fnv(fnv(fnv(fnv(fnv(fnv(fnv(fnv(seed, a0), a1), a2), a3), a4), a5), a6), a7), s), c), e)

def hash(+p: B.Pos) -> String:
  "HASH: " ++ hex8(8n, hash.lane(2166136261, p)) ++ hex8(8n, hash.lane(84696351, p))

# Move parsing
# ------------

# a square from two characters, 256 when malformed
def parse_sq(+f: U32, +r: U32) -> U32:
  +ok = Bool.and(Bool.and(U32.is_ge(f, 97), U32.is_le(f, 104)), Bool.and(U32.is_ge(r, 49), U32.is_le(r, 56)))
  B.sel(ok, M.sq(U32.sub(f, 97), U32.sub(r, 49)), 256)

def parse_promo(+c: U32) -> U32:
  +l = B.sel(U32.is_lt(c, 97), U32.add(c, 32), c)
  B.sel(B.eq(l, 113), 5, B.sel(B.eq(l, 114), 4, B.sel(B.eq(l, 98), 3, B.sel(B.eq(l, 110), 2, 256))))

# (from, to, promotion) packed as a move, or 4294967295 when malformed
def parse_move(s: String) -> U32:
  match s:
    case SCon{Chr{+a}, SCon{Chr{+b}, SCon{Chr{+c}, SCon{Chr{+d}, SNil{}}}}}:
      +from = parse_sq(a, b)
      +to = parse_sq(c, d)
      B.sel(Bool.or(B.eq(from, 256), B.eq(to, 256)), 4294967295, M.mv(from, to, 0))
    case SCon{Chr{+a}, SCon{Chr{+b}, SCon{Chr{+c}, SCon{Chr{+d}, SCon{Chr{+e}, SNil{}}}}}}:
      +from = parse_sq(a, b)
      +to = parse_sq(c, d)
      +pr = parse_promo(e)
      B.sel(Bool.or(Bool.or(B.eq(from, 256), B.eq(to, 256)), B.eq(pr, 256)), 4294967295, M.mv(from, to, pr))
    case _:
      4294967295

def matches(+want: U32, +m: U32) -> Bool:
  +wp = M.m.promo(want)
  +mp = M.m.promo(m)
  Bool.and(B.eq(U32.and(want, 4095), U32.and(m, 4095)),
    Bool.or(B.eq(wp, mp), Bool.and(U32.is_zero(wp), Bool.or(U32.is_zero(mp), B.eq(mp, 5)))))

# the first move of ms matching want, or 65535
def find_move(+want: U32, ms: List<&2, U32>) -> U32:
  match ms:
    case Nil{}:
      65535
    case Con{+m, t}:
      B.sel(matches(want, m), m, find_move(want, t))

# Replies
# -------

type Out is Data:
  Out{st: St, text: String}

def after_move(+s: St, +head: String) -> Out:
  +p = st.p(s)
  Out{s, lines(lines(head, B.show(p)), game_end(p))}

def move.why(+p: B.Pos, +want: U32) -> String:
  +v = B.at(p, M.m.from(want))
  +me = U32.shln(B.p.side(p), 3n)
  +pseudo = B.sel(B.eq(find_move(want, M.pseudo(p)), 65535), 0, 1)
  B.sel.s(U32.is_zero(v), "ERROR: No piece at source square",
    B.sel.s(U32.is_ne(M.color(v), me), "ERROR: Wrong color piece",
      B.sel.s(B.eq(pseudo, 1), "ERROR: King would be in check", "ERROR: Illegal move")))

def move.found(ok: Bool, +s: St, +m: U32, +why: String) -> Out:
  match ok:
    case True{}:
      after_move(st.push(s, M.make(st.p(s), m)), "OK: " ++ M.m.show(m))
    case False{}:
      Out{s, why}

def move.parsed(ok: Bool, +s: St, +want: U32) -> Out:
  match ok:
    case True{}:
      +p = st.p(s)
      +m = find_move(want, M.legal(p))
      move.found(U32.is_ne(m, 65535), s, m, move.why(p, want))
    case False{}:
      Out{s, "ERROR: Invalid move format"}

def cmd.move(+s: St, +arg: String) -> Out:
  +want = parse_move(arg)
  move.parsed(U32.is_ne(want, 4294967295), s, want)

def cmd.undo(m: Maybe<&2, St>, +s: St) -> Out:
  match m:
    case None{}:
      Out{s, "ERROR: No moves to undo"}
    case Some{+u}:
      Out{u, lines("OK: undo", B.show(st.p(u)))}

def cmd.fen(m: Maybe<&2, B.Pos>, +s: St) -> Out:
  match m:
    case None{}:
      Out{s, "ERROR: Invalid FEN string"}
    case Some{+p}:
      Out{st.new(p), lines("OK: Loaded position from FEN", B.show(p))}

def perft.text(+d: U32, +n: U32, +ms: U32) -> String:
  "Perft(" ++ U32.show(d) ++ "): " ++ U32.show(n) ++ " nodes in " ++ U32.show(ms) ++ "ms"

# the reply to an AI search that found move b.move with score b.score
def ai.text(+s: St, +d: U32, b: S.Best, +ms: U32) -> Out:
  match b:
    case S.Best{+m, +score}:
      after_move(st.push(s, M.make(st.p(s), m)),
        "AI: " ++ M.m.show(m) ++ " (depth=" ++ U32.show(d) ++ ", eval=" ++
          B.s.show(score) ++ ", time=" ++ U32.show(ms) ++ ")")

def help() -> String:
  "Available commands:\n" ++
  "  new                  - Start a new game\n" ++
  "  move <from><to>[p]   - Make a move (e.g. move e2e4, move e7e8q)\n" ++
  "  undo                 - Undo the last move\n" ++
  "  ai <depth>           - AI makes a move (depth 1-5)\n" ++
  "  fen <string>         - Load a position from FEN\n" ++
  "  export               - Export the position as FEN\n" ++
  "  eval                 - Evaluate the position (White's view)\n" ++
  "  perft <depth>        - Count leaf nodes (depth 1-6)\n" ++
  "  status               - Show the game status\n" ++
  "  hash                 - Show the position hash\n" ++
  "  draws                - Show draw detection status\n" ++
  "  help                 - Show this help\n" ++
  "  quit                 - Exit"
