# Debug Perft Failure

The perft(4) count from the starting position MUST be exactly 197281. If it's wrong, there's a bug in move generation or validation.

## Debugging Strategy

1. **Compare perft(1-3) first**: perft(1)=20, perft(2)=400, perft(3)=8902, perft(4)=197281
2. **Isolate the depth**: Find the first depth where the count diverges
3. **Use divide**: If available, run `perft divide` to see per-move node counts at depth N-1
4. **Common bugs by category**:

### Castling Issues
- King or rook must not have moved previously
- No pieces between king and rook
- King must not be in check, pass through check, or land in check
- Both kingside (e1g1/e8g8) and queenside (e1c1/e8c8)

### En Passant Issues
- Only valid immediately after opponent's two-square pawn advance
- The en passant target square must be set correctly
- Must remove the captured pawn (not on the target square but adjacent)

### Promotion Issues
- Pawn reaching rank 8 (White) or rank 1 (Black) must promote
- Default to Queen if not specified
- Test all promotion pieces (Q, R, B, N)

### Check/Pin Issues
- Moves that leave own king in check are illegal
- Pinned pieces can only move along the pin ray
- Double check: only king moves are legal

## Reference
- [Chess Engine Specs](../../CHESS_ENGINE_SPECS.md) — see the perft section
