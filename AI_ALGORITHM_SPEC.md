# Standard AI Algorithm Specification v1.0

## Overview

This document defines a **deterministic, language-agnostic algorithm** for move selection in chess engines. All implementations must follow this specification exactly to ensure consistent, reproducible AI behavior across different programming languages.

The goal is to enable:
- **Reproducibility**: Same position always yields same move
- **Testability**: Precise verification of AI correctness
- **Comparability**: Fair performance comparison across languages
- **Determinism**: No randomness or language-specific behavior

## 1. Core Algorithm: Minimax with Alpha-Beta Pruning

### 1.1 Minimax Function

```pseudocode
function minimax(position, depth, alpha, beta, maximizing_player):
    # Terminal conditions
    if depth == 0:
        return evaluate(position)
    
    legal_moves = generate_legal_moves(position)
    
    # Game end detection
    if legal_moves is empty:
        if is_in_check(position, current_player):
            # Checkmate - return extreme score
            if maximizing_player:
                return -100000
            else:
                return 100000
        else:
            # Stalemate - return draw score
            return 0
    
    # Order moves for better pruning
    ordered_moves = order_moves(legal_moves, position)
    
    if maximizing_player:
        max_eval = -INFINITY
        for move in ordered_moves:
            make_move(position, move)
            eval = minimax(position, depth - 1, alpha, beta, false)
            undo_move(position, move)
            
            max_eval = max(max_eval, eval)
            alpha = max(alpha, eval)
            
            if beta <= alpha:
                break  # Beta cutoff
        
        return max_eval
    else:
        min_eval = +INFINITY
        for move in ordered_moves:
            make_move(position, move)
            eval = minimax(position, depth - 1, alpha, beta, true)
            undo_move(position, move)
            
            min_eval = min(min_eval, eval)
            beta = min(beta, eval)
            
            if beta <= alpha:
                break  # Alpha cutoff
        
        return min_eval
```

### 1.2 Root Move Selection

```pseudocode
function select_best_move(position, depth):
    legal_moves = generate_legal_moves(position)
    
    if legal_moves is empty:
        return null
    
    ordered_moves = order_moves(legal_moves, position)
    
    maximizing = (position.to_move == WHITE)
    best_score = -INFINITY if maximizing else +INFINITY
    best_move = null
    alpha = -INFINITY
    beta = +INFINITY
    
    for move in ordered_moves:
        make_move(position, move)
        
        # Score is from opponent's perspective after our move
        score = minimax(position, depth - 1, alpha, beta, not maximizing)
        
        undo_move(position, move)
        
        # Update best move based on who is moving
        if maximizing:
            if score > best_score or (score == best_score and best_move == null):
                best_score = score
                best_move = move
            alpha = max(alpha, score)
        else:
            if score < best_score or (score == best_score and best_move == null):
                best_score = score
                best_move = move
            beta = min(beta, score)
    
    return best_move, best_score
```

## 2. Position Evaluation Function

The evaluation function must be **deterministic** and follow these exact rules:

### 2.1 Material Evaluation

**Piece Values** (in centipawns):
```
PAWN   = 100
KNIGHT = 320
BISHOP = 330
ROOK   = 500
QUEEN  = 900
KING   = 20000
```

Calculate material balance:
```pseudocode
material_score = 0
for each square on board:
    piece = get_piece(square)
    if piece:
        value = PIECE_VALUES[piece.type]
        if piece.color == WHITE:
            material_score += value
        else:
            material_score -= value
```

### 2.2 Piece-Square Tables

Position bonuses are added based on piece type and square location. Tables are defined for **white pieces** (black pieces use vertically flipped tables).

#### Pawn Table
```
    a   b   c   d   e   f   g   h
8 [  0,  0,  0,  0,  0,  0,  0,  0 ]
7 [ 50, 50, 50, 50, 50, 50, 50, 50 ]
6 [ 10, 10, 20, 30, 30, 20, 10, 10 ]
5 [  5,  5, 10, 25, 25, 10,  5,  5 ]
4 [  0,  0,  0, 20, 20,  0,  0,  0 ]
3 [  5, -5,-10,  0,  0,-10, -5,  5 ]
2 [  5, 10, 10,-20,-20, 10, 10,  5 ]
1 [  0,  0,  0,  0,  0,  0,  0,  0 ]
```

#### Knight Table
```
    a    b    c    d    e    f    g    h
8 [-50, -40, -30, -30, -30, -30, -40, -50 ]
7 [-40, -20,   0,   0,   0,   0, -20, -40 ]
6 [-30,   0,  10,  15,  15,  10,   0, -30 ]
5 [-30,   5,  15,  20,  20,  15,   5, -30 ]
4 [-30,   0,  15,  20,  20,  15,   0, -30 ]
3 [-30,   5,  10,  15,  15,  10,   5, -30 ]
2 [-40, -20,   0,   5,   5,   0, -20, -40 ]
1 [-50, -40, -30, -30, -30, -30, -40, -50 ]
```

#### Bishop Table
```
    a    b    c    d    e    f    g    h
8 [-20, -10, -10, -10, -10, -10, -10, -20 ]
7 [-10,   0,   0,   0,   0,   0,   0, -10 ]
6 [-10,   0,   5,  10,  10,   5,   0, -10 ]
5 [-10,   5,   5,  10,  10,   5,   5, -10 ]
4 [-10,   0,  10,  10,  10,  10,   0, -10 ]
3 [-10,  10,  10,  10,  10,  10,  10, -10 ]
2 [-10,   5,   0,   0,   0,   0,   5, -10 ]
1 [-20, -10, -10, -10, -10, -10, -10, -20 ]
```

#### Rook Table
```
    a   b   c   d   e   f   g   h
8 [  0,  0,  0,  0,  0,  0,  0,  0 ]
7 [  5, 10, 10, 10, 10, 10, 10,  5 ]
6 [ -5,  0,  0,  0,  0,  0,  0, -5 ]
5 [ -5,  0,  0,  0,  0,  0,  0, -5 ]
4 [ -5,  0,  0,  0,  0,  0,  0, -5 ]
3 [ -5,  0,  0,  0,  0,  0,  0, -5 ]
2 [ -5,  0,  0,  0,  0,  0,  0, -5 ]
1 [  0,  0,  0,  5,  5,  0,  0,  0 ]
```

#### Queen Table
```
    a    b    c    d    e    f    g    h
8 [-20, -10, -10,  -5,  -5, -10, -10, -20 ]
7 [-10,   0,   0,   0,   0,   0,   0, -10 ]
6 [-10,   0,   5,   5,   5,   5,   0, -10 ]
5 [ -5,   0,   5,   5,   5,   5,   0,  -5 ]
4 [  0,   0,   5,   5,   5,   5,   0,  -5 ]
3 [-10,   5,   5,   5,   5,   5,   0, -10 ]
2 [-10,   0,   5,   0,   0,   0,   0, -10 ]
1 [-20, -10, -10,  -5,  -5, -10, -10, -20 ]
```

#### King Table (Middle Game)
```
    a    b    c    d    e    f    g    h
8 [-30, -40, -40, -50, -50, -40, -40, -30 ]
7 [-30, -40, -40, -50, -50, -40, -40, -30 ]
6 [-30, -40, -40, -50, -50, -40, -40, -30 ]
5 [-30, -40, -40, -50, -50, -40, -40, -30 ]
4 [-20, -30, -30, -40, -40, -30, -30, -20 ]
3 [-10, -20, -20, -20, -20, -20, -20, -10 ]
2 [ 20,  20,   0,   0,   0,   0,  20,  20 ]
1 [ 20,  30,  10,   0,   0,  10,  30,  20 ]
```

### 2.3 Position Evaluation Algorithm

```pseudocode
function evaluate(position):
    score = 0
    
    # Material and piece-square tables
    for row in 0..7:
        for col in 0..7:
            piece = get_piece(position, row, col)
            if piece:
                piece_value = PIECE_VALUES[piece.type]
                
                # Get position bonus from piece-square table
                # For white: use row as-is (0=rank 1, 7=rank 8)
                # For black: flip vertically (7-row)
                eval_row = row if piece.color == WHITE else (7 - row)
                
                position_bonus = 0
                if piece.type == PAWN:
                    position_bonus = PAWN_TABLE[eval_row][col]
                else if piece.type == KNIGHT:
                    position_bonus = KNIGHT_TABLE[eval_row][col]
                else if piece.type == BISHOP:
                    position_bonus = BISHOP_TABLE[eval_row][col]
                else if piece.type == ROOK:
                    position_bonus = ROOK_TABLE[eval_row][col]
                else if piece.type == QUEEN:
                    position_bonus = QUEEN_TABLE[eval_row][col]
                else if piece.type == KING:
                    position_bonus = KING_TABLE[eval_row][col]
                
                total_value = piece_value + position_bonus
                
                if piece.color == WHITE:
                    score += total_value
                else:
                    score -= total_value
    
    return score
```

**Note**: The evaluation function intentionally does NOT include:
- King safety penalties
- Mobility bonuses
- Pawn structure analysis
- Other heuristics

This keeps the evaluation simple, deterministic, and easy to replicate exactly.

## 3. Move Ordering

Move ordering is crucial for alpha-beta pruning efficiency. Moves must be ordered **deterministically** in this exact sequence:

### 3.1 Move Scoring

```pseudocode
function score_move(move, position):
    score = 0
    
    # 1. Captures (Most Valuable Victim - Least Valuable Attacker)
    target_piece = get_piece(position, move.to_square)
    if target_piece:
        victim_value = PIECE_VALUES[target_piece.type]
        attacker = get_piece(position, move.from_square)
        attacker_value = PIECE_VALUES[attacker.type]
        # MVV-LVA: prioritize valuable victims, prefer cheap attackers
        score += (victim_value * 10) - attacker_value
    
    # 2. Promotions
    if move.promotion:
        score += PIECE_VALUES[move.promotion] * 10
    
    # 3. Center control (d4, d5, e4, e5)
    to_row = move.to_square.row
    to_col = move.to_square.col
    if (to_row == 3 or to_row == 4) and (to_col == 3 or to_col == 4):
        score += 10
    
    # 4. Castling
    if move.is_castling:
        score += 50
    
    return score
```

### 3.2 Deterministic Ordering

When multiple moves have the **same score**, use **algebraic notation** as the tie-breaker:

```pseudocode
function order_moves(moves, position):
    # Score all moves
    move_scores = []
    for move in moves:
        score = score_move(move, position)
        notation = to_algebraic(move)  # e.g., "e2e4", "e7e8q"
        move_scores.append((move, score, notation))
    
    # Sort by: score (descending), then notation (ascending)
    sorted_moves = sort(move_scores, key=(score DESC, notation ASC))
    
    return [move for (move, score, notation) in sorted_moves]
```

**Algebraic Notation Comparison**:
- Format: `<from><to>[promotion]`
- Examples: `a1a2`, `e2e4`, `e7e8q`
- Sort lexicographically (e.g., `a1a2` < `a1a3` < `b1c3`)

This ensures that when two moves have identical scores, the same move is always selected first across all implementations.

## 4. Test Positions for Verification

All implementations must produce **exactly these moves** in these positions:

### 4.1 Test Position 1: Starting Position, Depth 1

```
FEN: rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
Depth: 1
Expected Move: a2a3
Expected Eval: -5 (or close, depending on rounding)
```

**Rationale**: At depth 1, all moves are evaluated at the leaf. The move `a2a3` should be selected based on move ordering (it's alphabetically first among equal-scoring moves).

### 4.2 Test Position 2: Obvious Capture

```
FEN: rnbqkbnr/pppp1ppp/8/4p3/3P4/8/PPP1PPPP/RNBQKBNR w KQkq - 0 2
Depth: 2
Expected Move: d4e5
Expected Eval: ≈ 100 (material advantage)
```

**Rationale**: Capturing the free pawn on e5 is the best move.

### 4.3 Test Position 3: Forced Mate in One

```
FEN: 6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1
Depth: 1
Expected Move: a1a8
Expected Eval: ≈ 100000 (checkmate score)
```

**Rationale**: Back rank mate - only legal winning move.

### 4.4 Test Position 4: Promotion Choice

```
FEN: 4k3/P7/8/8/8/8/8/4K3 w - - 0 1
Depth: 2
Expected Move: a7a8q
Expected Eval: ≈ 900 (queen value gained)
```

**Rationale**: Promoting to queen is the strongest move.

### 4.5 Test Position 5: Deterministic Tie-Breaking

```
FEN: rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
Depth: 2
Expected Move: b1a3
Expected Eval: Variable
```

**Rationale**: Multiple moves may have similar evaluations. The implementation must select `b1a3` based on the deterministic move ordering (score + alphabetic tie-breaking).

## 5. Implementation Requirements

### 5.1 Determinism Checklist

To ensure deterministic behavior:

- ✅ Use exact integer arithmetic (avoid floating-point in evaluation)
- ✅ Use exact piece values and piece-square tables
- ✅ Sort moves deterministically (score DESC, algebraic ASC)
- ✅ Handle ties consistently
- ✅ Do NOT add randomness or "variety"
- ✅ Use consistent board representation (row 0 = rank 1, row 7 = rank 8)

### 5.2 Testing Compliance

An implementation is **compliant** if:

1. It selects the expected moves in all test positions
2. It reports evaluation scores within ±5 centipawns of expected
3. It uses the exact minimax algorithm described
4. It uses the exact evaluation function described
5. It uses the exact move ordering rules

### 5.3 Output Format

When making an AI move, output must be:

```
AI: <move> (depth=<n>, eval=<score>, time=<ms>)
```

Example:
```
AI: e2e4 (depth=3, eval=25, time=450)
```

## 6. Validation Suite

Add these test cases to `test_suite.json`:

```json
{
  "id": "ai_deterministic_start",
  "name": "AI Deterministic - Starting Position",
  "commands": [
    {"cmd": "new"},
    {"cmd": "ai 1"}
  ],
  "expected_patterns": ["AI:", "a2a3"],
  "timeout": 2000
}
```

```json
{
  "id": "ai_obvious_capture",
  "name": "AI Obvious Capture",
  "commands": [
    {"cmd": "fen rnbqkbnr/pppp1ppp/8/4p3/3P4/8/PPP1PPPP/RNBQKBNR w KQkq - 0 2"},
    {"cmd": "ai 2"}
  ],
  "expected_patterns": ["AI:", "d4e5"],
  "timeout": 5000
}
```

```json
{
  "id": "ai_mate_in_one",
  "name": "AI Mate in One",
  "commands": [
    {"cmd": "fen 6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1"},
    {"cmd": "ai 1"}
  ],
  "expected_patterns": ["AI:", "a1a8"],
  "timeout": 2000
}
```

```json
{
  "id": "ai_promotion",
  "name": "AI Promotion",
  "commands": [
    {"cmd": "fen 4k3/P7/8/8/8/8/8/4K3 w - - 0 1"},
    {"cmd": "ai 2"}
  ],
  "expected_patterns": ["AI:", "a7a8"],
  "timeout": 2000
}
```

## 7. Notes for Implementation

### 7.1 Board Coordinate System

The specification assumes:
- **Row 0 = Rank 1** (white's back rank)
- **Row 7 = Rank 8** (black's back rank)
- **Col 0 = File a**, **Col 7 = File h**

If your implementation uses a different system, you must translate coordinates appropriately.

### 7.2 Move Generation Order

Legal move generation does NOT need to be in any specific order, as moves will be sorted by the `order_moves` function.

### 7.3 Performance Considerations

This algorithm prioritizes:
1. **Correctness** - Exact behavior
2. **Reproducibility** - Same results every time
3. **Performance** - Alpha-beta pruning efficiency

Implementations may add performance optimizations (transposition tables, iterative deepening) **as long as** they do not change the selected move for the test positions.

## 8. Frequently Asked Questions

### Q: Why such a simple evaluation function?

**A**: Simplicity ensures exact reproducibility across languages. Complex evaluation functions may have subtle differences in implementation that lead to divergent behavior.

### Q: Can I add my own evaluation features?

**A**: Not if you want to pass the compliance tests. The specification must be followed exactly for deterministic behavior.

### Q: What about openings or endgame databases?

**A**: Not included in this specification. Pure algorithmic play only.

### Q: Why are piece-square tables so important?

**A**: They provide positional understanding while remaining completely deterministic and language-agnostic.

### Q: Can I use different data types (float vs int)?

**A**: Use integer arithmetic for evaluation scores to ensure exact reproducibility. Floats may have rounding differences across platforms.

## 9. Version History

- **v1.0** (2024-11): Initial specification

---

**End of Specification**

This specification ensures that chess engines across different programming languages make **identical decisions** in **identical positions**, enabling fair comparison and rigorous testing.
