# PRD-07 : Zobrist Hashing, Détection de répétition & Règle des 50 coups

## Résumé

Implémenter le hashing Zobrist pour identifier efficacement les positions, la détection de triple répétition (nulle par répétition), et la règle des 50 coups (nulle si 50 coups consécutifs sans capture ni mouvement de pion). Ces mécanismes sont les prérequis de la table de transposition (PRD-03) et du support complet des règles FIDE.

## Métriques cibles

| Indicateur | Valeur |
|---|---|
| LOC ajoutées par langage | +500 – 1 200 |
| LOC totales ajoutées (×7) | ~3 500 – 8 400 |
| Priorité | **P3 — Bonus** |

## Pertinence pour le projet

### Valeur fonctionnelle (moteur d'échecs)

#### Zobrist Hashing

Le hashing Zobrist est la méthode standard pour identifier les positions d'échecs. Le principe : chaque combinaison (pièce × case × couleur) a une clé aléatoire 64 bits pré-générée. Le hash d'une position est le XOR de toutes les clés des pièces présentes.

L'avantage fondamental : le hash est **incrémental**. Quand on déplace une pièce, on n'a pas besoin de recalculer depuis zéro — on XOR l'ancienne position et la nouvelle :

```
hash ^= zobrist_key[piece][from_square]  // Retirer la pièce de from
hash ^= zobrist_key[piece][to_square]    // Placer la pièce sur to
```

C'est O(1) au lieu de O(64) pour un recalcul complet. Essentiel pour la table de transposition (PRD-03).

#### Détection de répétition

Les règles FIDE stipulent qu'une partie est nulle si la même position se répète 3 fois (même pièces, même tour, mêmes droits de roque, même case en passant). Sans Zobrist, détecter cela nécessite de comparer l'état complet du plateau — avec Zobrist, c'est une simple comparaison d'entiers 64 bits.

#### Règle des 50 coups

Nulle si 50 coups consécutifs (100 demi-coups) sans capture ni mouvement de pion. Le compteur `halfmove_clock` existe déjà dans le FEN mais n'est pas utilisé pour déclarer la nulle automatiquement.

### Valeur pour l'objectif du projet (stress des toolchains)

| Langage | Ce que ça stress | Détail |
|---|---|---|
| **Rust** | `const fn`, `build.rs`, grands tableaux statiques | 781 clés Zobrist 64 bits en `const` (12 pièces × 64 cases + 1 side + 4 castling + 8 en passant). `const fn` pour la génération PRNG à la compilation. Le compilateur doit évaluer le PRNG sur ~800 itérations |
| **TypeScript** | BigInt, `as const` literals, mémoire tsc | `BigInt` n'est pas `number` — le type-checker doit gérer les deux. 781 `BigInt` literals en `as const` → ~4000 caractères de types littéraux. XOR sur BigInt vs number |
| **Python** | `Final`, `frozenset`, grands tuples typés | `Final[tuple[int, ...]]` pour les 781 clés, `mypy` doit vérifier l'immutabilité. Détection de répétition avec `dict[int, int]` typé |
| **PHP** | PHPStan tableaux constants, GMP | PHP n'a pas de type natif 64 bits unsigned → utilisation de `GMP` ou `bcmath`. PHPStan doit analyser les opérations GMP à travers les appels |
| **Dart** | `const` évaluation, Int64 | `const` tables d'entiers, mais Dart web n'a pas de vrai 64 bits → `Int64` du package `fixnum` ou `BigInt`. L'analyseur doit gérer les deux cas (VM vs Web) |
| **Ruby** | Bignum, `freeze`, Steep | Ruby gère nativement les gros entiers (Bignum) mais les opérations XOR sont lentes. `.freeze` sur 781 constantes. Steep doit typer les `Integer` |
| **Lua** | Bit operations, LuaJIT vs PUC | Lua 5.3+ a des opérations binaires natives, LuaJIT utilise `bit` library. LuaCheck doit gérer les deux API. Tables de 781 entrées |

**Point clé** : Les 781 clés Zobrist sont un gros bloc de **constantes numériques 64 bits** que chaque langage gère différemment (natif, BigInt, GMP...). C'est un excellent test de gestion des types numériques larges.

## Description fonctionnelle

### 1. Clés Zobrist

#### Structure

```
zobrist_keys = {
  pieces: [12][64]u64,    // 12 types de pièces × 64 cases = 768 clés
  side_to_move: u64,       // 1 clé pour le trait
  castling: [4]u64,        // 4 clés (K, Q, k, q)
  en_passant: [8]u64,      // 8 clés (colonnes a-h)
}
// Total : 768 + 1 + 4 + 8 = 781 clés
```

#### Génération

Les clés doivent être générées par un PRNG déterministe (même graines → mêmes clés dans tous les langages) :

```
// PRNG : XorShift64
seed = 0x123456789ABCDEF0  // Graine fixe, identique pour tous les langages

function xorshift64(state):
    state ^= state << 13
    state ^= state >> 7
    state ^= state << 17
    return state
```

### 2. Calcul du hash

#### Hash initial (depuis FEN)

```pseudocode
function compute_hash(position):
    hash = 0
    for each (piece, square) on board:
        hash ^= zobrist.pieces[piece_index(piece)][square]
    if position.side_to_move == BLACK:
        hash ^= zobrist.side_to_move
    for each castling_right in position.castling_rights:
        hash ^= zobrist.castling[right_index]
    if position.en_passant_file is not NONE:
        hash ^= zobrist.en_passant[file]
    return hash
```

#### Hash incrémental (après un coup)

```pseudocode
function update_hash(hash, move, position):
    // Retirer la pièce de la case source
    hash ^= zobrist.pieces[moving_piece][from]
    // Placer la pièce sur la case cible
    hash ^= zobrist.pieces[moving_piece][to]
    
    // Capture
    if move.captured_piece:
        hash ^= zobrist.pieces[captured_piece][to]
    
    // Roque
    if move.is_castling:
        hash ^= zobrist.pieces[rook][rook_from]
        hash ^= zobrist.pieces[rook][rook_to]
    
    // En passant
    if old_en_passant_file != NONE:
        hash ^= zobrist.en_passant[old_file]
    if new_en_passant_file != NONE:
        hash ^= zobrist.en_passant[new_file]
    
    // Droits de roque modifiés
    hash ^= zobrist.castling[old_rights]
    hash ^= zobrist.castling[new_rights]
    
    // Changement de camp
    hash ^= zobrist.side_to_move
    
    return hash
```

### 3. Détection de répétition

```pseudocode
class PositionHistory:
    history: list of (hash, halfmove_clock)
    
    function push(hash, halfmove_clock):
        history.append((hash, halfmove_clock))
    
    function pop():
        history.pop()
    
    function is_draw_by_repetition():
        if history.length < 8:  // Minimum 4 demi-coups pour une répétition
            return false
        
        current_hash = history.last().hash
        count = 0
        
        // Remonter dans l'historique
        for i in (history.length - 4) downto 0 step 2:
            if history[i].hash == current_hash:
                count += 1
                if count >= 2:  // 3ème occurrence (courante + 2 précédentes)
                    return true
            // Arrêter si un coup irréversible a été joué
            if history[i].halfmove_clock == 0:
                break
        
        return false
```

### 4. Règle des 50 coups

```pseudocode
function is_draw_by_fifty_moves(position):
    return position.halfmove_clock >= 100  // 100 demi-coups = 50 coups
```

### 5. Intégration dans la recherche

```pseudocode
function minimax_with_draws(position, depth, alpha, beta, maximizing):
    // Vérifier les nulles AVANT la recherche
    if position_history.is_draw_by_repetition():
        return 0  // Score de nulle
    if is_draw_by_fifty_moves(position):
        return 0
    
    // ... recherche normale ...
```

### 6. Commandes CLI

```
hash          -- Afficher le hash Zobrist de la position courante
draws         -- Afficher les compteurs (répétitions, 50 coups)
history       -- Afficher l'historique des positions (avec hashes)
```

## Fichiers à créer par langage

```
<lang>/
├── src/
│   ├── zobrist/
│   │   ├── mod.{ext}          -- Module principal
│   │   ├── keys.{ext}         -- 781 clés Zobrist pré-calculées
│   │   ├── hasher.{ext}       -- Calcul de hash (initial + incrémental)
│   │   └── prng.{ext}         -- XorShift64 déterministe
│   ├── draw_detection.{ext}   -- Répétition + 50 coups
│   └── position_history.{ext} -- Historique des positions
```

## Dépendances

- **Prérequis pour** : PRD-03 (Table de transposition) — la TT utilise le hash Zobrist comme clé
- **Indépendant de** : tous les autres PRDs

## Tests de validation

1. **Hash déterministe** : même position → même hash dans les 7 langages
2. **Hash incrémental** : hash après `make_move` + `undo_move` = hash original
3. **Répétition** : 1.Nf3 Nf6 2.Ng1 Ng8 3.Nf3 Nf6 4.Ng1 Ng8 → nulle par répétition
4. **50 coups** : position avec 100 demi-coups sans capture/pion → nulle
5. **Collision** : vérifier l'absence de collisions sur 10000+ positions
6. **Régression** : perft(4) = 197281

## Critères de succès

- [ ] 781 clés Zobrist identiques dans les 7 langages (même PRNG, même graine)
- [ ] Hash incrémental fonctionnel
- [ ] Détection de triple répétition
- [ ] Règle des 50 coups
- [ ] Tests de régression passants
- [ ] Temps de build mesurés avant/après (impact des grandes tables de constantes)
