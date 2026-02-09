# PRDs — Complexification de la base de code

> **Objectif** : passer de ~9 500 LOC à ~30 000–55 000 LOC de code légitime pour stresser les compilateurs, type-checkers, linters et analyseurs statiques des 7 langages (Rust, TypeScript, Python, PHP, Dart, Ruby, Lua).

## Vue d'ensemble

| # | PRD | LOC/lang | LOC total (×7) | Stress principal |
|---|---|---|---|---|
| **P1 — Fort impact build** |
| 01 | [Tables d'attaque & codegen](./01-attack-tables-codegen.md) | +400–1 200 | ~2 800–8 400 | Compilation (const arrays, build.rs, codegen) |
| 02 | [Évaluation riche](./02-rich-evaluation.md) | +800–2 500 | ~5 600–17 500 | Analyseur statique (beaucoup de fichiers/modules) |
| 03 | [TT + Iterative Deepening + Time](./03-transposition-table-iterative-deepening.md) | +900–2 000 | ~6 300–14 000 | Graphe d'appels, structures complexes, récursion |
| **P2 — Stress typé (compile-time)** |
| 04 | [Modélisation type-safe](./04-type-safe-modeling.md) | +400–1 200 | ~2 800–8 400 | Type-checker (phantom types, branded types, generics) |
| 05 | [Parseur PGN & variantes](./05-pgn-parser-variant-tree.md) | +900–2 500 | ~6 300–17 500 | Unions discriminées, AST récursif, visitor pattern |
| 06 | [Protocole UCI](./06-uci-protocol.md) | +700–1 800 | ~4 900–12 600 | Machine à états, parsing, validation |
| **P3 — Bonus** |
| 07 | [Zobrist + répétition + 50 coups](./07-zobrist-hashing-repetition.md) | +500–1 200 | ~3 500–8 400 | Types numériques 64 bits, grandes tables const |
| 08 | [Chess960](./08-chess960.md) | +600–1 600 | ~4 200–11 200 | Refactoring profond, re-analyse de code existant |
| 09 | [Tracing structuré](./09-structured-tracing-diagnostics.md) | +500–1 500 | ~3 500–10 500 | Transversal (touche tous les fichiers), decorators/macros |

## Estimations cumulées

| Scénario | PRDs | LOC ajoutées | Total projet |
|---|---|---|---|
| P1 seule | 01 + 02 + 03 | ~14 700–39 900 | ~24 000–49 000 |
| P1 + P2 | 01–06 | ~28 700–68 400 | ~38 000–78 000 |
| Toutes | 01–09 | ~39 900–98 500 | ~49 000–108 000 |

## Ce qui stress quoi, par langage

| Langage | PRDs les plus impactants | Mécanismes stressés |
|---|---|---|
| **Rust** | 01, 02, 04 | `build.rs`, `const fn`, proc macros, monomorphisation, lifetimes, `PhantomData` |
| **TypeScript** | 01, 04, 05 | `as const` literals, conditional types, mapped types, branded types, unions |
| **Python** | 02, 04, 05 | `Protocol`, `TypeGuard`, `Literal`, `NewType`, `@overload`, `match` |
| **PHP** | 02, 03, 06 | PHPStan generics (`@template`), enums PHP 8.1, analyse inter-fichiers |
| **Dart** | 04, 05, 06 | `sealed class`, extension types (Dart 3), pattern matching exhaustif |
| **Ruby** | 02, 09, 08 | Complexité cyclomatique (Rubocop), RBS/Steep, `prepend` |
| **Lua** | 01, 03, 09 | Tables imbriquées, métatables, coroutines, `debug.sethook()` |

## Graphe de dépendances

```
07 (Zobrist) ──→ 03 (TT + ID) ──→ 06 (UCI, time management)
                      │
01 (Attack Tables) ───┤
                      │
02 (Rich Eval) ───────┘

04 (Type-safe) : indépendant (refactoring)
05 (PGN) : indépendant (feature additive)
08 (Chess960) : indépendant (modifie le roque)
09 (Tracing) : indépendant (transversal)
```

## Ordre d'implémentation recommandé

1. **07** (Zobrist) — prérequis de 03
2. **01** (Attack Tables) — améliore les perfs de 02 et 03
3. **04** (Type-safe) — refactoring à faire tôt pour bénéficier les PRDs suivants
4. **02** (Rich Eval) — utilise 01
5. **03** (TT + ID) — utilise 07, bénéficie de 01
6. **05** (PGN) — indépendant, peut être parallélisé
7. **06** (UCI) — utilise 03 pour le time management
8. **08** (Chess960) — refactoring du roque, à faire quand la base est stable
9. **09** (Tracing) — en dernier car transversal (touche tous les fichiers)
