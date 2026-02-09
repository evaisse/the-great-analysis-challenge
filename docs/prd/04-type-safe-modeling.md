# PRD-04 : Modélisation type-safe (Board\<State\>, Move\<Legal\>, Branded Types)

## Résumé

Refactorer le modèle de données du moteur pour exploiter les systèmes de types avancés de chaque langage : types fantômes (phantom types), types de marque (branded/opaque types), generics contraints, et types dépendants légers. L'objectif est de rendre les erreurs de logique échiquéenne détectables à la compilation plutôt qu'à l'exécution.

## Métriques cibles

| Indicateur | Valeur |
|---|---|
| LOC ajoutées par langage | +400 – 1 200 |
| LOC totales ajoutées (×7) | ~2 800 – 8 400 |
| Priorité | **P2 — Stress typé (compile-time)** |

## Pertinence pour le projet

### Valeur fonctionnelle (moteur d'échecs)

Le modèle actuel utilise des types basiques (`int` pour les cases, `string` pour les coups, `array` pour le plateau). Cela permet des bugs silencieux :

```python
# Actuellement possible — aucune erreur détectée :
move(42, -1)           # Cases invalides
board.set(row=3, col=9, piece=KING)  # Colonne hors bornes
apply_move(illegal_move)  # Coup non validé
```

Avec une modélisation type-safe :

```typescript
// Erreur de compilation :
move(Square(42), Square(-1))  // Square ne peut contenir que 0-63
board.set<Legal>(illegal_move) // Type Move<Legal> requis, Move<Unchecked> fourni
```

Concrètement :
- **`Square`** : type opaque garantissant 0 ≤ value ≤ 63
- **`Move<Legal>` vs `Move<Unchecked>`** : un coup doit être validé avant d'être appliqué
- **`Board<State>`** : l'état du plateau encode les invariants (qui joue, droits de roque)
- **`Color`** : type-level distinction blanc/noir (pas un simple booléen)

### Valeur pour l'objectif du projet (stress des toolchains)

C'est **la feature la plus ciblée sur le stress du type-checker**. Chaque langage est poussé dans ses retranchements :

| Langage | Ce que ça stress | Technique spécifique |
|---|---|---|
| **Rust** | Compilateur (monomorphisation, trait bounds) | `PhantomData<State>`, `Board<WhiteToMove>` vs `Board<BlackToMove>`, `impl Board<WhiteToMove> { fn make_move(self) -> Board<BlackToMove> }` — le compilateur doit vérifier les transitions d'état à la compilation. Lifetime bounds sur les références au plateau |
| **TypeScript** | `tsc` (conditional types, template literals) | Branded types (`type Square = number & { __brand: 'Square' }`), conditional types (`type NextColor<C> = C extends White ? Black : White`), template literal types pour la notation algébrique (`type AlgebraicSquare = \`${'a'|'b'|...|'h'}${'1'|...|'8'}\``) — explose la complexité du type-checker |
| **Python** | `mypy` / `pyright` (NewType, Protocol, overload) | `NewType('Square', int)`, `@overload` pour les méthodes avec différents types de retour selon l'état, `Protocol[State]` pour les interfaces stateful, `TypeGuard` pour les validations |
| **PHP** | PHPStan (generics, assertions) | `@template TState of GameState`, `@param Board<WhiteToMove>`, `@return Board<BlackToMove>`, assertions PHPStan (`assert($move instanceof LegalMove)`) — PHPStan doit traquer les types génériques à travers les appels |
| **Dart** | `dart analyze` (generics, sealed) | `Board<S extends GameState>`, `sealed class GameState`, `extension type Square._(int value)` (Dart 3 extension types) — l'analyseur doit vérifier l'exhaustivité des patterns |
| **Ruby** | Steep (RBS generics) | `Board[WhiteToMove]` en RBS, vérification de types structurels, signatures de méthodes avec types dépendants |
| **Lua** | LuaLS annotations | `---@class Square`, `---@generic T : GameState`, `---@param board Board<T>` — annotations Lua Language Server |

**Point clé** : Cette feature ne change pas le comportement à l'exécution — elle ajoute uniquement des contraintes de types. C'est du code qui existe **exclusivement** pour le compilateur/type-checker, ce qui maximise le ratio "travail du type-checker / code exécuté".

## Description fonctionnelle

### 1. Type `Square` (case)

Un type opaque/branded garantissant une valeur entre 0 et 63 :

```
// Construction validée
Square.new(0)   → OK (a1)
Square.new(63)  → OK (h8)
Square.new(64)  → Erreur (compile-time ou runtime selon le langage)
Square.new(-1)  → Erreur

// Méthodes
square.rank() → Rank (0-7)
square.file() → File (0-7)
square.to_algebraic() → "e4"
Square.from_algebraic("e4") → Square(28)

// Opérations type-safe
square.offset(dx, dy) → Option<Square>  // Peut retourner None si hors plateau
square.distance(other) → u8
```

#### Par langage

| Langage | Implémentation |
|---|---|
| Rust | `#[derive(Copy, Clone)] struct Square(u8);` avec `impl TryFrom<u8>` |
| TypeScript | `type Square = number & { readonly __brand: unique symbol }` + factory function |
| Python | `NewType('Square', int)` + validation à la construction |
| PHP | `final class Square { private function __construct(private readonly int $value) {} }` |
| Dart | `extension type Square._(int value) { Square(int v) : assert(v >= 0 && v < 64), value = v; }` |
| Ruby | `Square = Data.define(:value) { def initialize(value:) = (raise unless (0..63).include?(value)) }` |
| Lua | Métatable avec `__newindex` bloqué |

### 2. Type `Move<Legal>` vs `Move<Unchecked>`

Deux "états" pour un coup : non validé (parsé depuis l'entrée utilisateur) et validé (confirmé légal) :

```
// Parsing → Move<Unchecked>
raw_move = Move.parse("e2e4")  // type: Move<Unchecked>

// Validation → Move<Legal>
legal_move = board.validate(raw_move)  // type: Option<Move<Legal>>

// Application — n'accepte QUE Move<Legal>
board.apply(legal_move)  // OK
board.apply(raw_move)    // ERREUR DE COMPILATION
```

### 3. Type `Board<State>` avec transitions

L'état du plateau encode qui doit jouer :

```
// Le type change après chaque coup
board: Board<WhiteToMove>
new_board = board.make_move(move)  // type: Board<BlackToMove>

// Impossible d'appeler make_move deux fois sans alternance
board.make_move(m1).make_move(m2)  // m1 est blanc, m2 est noir — vérifié par les types
```

### 4. Types `Color`, `Piece`, `Rank`, `File`

Types opaques pour toutes les primitives :

```
Color: White | Black (pas un booléen)
PieceType: King | Queen | Rook | Bishop | Knight | Pawn (pas un char)
Rank: R1 | R2 | ... | R8 (pas un int)
File: FA | FB | ... | FH (pas un int)
Piece: { color: Color, piece_type: PieceType }
```

### 5. Builder pattern type-safe pour les positions

```
// Construction de position avec vérification de types
Position.builder()
  .place(Square.E1, Piece.WHITE_KING)    // requis
  .place(Square.E8, Piece.BLACK_KING)    // requis
  .side_to_move(Color.WHITE)
  .castling_rights(CastlingRights.ALL)
  .build()                                // type: Board<WhiteToMove>
```

## Fichiers à créer par langage

```
<lang>/
├── src/
│   ├── types/
│   │   ├── mod.{ext}        -- Ré-exports
│   │   ├── square.{ext}     -- Type Square opaque
│   │   ├── piece.{ext}      -- Types Color, PieceType, Piece
│   │   ├── move.{ext}       -- Move<Legal> / Move<Unchecked>
│   │   ├── board_state.{ext} -- Board<State> transitions
│   │   ├── rank_file.{ext}  -- Types Rank et File
│   │   └── castling.{ext}   -- CastlingRights type-safe
```

## Contraintes de compatibilité

- Le comportement à l'exécution ne change **pas**
- Tous les tests existants doivent passer sans modification
- L'interface CLI reste identique
- Le refactoring peut être progressif (un type à la fois)

## Tests de validation

1. **Compilation** : le code doit compiler/type-check sans erreur avec les type-checkers stricts (`tsc --strict`, `mypy --strict`, `phpstan level 9`, `cargo clippy`)
2. **Erreurs attendues** : documenter les erreurs de compilation que le type system **devrait** attraper
3. **Régression** : tous les tests fonctionnels passent
4. **Performance** : mesurer l'impact sur le temps de type-checking (objectif : augmentation notable)

## Critères de succès

- [ ] `Square` type-safe dans les 7 langages
- [ ] Au moins `Move<Legal>` / `Move<Unchecked>` dans Rust, TypeScript, et Dart
- [ ] `Board<State>` avec transitions dans au moins 3 langages
- [ ] Temps de type-checking mesuré avant/après pour chaque langage
- [ ] Documentation des patterns type-safe par langage
- [ ] Aucune régression fonctionnelle
