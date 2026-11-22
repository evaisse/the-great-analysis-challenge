# Evaluation, deterministic move ordering, perft and minimax with
# alpha-beta pruning, as specified in AI_ALGORITHM_SPEC.md.
#
# Scores are signed integers held in U32 (two's complement), compared with
# B.s.lt. Every recursion is structural: perft and alpha-beta are each one
# def walking (depth, move list), so Bend proves they terminate.
import Base
import ./board.bend as B
import ./moves.bend as M
import ./pst.bend as T

# Evaluation
# ----------

def value(+t: U32) -> U32:
  B.sel(B.eq(t, 1), 100, B.sel(B.eq(t, 2), 320, B.sel(B.eq(t, 3), 330,
    B.sel(B.eq(t, 4), 500, B.sel(B.eq(t, 5), 900, B.sel(B.eq(t, 6), 20000, 0))))))

# the signed contribution of the piece v standing on square s
def piece_score(+v: U32, +s: U32) -> U32:
  +t = U32.and(v, 7)
  +black = B.bit(v, 8)
  +idx = B.sel(black, U32.xor(s, 56), s)
  +total = B.sel(U32.is_zero(t), 0, U32.add(value(t), T.pst(t, idx)))
  B.sel(black, B.neg(total), total)

def eval.go(n: Nat, +b: B.Board, +s: U32, +acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+k:
      eval.go(k, b, U32.inc(s), U32.add(acc, piece_score(B.get(b, s), s)))

def evaluate(+p: B.Pos) -> U32:
  eval.go(64n, B.p.b(p), 0, 0)

# Move ordering
# -------------

def score_move(+p: B.Pos, +m: U32) -> U32:
  +b = B.p.b(p)
  +from = M.m.from(m)
  +to = M.m.to(m)
  +pr = M.m.promo(m)
  +victim = B.get(b, to)
  +attacker = U32.and(B.get(b, from), 7)
  +cap = B.sel(U32.is_zero(victim), 0,
    U32.sub(U32.mul(value(U32.and(victim, 7)), 10), value(attacker)))
  +promo = U32.mul(value(pr), 10)
  +tf = U32.and(to, 7)
  +tr = U32.shrn(to, 3n)
  +center = Bool.and(Bool.or(B.eq(tr, 3), B.eq(tr, 4)), Bool.or(B.eq(tf, 3), B.eq(tf, 4)))
  +castle = Bool.and(B.eq(attacker, 6),
    Bool.or(B.eq(to, U32.add(from, 2)), B.eq(U32.add(to, 2), from)))
  U32.add(U32.add(cap, promo), U32.add(B.sel(center, 10, 0), B.sel(castle, 50, 0)))

# the promotion letter's rank in algebraic order: none, b, n, q, r
def promo_rank(+pr: U32) -> U32:
  B.sel(B.eq(pr, 3), 1, B.sel(B.eq(pr, 2), 2, B.sel(B.eq(pr, 5), 3, B.sel(B.eq(pr, 4), 4, 0))))

def promo_of_rank(+k: U32) -> U32:
  B.sel(B.eq(k, 1), 3, B.sel(B.eq(k, 2), 2, B.sel(B.eq(k, 3), 5, B.sel(B.eq(k, 4), 4, 0))))

# a sort key: (32767 - score) above the notation's own order, so an
# ascending sort gives score descending, then notation ascending; the key
# alone encodes the move
def order_key(+p: B.Pos, +m: U32) -> U32:
  +from = M.m.from(m)
  +to = M.m.to(m)
  +n1 = U32.or(U32.shln(U32.and(from, 7), 3n), U32.shrn(from, 3n))
  +n2 = U32.or(U32.shln(U32.and(to, 7), 3n), U32.shrn(to, 3n))
  +notation = U32.or(U32.shln(U32.or(U32.shln(n1, 6n), n2), 3n), promo_rank(M.m.promo(m)))
  U32.or(U32.shln(U32.sub(32767, score_move(p, m)), 15n), notation)

def key_move(+k: U32) -> U32:
  +ff = U32.and(U32.shrn(k, 12n), 7)
  +fr = U32.and(U32.shrn(k, 9n), 7)
  +tf = U32.and(U32.shrn(k, 6n), 7)
  +tr = U32.and(U32.shrn(k, 3n), 7)
  M.mv(M.sq(ff, fr), M.sq(tf, tr), promo_of_rank(U32.and(k, 7)))

def keys(+p: B.Pos, ms: List<&2, U32>) -> List<&2, U32>:
  match ms:
    case Nil{}:
      Nil{}
    case Con{+m, t}:
      order_key(p, m) <> keys(p, t)

def unkeys(ks: List<&2, U32>) -> List<&2, U32>:
  match ks:
    case Nil{}:
      Nil{}
    case Con{+k, t}:
      key_move(k) <> unkeys(t)

def order(+p: B.Pos, ms: List<&2, U32>) -> List<&2, U32>:
  unkeys(List.sort(~U32, ~U32.is_le, keys(p, ms)))

# Perft
# -----

def count(ms: List<&2, U32>) -> U32:
  match ms:
    case Nil{}:
      0
    case Con{m, t}:
      U32.inc(count(t))

# the leaves d plies below each move of ms played from p
def perft.go(+d: Nat, ms: List<&2, U32>, +p: B.Pos) -> U32:
  match d ms:
    case _ Nil{}:
      0
    case 0n Con{m, t}:
      U32.inc(perft.go(d, t, p))
    case 1n+k Con{+m, t}:
      +q = M.make(p, m)
      U32.add(perft.go(k, M.legal(q), q), perft.go(d, t, p))

def perft(+d: Nat, +p: B.Pos) -> U32:
  match d:
    case 0n:
      1
    case 1n+k:
      perft.go(k, M.legal(p), p)

# Alpha-beta
# ----------

def inf() -> U32:
  1000000

# the score a node starts from: its mate or stalemate score when it has no
# move, else the worst bound for the side to move
def start_score(+empty: Bool, +q: B.Pos, +maxi: Bool) -> U32:
  +mate = B.sel(maxi, B.neg(100000), 100000)
  +none = B.sel(M.in_check(q), mate, 0)
  B.sel(empty, none, B.sel(maxi, B.neg(inf()), inf()))

def is_empty(+ms: List<&2, U32>) -> Bool:
  List.is_empty(&2, U32, ms)

# Scans the moves of a node at p, its children searched d plies deep; stop
# carries the cutoff of the previous move. Returns the node's score.
def ab(+d: Nat, ms: List<&2, U32>, stop: Bool, +p: B.Pos, +alpha: U32,
  +beta: U32, +maxi: Bool, +best: U32) -> U32:
  match d ms stop:
    case _ _ True{}:
      best
    case _ Nil{} False{}:
      best
    case 0n Con{+m, t} False{}:
      +score = evaluate(M.make(p, m))
      +nb = B.sel(maxi, B.s.max(best, score), B.s.min(best, score))
      +na = B.sel(maxi, B.s.max(alpha, score), alpha)
      +nbeta = B.sel(maxi, beta, B.s.min(beta, score))
      ab(d, t, Bool.not(B.s.lt(na, nbeta)), p, na, nbeta, maxi, nb)
    case 1n+k Con{+m, t} False{}:
      +q = M.make(p, m)
      +cm = M.legal(q)
      +cmaxi = Bool.not(maxi)
      +score = ab(k, order(q, cm), False{}, q, alpha, beta, cmaxi,
        start_score(is_empty(cm), q, cmaxi))
      +nb = B.sel(maxi, B.s.max(best, score), B.s.min(best, score))
      +na = B.sel(maxi, B.s.max(alpha, score), alpha)
      +nbeta = B.sel(maxi, beta, B.s.min(beta, score))
      ab(d, t, Bool.not(B.s.lt(na, nbeta)), p, na, nbeta, maxi, nb)

# the minimax value of the position q, depth plies deep
def minimax(+depth: Nat, +q: B.Pos, +alpha: U32, +beta: U32, +maxi: Bool) -> U32:
  match depth:
    case 0n:
      evaluate(q)
    case 1n+k:
      +cm = M.legal(q)
      ab(k, order(q, cm), False{}, q, alpha, beta, maxi, start_score(is_empty(cm), q, maxi))

type Best is Data:
  Best{move: U32, score: U32}

# the root: every move is searched (no cutoff), the first strictly better
# score wins, so ties keep the earlier move in the deterministic order
def root(ms: List<&2, U32>, +k: Nat, +p: B.Pos, +alpha: U32, +beta: U32,
  +maxi: Bool, +bm: U32, +bs: U32) -> Best:
  match ms:
    case Nil{}:
      Best{bm, bs}
    case Con{+m, t}:
      +score = minimax(k, M.make(p, m), alpha, beta, Bool.not(maxi))
      +better = B.sel.b(maxi, B.s.lt(bs, score), B.s.lt(score, bs))
      +na = B.sel(maxi, B.s.max(alpha, score), alpha)
      +nbeta = B.sel(maxi, beta, B.s.min(beta, score))
      root(t, k, p, na, nbeta, maxi, B.sel(better, m, bm), B.sel(better, score, bs))

# the best move at depth >= 1 (65535 when there is none)
def best_move(+depth: Nat, +p: B.Pos) -> Best:
  match depth:
    case 0n:
      Best{65535, 0}
    case 1n+k:
      +maxi = B.eq(B.p.side(p), 0)
      root(order(p, M.legal(p)), k, p, B.neg(inf()), inf(), maxi, 65535,
        B.sel(maxi, B.neg(inf()), inf()))
