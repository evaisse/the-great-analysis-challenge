# Move generation, attack detection and move execution.
#
# A move is one U32: from | to << 6 | promotion << 12 (piece type 2..5, or 0).
# Coordinates walk as (file, rank) pairs of U32; a step of -1 is 4294967295,
# so stepping off the board wraps to a huge value and fails the `< 8` test.
#
# A `match` may only inspect parameters, so every loop receives the Bool that
# decides its next step precomputed by its caller (the style of Bend's own
# benchmarks), and every recursion counts down a Nat fuel, so all defs here
# are proven to terminate.
import Base
import ./board.bend as B

# Move encoding
# -------------

def mv(+from: U32, +to: U32, +promo: U32) -> U32:
  U32.or(U32.or(from, U32.shln(to, 6n)), U32.shln(promo, 12n))

def m.from(+m: U32) -> U32:
  U32.and(m, 63)

def m.to(+m: U32) -> U32:
  U32.and(U32.shrn(m, 6n), 63)

def m.promo(+m: U32) -> U32:
  U32.and(U32.shrn(m, 12n), 7)

def m.show(+m: U32) -> String:
  +pr = m.promo(m)
  B.sq_name(m.from(m)) ++ B.sq_name(m.to(m)) ++
    B.sel.s(U32.is_zero(pr), "", B.chr(U32.add(B.piece_char(pr), 32)))

# Board geometry
# --------------

def on(+f: U32, +r: U32) -> Bool:
  Bool.and(U32.is_lt(f, 8), U32.is_lt(r, 8))

def sq(+f: U32, +r: U32) -> U32:
  U32.add(U32.shln(r, 3n), f)

# the piece at (f, r), or 255 off the board
def pc_at(+b: B.Board, +f: U32, +r: U32) -> U32:
  B.sel(on(f, r), B.get(b, U32.and(sq(f, r), 63)), 255)

def color(+v: U32) -> U32:
  U32.and(v, 8)

def is_enemy(+v: U32, +me: U32) -> Bool:
  Bool.and(Bool.and(U32.is_ne(v, 0), U32.is_ne(v, 255)), U32.is_ne(color(v), me))

def cons_if(c: Bool, m: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match c:
    case True{}:
      m <> acc
    case False{}:
      acc

# Attacks
# -------

# the first piece met along a ray from (f, r): 0 when none; z says whether
# the current square is empty, so the walk goes on
def ray(n: Nat, z: Bool, +v: U32, +b: B.Board, +f: U32, +r: U32, +df: U32,
  +dr: U32) -> U32:
  match n z:
    case 1n+k True{}:
      +nf = U32.add(f, df)
      +nr = U32.add(r, dr)
      +nv = pc_at(b, nf, nr)
      ray(k, B.eq(nv, 0), nv, b, nf, nr, df, dr)
    case _ _:
      B.sel(B.eq(v, 255), 0, v)

def ray_from(+b: B.Board, +f: U32, +r: U32, +df: U32, +dr: U32) -> U32:
  ray(8n, True{}, 0, b, f, r, df, dr)

# does the ray end on one of the two piece codes x, y?
def ray_is(+b: B.Board, +f: U32, +r: U32, +df: U32, +dr: U32, +x: U32, +y: U32) -> Bool:
  +v = ray_from(b, f, r, df, dr)
  Bool.or(B.eq(v, x), B.eq(v, y))

def hit(+b: B.Board, +f: U32, +r: U32, +df: U32, +dr: U32, +x: U32) -> Bool:
  B.eq(pc_at(b, U32.add(f, df), U32.add(r, dr)), x)

# is the square (f, r) attacked by color `by` (0 white, 8 black)?
def attacked(+b: B.Board, +f: U32, +r: U32, +by: U32) -> Bool:
  +m1 = {4294967295 : U32}
  +m2 = {4294967294 : U32}
  +pawn = U32.or(1, by)
  +knight = U32.or(2, by)
  +bishop = U32.or(3, by)
  +rook = U32.or(4, by)
  +queen = U32.or(5, by)
  +king = U32.or(6, by)
  # a white pawn attacks upwards, so it sits one rank below the square
  +pr = B.sel(B.eq(by, 0), m1, 1)
  +pawns = Bool.or(hit(b, f, r, m1, pr, pawn), hit(b, f, r, 1, pr, pawn))
  +knights = Bool.or(
    Bool.or(Bool.or(hit(b, f, r, 1, 2, knight), hit(b, f, r, 2, 1, knight)),
      Bool.or(hit(b, f, r, 2, m1, knight), hit(b, f, r, 1, m2, knight))),
    Bool.or(Bool.or(hit(b, f, r, m1, m2, knight), hit(b, f, r, m2, m1, knight)),
      Bool.or(hit(b, f, r, m2, 1, knight), hit(b, f, r, m1, 2, knight))))
  +kings = Bool.or(
    Bool.or(Bool.or(hit(b, f, r, 1, 0, king), hit(b, f, r, m1, 0, king)),
      Bool.or(hit(b, f, r, 0, 1, king), hit(b, f, r, 0, m1, king))),
    Bool.or(Bool.or(hit(b, f, r, 1, 1, king), hit(b, f, r, 1, m1, king)),
      Bool.or(hit(b, f, r, m1, 1, king), hit(b, f, r, m1, m1, king))))
  +lines = Bool.or(
    Bool.or(ray_is(b, f, r, 1, 0, rook, queen), ray_is(b, f, r, m1, 0, rook, queen)),
    Bool.or(ray_is(b, f, r, 0, 1, rook, queen), ray_is(b, f, r, 0, m1, rook, queen)))
  +diags = Bool.or(
    Bool.or(ray_is(b, f, r, 1, 1, bishop, queen), ray_is(b, f, r, 1, m1, bishop, queen)),
    Bool.or(ray_is(b, f, r, m1, 1, bishop, queen), ray_is(b, f, r, m1, m1, bishop, queen)))
  Bool.or(Bool.or(pawns, knights), Bool.or(kings, Bool.or(lines, diags)))

def attacked_sq(+b: B.Board, +s: U32, +by: U32) -> Bool:
  attacked(b, U32.and(s, 7), U32.shrn(s, 3n), by)

# the square of the piece code v (64 when absent)
def find(n: Nat, +b: B.Board, +s: U32, +v: U32) -> U32:
  match n:
    case 0n:
      64
    case 1n+k:
      B.sel(B.eq(B.get(b, s), v), s, find(k, b, U32.inc(s), v))

def king_sq(+b: B.Board, +me: U32) -> U32:
  find(64n, b, 0, U32.or(6, me))

def in_check(+p: B.Pos) -> Bool:
  +me = U32.shln(B.p.side(p), 3n)
  +b = B.p.b(p)
  +k = king_sq(b, me)
  Bool.and(U32.is_lt(k, 64), attacked_sq(b, k, U32.xor(me, 8)))

# Pseudo-legal generation
# -----------------------

# slides from (f, r) along (df, dr); go says whether the last square was
# empty, so the slide continues
def slide(n: Nat, go: Bool, +b: B.Board, +from: U32, +f: U32, +r: U32,
  +df: U32, +dr: U32, +me: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match n go:
    case 1n+k True{}:
      +nf = U32.add(f, df)
      +nr = U32.add(r, dr)
      +v = pc_at(b, nf, nr)
      +empty = B.eq(v, 0)
      +ok = Bool.or(empty, is_enemy(v, me))
      slide(k, empty, b, from, nf, nr, df, dr, me,
        cons_if(ok, mv(from, U32.and(sq(nf, nr), 63), 0), acc))
    case _ _:
      acc

def slide_from(+b: B.Board, +from: U32, +df: U32, +dr: U32, +me: U32,
  acc: List<&2, U32>) -> List<&2, U32>:
  slide(8n, True{}, b, from, U32.and(from, 7), U32.shrn(from, 3n), df, dr, me, acc)

def lines(+b: B.Board, +from: U32, +me: U32, acc: List<&2, U32>) -> List<&2, U32>:
  +m1 = {4294967295 : U32}
  slide_from(b, from, 1, 0, me, slide_from(b, from, m1, 0, me,
    slide_from(b, from, 0, 1, me, slide_from(b, from, 0, m1, me, acc))))

def diags(+b: B.Board, +from: U32, +me: U32, acc: List<&2, U32>) -> List<&2, U32>:
  +m1 = {4294967295 : U32}
  slide_from(b, from, 1, 1, me, slide_from(b, from, 1, m1, me,
    slide_from(b, from, m1, 1, me, slide_from(b, from, m1, m1, me, acc))))

# one step to (f + df, r + dr) onto an empty or enemy square
def step(+b: B.Board, +from: U32, +df: U32, +dr: U32, +me: U32,
  acc: List<&2, U32>) -> List<&2, U32>:
  +nf = U32.add(U32.and(from, 7), df)
  +nr = U32.add(U32.shrn(from, 3n), dr)
  +v = pc_at(b, nf, nr)
  cons_if(Bool.or(B.eq(v, 0), is_enemy(v, me)), mv(from, U32.and(sq(nf, nr), 63), 0), acc)

def knight(+b: B.Board, +from: U32, +me: U32, acc: List<&2, U32>) -> List<&2, U32>:
  +m1 = {4294967295 : U32}
  +m2 = {4294967294 : U32}
  step(b, from, 1, 2, me, step(b, from, 2, 1, me, step(b, from, 2, m1, me,
    step(b, from, 1, m2, me, step(b, from, m1, m2, me, step(b, from, m2, m1, me,
    step(b, from, m2, 1, me, step(b, from, m1, 2, me, acc))))))))

def king_steps(+b: B.Board, +from: U32, +me: U32, acc: List<&2, U32>) -> List<&2, U32>:
  +m1 = {4294967295 : U32}
  step(b, from, 1, 0, me, step(b, from, m1, 0, me, step(b, from, 0, 1, me,
    step(b, from, 0, m1, me, step(b, from, 1, 1, me, step(b, from, 1, m1, me,
    step(b, from, m1, 1, me, step(b, from, m1, m1, me, acc))))))))

# castling: rights, empty squares between, king not crossing attacked squares
def castle(+p: B.Pos, +from: U32, +me: U32, acc: List<&2, U32>) -> List<&2, U32>:
  +b = B.p.b(p)
  +c = B.p.castle(p)
  +op = U32.xor(me, 8)
  +home = B.sel(B.eq(me, 0), 4, 60)
  +at_home = B.eq(from, home)
  +ksb = B.sel(B.eq(me, 0), 1, 4)
  +qsb = B.sel(B.eq(me, 0), 2, 8)
  +safe = Bool.and(at_home, Bool.not(attacked_sq(b, from, op)))
  +ks = Bool.and(Bool.and(safe, B.bit(c, ksb)),
    Bool.and(Bool.and(B.eq(B.get(b, U32.add(from, 1)), 0), B.eq(B.get(b, U32.add(from, 2)), 0)),
      Bool.and(B.eq(B.get(b, U32.add(from, 3)), U32.or(4, me)),
        Bool.and(Bool.not(attacked_sq(b, U32.add(from, 1), op)),
          Bool.not(attacked_sq(b, U32.add(from, 2), op))))))
  +qs = Bool.and(Bool.and(safe, B.bit(c, qsb)),
    Bool.and(Bool.and(B.eq(B.get(b, U32.sub(from, 1)), 0), B.eq(B.get(b, U32.sub(from, 2)), 0)),
      Bool.and(Bool.and(B.eq(B.get(b, U32.sub(from, 3)), 0), B.eq(B.get(b, U32.sub(from, 4)), U32.or(4, me))),
        Bool.and(Bool.not(attacked_sq(b, U32.sub(from, 1), op)),
          Bool.not(attacked_sq(b, U32.sub(from, 2), op))))))
  cons_if(ks, mv(from, U32.add(from, 2), 0), cons_if(qs, mv(from, U32.sub(from, 2), 0), acc))

# a pawn move to `to`, expanded into the four promotions on the last rank
def pawn_to(+c: Bool, +from: U32, +to: U32, acc: List<&2, U32>) -> List<&2, U32>:
  +last = Bool.or(U32.is_lt(to, 8), U32.is_ge(to, 56))
  +promo = Bool.and(c, last)
  cons_if(Bool.and(c, Bool.not(last)), mv(from, to, 0),
    cons_if(promo, mv(from, to, 5), cons_if(promo, mv(from, to, 4),
      cons_if(promo, mv(from, to, 3), cons_if(promo, mv(from, to, 2), acc)))))

def pawn(+p: B.Pos, +from: U32, +me: U32, acc: List<&2, U32>) -> List<&2, U32>:
  +b = B.p.b(p)
  +ep = B.p.ep(p)
  +f = U32.and(from, 7)
  +r = U32.shrn(from, 3n)
  +dr = B.sel(B.eq(me, 0), 1, 4294967295)
  +start = B.sel(B.eq(me, 0), 1, 6)
  +r1 = U32.add(r, dr)
  +one = B.eq(pc_at(b, f, r1), 0)
  +two = Bool.and(Bool.and(one, B.eq(r, start)), B.eq(pc_at(b, f, U32.add(r1, dr)), 0))
  +fl = U32.sub(f, 1)
  +fr = U32.add(f, 1)
  +cl = Bool.or(is_enemy(pc_at(b, fl, r1), me), Bool.and(on(fl, r1), B.eq(sq(fl, r1), ep)))
  +cr = Bool.or(is_enemy(pc_at(b, fr, r1), me), Bool.and(on(fr, r1), B.eq(sq(fr, r1), ep)))
  pawn_to(one, from, U32.and(sq(f, r1), 63),
    cons_if(two, mv(from, U32.and(sq(f, U32.add(r1, dr)), 63), 0),
      pawn_to(cl, from, U32.and(sq(fl, r1), 63), pawn_to(cr, from, U32.and(sq(fr, r1), 63), acc))))

# dispatch on the piece type t, one Bool per stage
def gen.k(c: Bool, +p: B.Pos, +from: U32, +me: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match c:
    case True{}:
      king_steps(B.p.b(p), from, me, castle(p, from, me, acc))
    case False{}:
      acc

def gen.q(c: Bool, +t: U32, +p: B.Pos, +from: U32, +me: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match c:
    case True{}:
      lines(B.p.b(p), from, me, diags(B.p.b(p), from, me, acc))
    case False{}:
      gen.k(B.eq(t, 6), p, from, me, acc)

def gen.r(c: Bool, +t: U32, +p: B.Pos, +from: U32, +me: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match c:
    case True{}:
      lines(B.p.b(p), from, me, acc)
    case False{}:
      gen.q(B.eq(t, 5), t, p, from, me, acc)

def gen.b(c: Bool, +t: U32, +p: B.Pos, +from: U32, +me: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match c:
    case True{}:
      diags(B.p.b(p), from, me, acc)
    case False{}:
      gen.r(B.eq(t, 4), t, p, from, me, acc)

def gen.n(c: Bool, +t: U32, +p: B.Pos, +from: U32, +me: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match c:
    case True{}:
      knight(B.p.b(p), from, me, acc)
    case False{}:
      gen.b(B.eq(t, 3), t, p, from, me, acc)

def gen.p(c: Bool, +t: U32, +p: B.Pos, +from: U32, +me: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match c:
    case True{}:
      pawn(p, from, me, acc)
    case False{}:
      gen.n(B.eq(t, 2), t, p, from, me, acc)

def gen.own(c: Bool, +v: U32, +p: B.Pos, +from: U32, +me: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match c:
    case True{}:
      +t = U32.and(v, 7)
      gen.p(B.eq(t, 1), t, p, from, me, acc)
    case False{}:
      acc

# squares 63 down to 0, so the list comes out in ascending square order
def gen.all(n: Nat, +p: B.Pos, +s: U32, +me: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match n:
    case 0n:
      acc
    case 1n+k:
      +v = B.at(p, s)
      +own = Bool.and(U32.is_ne(v, 0), B.eq(color(v), me))
      gen.all(k, p, U32.sub(s, 1), me, gen.own(own, v, p, s, me, acc))

def pseudo(+p: B.Pos) -> List<&2, U32>:
  gen.all(64n, p, 63, U32.shln(B.p.side(p), 3n), Nil{})

# Move execution
# --------------

def put_if(c: Bool, +b: B.Board, +s: U32, +v: U32) -> B.Board:
  match c:
    case True{}:
      B.put(b, s, v)
    case False{}:
      b

# the castling rights a move touching square s keeps
def keep_rights(+s: U32) -> U32:
  B.sel(B.eq(s, 0), 13, B.sel(B.eq(s, 7), 14, B.sel(B.eq(s, 4), 12,
    B.sel(B.eq(s, 56), 7, B.sel(B.eq(s, 63), 11, B.sel(B.eq(s, 60), 3, 15))))))

def make(+p: B.Pos, +m: U32) -> B.Pos:
  match p:
    case B.Pos{+b, +side, +cs, +ep, +half, +full}:
      +from = m.from(m)
      +to = m.to(m)
      +pr = m.promo(m)
      +v = B.get(b, from)
      +t = U32.and(v, 7)
      +me = color(v)
      +cap = B.get(b, to)
      +is_pawn = B.eq(t, 1)
      +is_ep = Bool.and(Bool.and(is_pawn, B.eq(to, ep)), U32.is_ne(U32.and(from, 7), U32.and(to, 7)))
      +ep_cap = B.sel(B.eq(me, 0), U32.sub(to, 8), U32.add(to, 8))
      +last = Bool.or(U32.is_lt(to, 8), U32.is_ge(to, 56))
      +placed = B.sel(Bool.and(is_pawn, last), U32.or(B.sel(U32.is_zero(pr), 5, pr), me), v)
      +king = B.eq(t, 6)
      +ks = Bool.and(king, B.eq(to, U32.add(from, 2)))
      +qs = Bool.and(king, B.eq(U32.add(to, 2), from))
      +rook = U32.or(4, me)
      +b1 = B.put(B.put(b, from, 0), to, placed)
      +b2 = put_if(is_ep, b1, ep_cap, 0)
      +b3 = put_if(ks, put_if(ks, b2, U32.add(from, 3), 0), U32.add(from, 1), rook)
      +b4 = put_if(qs, put_if(qs, b3, U32.sub(from, 4), 0), U32.sub(from, 1), rook)
      +dbl = Bool.and(is_pawn, Bool.or(B.eq(to, U32.add(from, 16)), B.eq(from, U32.add(to, 16))))
      +nep = B.sel(dbl, U32.shrn(U32.add(from, to), 1n), 64)
      +ncs = U32.and(cs, U32.and(keep_rights(from), keep_rights(to)))
      +reset = Bool.or(is_pawn, Bool.or(U32.is_ne(cap, 0), is_ep))
      B.Pos{b4, U32.xor(side, 1), ncs, nep, B.sel(reset, 0, U32.inc(half)),
        B.sel(B.eq(side, 1), U32.inc(full), full)}

# Legal moves
# -----------

# a move is legal when the mover's king is not attacked afterwards
def legal_after(+q: B.Pos) -> Bool:
  +me = U32.shln(U32.xor(B.p.side(q), 1), 3n)
  +b = B.p.b(q)
  Bool.not(attacked_sq(b, king_sq(b, me), U32.xor(me, 8)))

def keep_legal(+p: B.Pos, ms: List<&2, U32>) -> List<&2, U32>:
  match ms:
    case Nil{}:
      Nil{}
    case Con{+m, t}:
      cons_if(legal_after(make(p, m)), m, keep_legal(p, t))

def legal(+p: B.Pos) -> List<&2, U32>:
  keep_legal(p, pseudo(p))
