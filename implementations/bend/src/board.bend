# Board representation, position state, FEN import/export and display.
#
# The board is plain Data: eight U32 words, one per rank, each holding eight
# 4-bit squares (file a in the low nibble). Being Data, a position can be
# copied freely with `+`, so search uses copy-make instead of make/unmake.
#
# Square index: sq = rank * 8 + file, rank 0 = rank 1 (White's back rank).
# Piece codes: 0 empty, 1 P, 2 N, 3 B, 4 R, 5 Q, 6 K; black adds 8.
# Signed integers (evaluation scores) are two's complement U32 values.
import Base

type Board is Data:
  Board{r0: U32, r1: U32, r2: U32, r3: U32, r4: U32, r5: U32, r6: U32, r7: U32}

# side: 0 white, 1 black; castle bits: 1 K, 2 Q, 4 k, 8 q; ep: square or 64
type Pos is Data:
  Pos{b: Board, side: U32, castle: U32, ep: U32, half: U32, full: U32}

# Generic helpers
# ---------------

def sel(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

def sel.b(c: Bool, a: Bool, b: Bool) -> Bool:
  match c:
    case True{}:
      a
    case False{}:
      b

def bit(+x: U32, +m: U32) -> Bool:
  U32.is_ne(U32.and(x, m), 0)

def eq(a: U32, b: U32) -> Bool:
  U32.is_eq(a, b)

def neg(a: U32) -> U32:
  U32.sub(0, a)

def s.lt(a: U32, b: U32) -> Bool:
  U32.is_lt(U32.xor(a, 2147483648), U32.xor(b, 2147483648))

def s.max(+a: U32, +b: U32) -> U32:
  sel(s.lt(a, b), b, a)

def s.min(+a: U32, +b: U32) -> U32:
  sel(s.lt(b, a), b, a)

def s.show.go(n: Bool, +a: U32) -> String:
  match n:
    case True{}:
      "-" ++ U32.show(neg(a))
    case False{}:
      U32.show(a)

def s.show(+a: U32) -> String:
  s.show.go(U32.is_ge(a, 2147483648), a)

def chr(c: U32) -> String:
  SCon{Chr{c}, SNil{}}

# Board access
# ------------

def empty_board() -> Board:
  Board{0, 0, 0, 0, 0, 0, 0, 0}

def rank_word(+b: Board, +r: U32) -> U32:
  match b:
    case Board{a0, a1, a2, a3, a4, a5, a6, a7}:
      +b0 = bit(r, 1)
      +b1 = bit(r, 2)
      sel(bit(r, 4),
        sel(b1, sel(b0, a7, a6), sel(b0, a5, a4)),
        sel(b1, sel(b0, a3, a2), sel(b0, a1, a0)))

def get(+b: Board, +sq: U32) -> U32:
  +w = rank_word(b, U32.shrn(sq, 3n))
  U32.and(U32.shrn(w, U32.to_nat(U32.shln(U32.and(sq, 7), 2n))), 15)

def put_word(+r: U32, +w: U32, +b: Board) -> Board:
  match b:
    case Board{a0, a1, a2, a3, a4, a5, a6, a7}:
      Board{sel(eq(r, 0), w, a0), sel(eq(r, 1), w, a1),
        sel(eq(r, 2), w, a2), sel(eq(r, 3), w, a3),
        sel(eq(r, 4), w, a4), sel(eq(r, 5), w, a5),
        sel(eq(r, 6), w, a6), sel(eq(r, 7), w, a7)}

def put(+b: Board, +sq: U32, +v: U32) -> Board:
  +r = U32.shrn(sq, 3n)
  +sh = U32.to_nat(U32.shln(U32.and(sq, 7), 2n))
  +w = rank_word(b, r)
  +nw = U32.or(U32.and(w, U32.not(U32.shln(15, sh))), U32.shln(v, sh))
  put_word(r, nw, b)

# Position accessors
# ------------------

def p.b(+p: Pos) -> Board:
  match p:
    case Pos{b, s, c, e, h, f}:
      b

def p.side(+p: Pos) -> U32:
  match p:
    case Pos{b, s, c, e, h, f}:
      s

def p.castle(+p: Pos) -> U32:
  match p:
    case Pos{b, s, c, e, h, f}:
      c

def p.ep(+p: Pos) -> U32:
  match p:
    case Pos{b, s, c, e, h, f}:
      e

def p.half(+p: Pos) -> U32:
  match p:
    case Pos{b, s, c, e, h, f}:
      h

def p.full(+p: Pos) -> U32:
  match p:
    case Pos{b, s, c, e, h, f}:
      f

def at(+p: Pos, +sq: U32) -> U32:
  get(p.b(p), sq)

# Piece characters
# ----------------

# the FEN letter of a piece code ('.' when empty)
def piece_char(+v: U32) -> U32:
  +t = U32.and(v, 7)
  +w = sel(eq(t, 1), 80, sel(eq(t, 2), 78, sel(eq(t, 3), 66,
    sel(eq(t, 4), 82, sel(eq(t, 5), 81, sel(eq(t, 6), 75, 46))))))
  sel(bit(v, 8), U32.add(w, 32), w)

# the piece code of a FEN letter (0 when not a piece)
def piece_of(+c: U32) -> U32:
  +l = sel(U32.is_ge(c, 97), U32.sub(c, 32), c)
  +t = sel(eq(l, 80), 1, sel(eq(l, 78), 2, sel(eq(l, 66), 3,
    sel(eq(l, 82), 4, sel(eq(l, 81), 5, sel(eq(l, 75), 6, 0))))))
  sel(Bool.and(U32.is_ge(c, 97), U32.is_ne(t, 0)), U32.or(t, 8), t)

def sq_name(+sq: U32) -> String:
  chr(U32.add(97, U32.and(sq, 7))) ++ chr(U32.add(49, U32.shrn(sq, 3n)))

# Starting position
# -----------------

def start_board() -> Board:
  # rank 1: R N B Q K B N R; rank 2: pawns; ranks 7 and 8 mirrored
  Board{1110856484, 286331153, 0, 0, 0, 0, 2576980377, 3401505708}

def start_pos() -> Pos:
  Pos{start_board(), 0, 15, 64, 0, 1}

# FEN import
# ----------

def fen.pl.put(c: Bool, +b: Board, +sq: U32, +v: U32) -> Board:
  match c:
    case True{}:
      put(b, sq, v)
    case False{}:
      b


# walks the placement field; r/f is the cursor, err counts problems
def fen.pl(s: String, +b: Board, +r: U32, +f: U32, +err: U32) -> Board & U32:
  match s:
    case SNil{}:
      (b, U32.add(err, U32.add(Bool.to_u32(U32.is_ne(r, 0)), Bool.to_u32(U32.is_ne(f, 8)))))
    case SCon{Chr{+c}, t}:
      +pc = piece_of(c)
      +slash = eq(c, 47)
      +digit = Bool.and(U32.is_ge(c, 49), U32.is_le(c, 56))
      +bad_slash = Bool.and(slash, Bool.or(U32.is_ne(f, 8), eq(r, 0)))
      +is_pc = U32.is_ne(pc, 0)
      +bad_pc = Bool.and(is_pc, U32.is_ge(f, 8))
      +bad_char = Bool.not(Bool.or(slash, Bool.or(digit, is_pc)))
      +nf = sel(slash, 0, sel(digit, U32.add(f, U32.sub(c, 48)), U32.inc(f)))
      +nr = sel(Bool.and(slash, U32.is_ne(r, 0)), U32.sub(r, 1), r)
      +nb = fen.pl.put(Bool.and(is_pc, U32.is_lt(f, 8)), b, U32.add(U32.shln(r, 3n), f), pc)
      +e1 = U32.add(err, Bool.to_u32(Bool.or(bad_slash, Bool.or(bad_pc, bad_char))))
      +e2 = U32.add(e1, Bool.to_u32(U32.is_gt(nf, 8)))
      fen.pl(t, nb, nr, nf, e2)

def fen.castle(s: String, +acc: U32) -> U32:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{+c}, t}:
      +m = sel(eq(c, 75), 1, sel(eq(c, 81), 2, sel(eq(c, 107), 4,
        sel(eq(c, 113), 8, sel(eq(c, 45), 0, 256)))))
      fen.castle(t, U32.or(acc, m))

# an en passant field: "-" is 64, a square its index, garbage 256
def fen.ep(s: String) -> U32:
  match s:
    case SCon{Chr{+f}, SCon{Chr{+r}, SNil{}}}:
      +ok = Bool.and(Bool.and(U32.is_ge(f, 97), U32.is_le(f, 104)),
        Bool.and(U32.is_ge(r, 49), U32.is_le(r, 56)))
      sel(ok, U32.add(U32.shln(U32.sub(r, 49), 3n), U32.sub(f, 97)), 256)
    case SCon{Chr{+c}, SNil{}}:
      sel(eq(c, 45), 64, 256)
    case _:
      256

def fen.side(s: String) -> U32:
  match s:
    case SCon{Chr{+c}, SNil{}}:
      sel(eq(c, 119), 0, sel(eq(c, 98), 1, 256))
    case _:
      256

def fen.num(s: String, d: U32) -> U32:
  Maybe.default(&2, U32, U32.read(s), d)

def fen.done(ok: Bool, +k: Board, +side: U32, +cs: U32, +ep: U32, +h: U32,
  +fu: U32) -> Maybe<&2, Pos>:
  match ok:
    case True{}:
      Some{Pos{k, side, U32.and(cs, 15), ep, h, sel(eq(fu, 0), 1, fu)}}
    case False{}:
      None{}

def fen.fin(r: Board & U32, +side: U32, +cs: U32, +ep: U32, +h: U32, +fu: U32) -> Maybe<&2, Pos>:
  (k, +n) = r
  fen.done(U32.is_lt(U32.or(U32.or(sel(eq(n, 0), 0, 256), side), U32.or(cs, ep)), 256), k, side, cs, ep, h, fu)

def fen.parse(xs: List<&2, String>) -> Maybe<&2, Pos>:
  match xs:
    case Con{pl, Con{sd, Con{cs, Con{ep, Con{h, Con{fu, Nil{}}}}}}}:
      fen.fin(fen.pl(pl, empty_board(), 7, 0, 0), fen.side(sd), fen.castle(cs, 0),
        fen.ep(ep), fen.num(h, 0), fen.num(fu, 1))
    case Con{pl, Con{sd, Con{cs, Con{ep, Nil{}}}}}:
      fen.fin(fen.pl(pl, empty_board(), 7, 0, 0), fen.side(sd), fen.castle(cs, 0),
        fen.ep(ep), 0, 1)
    case _:
      None{}

def drop_empty.go(e: Bool, h: String, t: List<&2, String>) -> List<&2, String>:
  match e:
    case True{}:
      t
    case False{}:
      h <> t


def drop_empty(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+h, t}:
      drop_empty.go(String.is_empty(h), h, drop_empty(t))

def fen.read(s: String) -> Maybe<&2, Pos>:
  fen.parse(drop_empty(String.split(s, ' ')))

# FEN export
# ----------

def sel.s(c: Bool, a: String, b: String) -> String:
  match c:
    case True{}:
      a
    case False{}:
      b

# one rank of the placement, files f..7, n empty squares pending

def fen.gap(+n: U32) -> String:
  sel.s(U32.is_zero(n), "", U32.show(n))

def fen.rank(k: Nat, +b: Board, +sq: U32, +n: U32) -> String:
  match k:
    case 0n:
      fen.gap(n)
    case 1n+k2:
      +v = get(b, sq)
      +e = U32.is_zero(v)
      sel.s(e, "", fen.gap(n) ++ chr(piece_char(v))) ++
        fen.rank(k2, b, U32.inc(sq), sel(e, U32.inc(n), 0))

def fen.ranks(+k: Nat, +b: Board) -> String:
  match k:
    case 0n:
      ""
    case 1n+k2:
      +r = U32.from_nat(k2)
      fen.rank(8n, b, U32.shln(r, 3n), 0) ++ sel.s(U32.is_zero(r), "", "/") ++ fen.ranks(k2, b)

def fen.castle_str(+c: U32) -> String:
  +s = sel.s(bit(c, 1), "K", "") ++ sel.s(bit(c, 2), "Q", "") ++
    sel.s(bit(c, 4), "k", "") ++ sel.s(bit(c, 8), "q", "")
  sel.s(U32.is_zero(c), "-", s)

def fen.write(+p: Pos) -> String:
  match p:
    case Pos{+b, +s, +c, +e, +h, +f}:
      fen.ranks(8n, b) ++ " " ++ sel.s(U32.is_zero(s), "w", "b") ++ " " ++
        fen.castle_str(c) ++ " " ++ sel.s(U32.is_lt(e, 64), sq_name(e), "-") ++
        " " ++ U32.show(h) ++ " " ++ U32.show(f)

# Display
# -------

def show.rank(k: Nat, +b: Board, +sq: U32) -> String:
  match k:
    case 0n:
      ""
    case 1n+k2:
      " " ++ chr(piece_char(get(b, sq))) ++ show.rank(k2, b, U32.inc(sq))

def show.ranks(+k: Nat, +b: Board) -> String:
  match k:
    case 0n:
      ""
    case 1n+k2:
      +r = U32.from_nat(k2)
      +lbl = U32.show(U32.inc(r))
      lbl ++ show.rank(8n, b, U32.shln(r, 3n)) ++ " " ++ lbl ++ "\n" ++ show.ranks(k2, b)

def show(+p: Pos) -> String:
  "  a b c d e f g h\n" ++ show.ranks(8n, p.b(p)) ++ "  a b c d e f g h\n\n" ++
    sel.s(U32.is_zero(p.side(p)), "White", "Black") ++ " to move"
