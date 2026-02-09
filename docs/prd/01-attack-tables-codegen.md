# PRD-01 : Tables d'attaque pré-calculées & génération de code

## Résumé

Ajouter un système de tables d'attaque pré-calculées à la compilation (ou au démarrage) pour chaque pièce, remplaçant le calcul dynamique actuel des cases attaquées. Ce système inclut des tables de lookup pour cavaliers, rois, rayons de fous/tours/dames, et des tables de distance entre cases.

## Métriques cibles

| Indicateur | Valeur |
|---|---|
| LOC ajoutées par langage | +400 – 1 200 |
| LOC totales ajoutées (×7) | ~2 800 – 8 400 |
| Priorité | **P1 — Fort impact build/analyse** |

## Pertinence pour le projet

### Valeur fonctionnelle (moteur d'échecs)

Les tables d'attaque pré-calculées sont une optimisation **fondamentale** de tout moteur d'échecs sérieux. Actuellement, chaque appel à la génération de coups recalcule dynamiquement les cases attaquées par chaque pièce. Avec des lookup tables :

- La génération de coups pour cavaliers et rois devient un simple accès mémoire O(1) au lieu d'une boucle sur les offsets
- Les tables de rayons accélèrent considérablement la détection de clouages (pins) et de rayons-X
- Les tables de distance permettent d'évaluer rapidement la proximité roi-pièces (utile pour la sécurité du roi)
- Le perft(4) et la recherche AI bénéficient directement de cette accélération

### Valeur pour l'objectif du projet (stress des toolchains)

C'est l'une des features les plus impactantes sur les temps de build car elle produit de **gros blocs de données constantes** que chaque compilateur/analyseur doit traiter différemment :

| Langage | Ce que ça stress | Mécanisme |
|---|---|---|
| **Rust** | Compilation, monomorphisation | `build.rs` qui génère du code, `const fn`, proc macros, gros tableaux `[u64; 64]` statiques — le compilateur doit évaluer les `const fn` à la compilation |
| **TypeScript** | Type-checker `tsc` | Gros fichiers `.ts` de tableaux `as const` (literal types), le type-checker infer les types littéraux de chaque valeur — explose la mémoire de `tsc` |
| **Python** | `mypy` / `pyright` | `Final[tuple[int, ...]]`, `Literal` types sur des constantes, `frozenset` — l'analyseur statique doit vérifier l'immutabilité de centaines de valeurs |
| **PHP** | PHPStan | Gros `const array` avec `@var array<int, array<int, int>>` — PHPStan doit inférer les types de chaque élément du tableau |
| **Dart** | Analyseur `dart analyze` | `const List<List<int>>` imbriquées, le compilateur doit vérifier la constance à la compilation |
| **Ruby** | Rubocop, Steep | `.freeze` sur de gros tableaux, vérification de complexité cyclomatique sur les modules de constantes |
| **Lua** | LuaCheck | Grandes tables Lua imbriquées, vérification des accès globaux vs locaux |

## Description fonctionnelle

### 1. Tables d'attaque cavalier (Knight Attack Tables)

Pour chaque case (0–63), pré-calculer le masque binaire (bitboard ou liste) de toutes les cases attaquées par un cavalier posé sur cette case.

```
KNIGHT_ATTACKS[64] = {
  [0] = {b3, c2},          -- a1
  [1] = {a3, c3, d2},      -- b1
  ...
  [63] = {f7, g6},          -- h8
}
```

**Volume** : 64 entrées × ~2-8 cases cibles = ~200-500 LOC selon la représentation.

### 2. Tables d'attaque roi (King Attack Tables)

Même principe pour le roi : pour chaque case, les 3-8 cases adjacentes.

```
KING_ATTACKS[64] = {
  [0] = {a2, b1, b2},      -- a1
  ...
}
```

**Volume** : 64 entrées, ~150-300 LOC.

### 3. Tables de rayons (Ray Tables)

Pour les pièces glissantes (fou, tour, dame), pré-calculer les rayons dans chaque direction depuis chaque case :

```
RAY_NORTH[64]      -- cases au nord de chaque case
RAY_SOUTH[64]      -- cases au sud
RAY_EAST[64]       -- cases à l'est
RAY_WEST[64]       -- cases à l'ouest
RAY_NORTHEAST[64]  -- diagonale nord-est
RAY_NORTHWEST[64]  -- diagonale nord-ouest
RAY_SOUTHEAST[64]  -- diagonale sud-est
RAY_SOUTHWEST[64]  -- diagonale sud-ouest
```

**Volume** : 8 directions × 64 cases = 512 entrées. C'est le bloc le plus volumineux (~400-800 LOC).

### 4. Tables de distance

Distance de Chebyshev (distance roi) et distance de Manhattan entre toutes les paires de cases :

```
CHEBYSHEV_DISTANCE[64][64]  -- 4096 valeurs
MANHATTAN_DISTANCE[64][64]  -- 4096 valeurs
```

**Volume** : 2 × 4096 = 8192 valeurs, ~200-400 LOC (compact) ou ~500+ LOC (lisible).

### 5. Génération de code (codegen)

Pour maximiser le stress sur les builds, les tables doivent être générées à la **compilation** quand le langage le permet :

| Langage | Stratégie de codegen |
|---|---|
| Rust | `build.rs` qui génère un fichier `attack_tables.rs` inclus via `include!()`, ou `const fn` qui calcule les tables |
| TypeScript | Script de génération qui produit un `.ts` avec `as const`, ou calcul dans un fichier séparé |
| Python | Script de génération ou `__init_subclass__` + `Final` annotations |
| PHP | Script de génération ou gros fichier de constantes de classe |
| Dart | `const` constructors et listes constantes |
| Ruby | Script de génération ou module `freeze`d |
| Lua | Table Lua générée par script ou définie inline |

## Fichiers à créer par langage

```
<lang>/
├── src/
│   ├── attack_tables.{ext}       -- Tables pré-calculées (le gros du volume)
│   ├── attack_tables_gen.{ext}   -- Script de génération (si codegen)
│   ├── ray_tables.{ext}          -- Tables de rayons (peut être fusionné)
│   └── distance_tables.{ext}     -- Tables de distance
```

## Tests de validation

1. **Cohérence** : Pour chaque case, vérifier que `KNIGHT_ATTACKS[sq]` correspond aux coups légaux d'un cavalier seul sur un échiquier vide
2. **Exhaustivité** : 64 entrées dans chaque table
3. **Performance** : La génération de coups utilisant les tables doit être ≥2× plus rapide que le calcul dynamique
4. **Perft** : Les résultats perft doivent rester identiques (perft(4) = 197281)

## Critères de succès

- [ ] Tables générées ou définies pour les 7 langages
- [ ] Le générateur de coups utilise les tables au lieu du calcul dynamique
- [ ] Perft(4) = 197281 (aucune régression)
- [ ] Temps de build mesurés avant/après pour chaque langage
- [ ] Impact documenté sur `tsc`, `rustc`, `mypy`, `phpstan`, `dart analyze`
