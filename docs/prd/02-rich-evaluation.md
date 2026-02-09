# PRD-02 : Évaluation riche (Tapered Eval, Mobilité, Structure de pions, Sécurité du roi)

## Résumé

Remplacer la fonction d'évaluation simple (matériel + piece-square tables) par une évaluation multi-critères riche incluant : tapered evaluation (interpolation opening/endgame), mobilité des pièces, analyse de la structure de pions, sécurité du roi, et bonus positionnel avancé.

## Métriques cibles

| Indicateur | Valeur |
|---|---|
| LOC ajoutées par langage | +800 – 2 500 |
| LOC totales ajoutées (×7) | ~5 600 – 17 500 |
| Priorité | **P1 — Fort impact build/analyse** |

## Pertinence pour le projet

### Valeur fonctionnelle (moteur d'échecs)

L'évaluation actuelle est rudimentaire : matériel + piece-square tables statiques. C'est suffisant pour des coups basiques, mais le moteur manque de compréhension positionnelle. Une évaluation riche produit un jeu qualitativement meilleur :

- **Tapered eval** : les piece-square tables actuelles sont optimales pour le milieu de partie, mais mauvaises en finale (le roi doit être centralisé en finale, pas caché dans un coin). Le tapered eval interpole entre deux jeux de tables (middlegame/endgame) selon la quantité de matériel restant
- **Mobilité** : un fou avec 11 cases disponibles vaut plus qu'un fou coincé derrière ses propres pions — le moteur actuel ne le sait pas
- **Structure de pions** : pions doublés, isolés, passés, chaînes — c'est le fondement de la stratégie aux échecs
- **Sécurité du roi** : évaluer le danger autour du roi (colonnes ouvertes, pions-bouclier manquants)

### Valeur pour l'objectif du projet (stress des toolchains)

C'est la feature qui ajoute le **plus de volume de code** et le plus de **diversité structurelle** :

| Langage | Ce que ça stress | Détail |
|---|---|---|
| **Rust** | Monomorphisation, analyseur de lifetimes | Beaucoup de petites `fn` pures avec des `&Board` en paramètre, generics pour `Phase<Middlegame>` / `Phase<Endgame>`, le compilateur doit monomorphiser chaque combinaison |
| **TypeScript** | `tsc` type-checking, mémoire | Unions discriminées pour les termes d'évaluation, mapped types pour les tables middlegame/endgame, conditional types pour sélectionner le bon jeu de tables |
| **Python** | `mypy` / `pyright` profondeur d'analyse | `Protocol` classes pour chaque terme d'évaluation, `TypedDict` pour les scores composites, `@overload` decorators, `Literal` unions pour les phases |
| **PHP** | PHPStan analyse inter-fichiers | Interfaces multiples (`MobilityEvaluator`, `PawnStructureEvaluator`...), generics via `@template`, analyse de flux de données complexe |
| **Dart** | `dart analyze` pattern matching | `sealed class EvalTerm`, `switch` expressions exhaustifs sur les variantes, extensions typées |
| **Ruby** | Rubocop complexité, Steep | Beaucoup de petites méthodes (ABC complexity), modules mixins, RBS type signatures |
| **Lua** | LuaCheck portée des variables | Beaucoup de fonctions locales, tables imbriquées, metatables pour l'héritage |

**Point clé** : Cette feature produit naturellement 6-10 nouveaux fichiers/modules par langage, ce qui multiplie le nombre d'unités de compilation et force l'analyseur à résoudre des dépendances inter-fichiers.

## Description fonctionnelle

### 1. Tapered Evaluation

Interpolation linéaire entre une évaluation middlegame (mg) et une évaluation endgame (eg) basée sur la phase de jeu :

```
phase = compute_phase(position)  // 0 = endgame pur, 256 = opening pur

mg_score = evaluate_middlegame(position)
eg_score = evaluate_endgame(position)

score = (mg_score * phase + eg_score * (256 - phase)) / 256
```

**Phase** calculée à partir du matériel restant :
```
phase_value = {
  PAWN: 0, KNIGHT: 1, BISHOP: 1, ROOK: 2, QUEEN: 4
}
total_phase = 24  // 4×1 + 4×1 + 4×2 + 2×4
phase = min(total_phase, sum(phase_value[piece] for piece on board))
```

**Nouveau jeu de tables** : Piece-square tables endgame (roi centralisé, pions passés valorisés).

**Volume** : ~200-600 LOC (tables endgame + logique d'interpolation).

### 2. Mobilité

Compter le nombre de cases légales accessibles pour chaque pièce et appliquer un bonus/malus :

```
mobility_bonus[KNIGHT] = [-15, -5, 0, 5, 10, 15, 20, 22, 24]  // 0-8 cases
mobility_bonus[BISHOP] = [-20, -10, 0, 5, 10, 15, 18, 21, 24, 26, 28, 30, 32, 34]  // 0-13
mobility_bonus[ROOK]   = [-15, -8, 0, 3, 6, 9, 12, 14, 16, 18, 20, 22, 24, 26, 28]  // 0-14
mobility_bonus[QUEEN]  = [-10, -5, 0, 2, 4, 6, 8, 10, 12, 13, 14, 15, 16, ...] // 0-27
```

**Volume** : ~200-400 LOC (calcul de mobilité + tables de bonus).

### 3. Structure de pions

Analyser la configuration des pions et appliquer des bonus/malus :

| Terme | Description | Bonus/Malus |
|---|---|---|
| Pions doublés | Deux pions de même couleur sur même colonne | -20 cp |
| Pions isolés | Aucun pion ami sur les colonnes adjacentes | -15 cp |
| Pions passés | Aucun pion adverse pouvant bloquer/capturer | +20 à +120 cp (selon le rang) |
| Chaînes de pions | Pions se protégeant mutuellement | +5 à +15 cp |
| Pions arriérés | Pion ne pouvant avancer car la case est contrôlée | -10 cp |
| Pions connectés | Pions adjacents sur le même rang | +5 cp |

```
passed_pawn_bonus_by_rank = [0, 10, 20, 40, 60, 90, 120, 0]  // rang 1-8
```

**Volume** : ~300-800 LOC (détection de chaque pattern + tables).

### 4. Sécurité du roi

Évaluer le danger autour de chaque roi :

- **Pions-bouclier** : bonus pour les pions devant le roi (+10 à +30 cp par pion)
- **Colonnes ouvertes** : malus si une colonne ouverte/semi-ouverte pointe vers le roi (-30 cp)
- **Attaquants** : nombre de pièces adverses attaquant la zone du roi (8 cases autour)
- **Tropisme** : bonus pour les pièces proches du roi adverse (utilise les distance tables du PRD-01)

```
king_safety_score = shield_bonus - open_file_penalty - attacker_weight * attacker_count
```

**Volume** : ~200-500 LOC.

### 5. Bonus positionnels avancés

- **Paire de fous** : +30 cp si un camp a ses deux fous
- **Tour sur colonne ouverte** : +25 cp
- **Tour sur colonne semi-ouverte** : +15 cp
- **Tour sur la 7ème rangée** : +20 cp
- **Cavalier avant-poste** : +20 cp si protégé par un pion et ne pouvant être chassé

**Volume** : ~100-300 LOC.

## Fichiers à créer par langage

```
<lang>/
├── src/
│   ├── eval/
│   │   ├── mod.{ext}              -- Module principal d'évaluation
│   │   ├── tapered.{ext}          -- Tapered eval + tables endgame
│   │   ├── mobility.{ext}         -- Calcul de mobilité
│   │   ├── pawn_structure.{ext}   -- Analyse de structure de pions
│   │   ├── king_safety.{ext}      -- Sécurité du roi
│   │   ├── positional.{ext}       -- Bonus positionnels divers
│   │   └── tables.{ext}           -- Tables de constantes (PST endgame, bonus)
```

## Contraintes de compatibilité

- La nouvelle évaluation doit être **activable/désactivable** (flag `--rich-eval` ou similaire) pour maintenir la compatibilité avec les tests existants qui attendent l'évaluation simple de `AI_ALGORITHM_SPEC.md`
- Les tests perft ne sont pas affectés (ils ne dépendent pas de l'évaluation)
- Les tests AI existants doivent toujours passer avec l'évaluation simple

## Tests de validation

1. **Tapered eval** : vérifier que l'évaluation d'ouverture ≠ évaluation de finale pour les mêmes pièces
2. **Mobilité** : un fou bloqué doit avoir un score de mobilité < un fou libre
3. **Pions passés** : un pion passé en 6ème rangée doit augmenter le score significativement
4. **Sécurité roi** : un roi exposé (pas de pions-bouclier) doit avoir un malus
5. **Régression** : perft(4) = 197281 (inchangé)

## Critères de succès

- [ ] 6-10 nouveaux fichiers/modules par langage
- [ ] Tapered eval avec deux jeux de piece-square tables
- [ ] Mobilité calculée pour cavaliers, fous, tours, dames
- [ ] Au moins 4 termes de structure de pions (doublés, isolés, passés, chaînes)
- [ ] Score de sécurité du roi fonctionnel
- [ ] Flag pour basculer entre évaluation simple et riche
- [ ] Temps de build et d'analyse mesurés avant/après
