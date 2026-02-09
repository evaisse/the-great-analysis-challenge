# PRD-03 : Table de transposition, Deepening itératif & Gestion du temps

## Résumé

Implémenter trois composantes interconnectées qui forment le cœur d'un moteur d'échecs moderne : une table de transposition (hash table pour mémoriser les positions déjà évaluées), un framework d'iterative deepening (recherche par approfondissement progressif), et un système de gestion du temps pour contrôler la durée de la recherche.

## Métriques cibles

| Indicateur | Valeur |
|---|---|
| LOC ajoutées par langage | +900 – 2 000 |
| LOC totales ajoutées (×7) | ~6 300 – 14 000 |
| Priorité | **P1 — Fort impact build/analyse** |

## Pertinence pour le projet

### Valeur fonctionnelle (moteur d'échecs)

Ces trois composantes sont **indissociables** dans un vrai moteur et transforment fondamentalement la recherche :

- **Table de transposition (TT)** : Dans un arbre de recherche d'échecs, la même position peut être atteinte par des ordres de coups différents (e.g., 1.e4 d5 2.d4 = 1.d4 d5 2.e4). Sans TT, on recalcule ces positions. Avec TT, on les reconnaît et on réutilise le résultat → réduction de 30-70% des nœuds explorés
- **Iterative deepening** : Au lieu de chercher directement à profondeur N, on cherche d'abord à profondeur 1, puis 2, puis 3... jusqu'à N. Ça semble gaspiller du travail, mais grâce à la TT et au meilleur tri des coups, c'est en réalité **plus rapide** que la recherche directe. En bonus, on a toujours un "meilleur coup provisoire" si le temps expire
- **Gestion du temps** : Avec l'iterative deepening, on peut interrompre la recherche à tout moment et renvoyer le meilleur coup trouvé jusqu'ici. Le time manager décide quand arrêter en fonction du temps restant, de la complexité de la position, et de la stabilité du meilleur coup

### Valeur pour l'objectif du projet (stress des toolchains)

C'est la feature qui produit le **graphe d'appels le plus complexe** et les **structures de données les plus sophistiquées** :

| Langage | Ce que ça stress | Détail |
|---|---|---|
| **Rust** | Borrow checker, lifetimes, unsafe | La TT est un `Vec<Entry>` partagé entre les itérations — lifetime management complexe. L'interruption de recherche nécessite un mécanisme de signaling (`AtomicBool` ou channel). Le borrow checker doit valider que la TT n'est pas mutée pendant la lecture |
| **TypeScript** | Type inference profonde, unions | `TTEntry` avec unions discriminées (`Exact | LowerBound | UpperBound`), generics pour la `HashMap<ZobristKey, TTEntry>`, types conditionnels pour les flags de bound |
| **Python** | `mypy` analyse de flux, Protocol | `Protocol` pour l'interface de recherche, `TypeGuard` pour les bound types, `dataclass` composites, `threading.Event` pour le time management — mypy doit analyser le flux entre threads |
| **PHP** | PHPStan complexité inter-classes | Classes `TranspositionTable`, `IterativeDeepener`, `TimeManager` avec injection de dépendances, generics `@template T of BoundType`, analyse de flux de données à travers les itérations |
| **Dart** | Analyse de flux, sealed classes | `sealed class BoundType { Exact, LowerBound, UpperBound }`, `Isolate` pour le time management, pattern matching exhaustif |
| **Ruby** | Complexité cyclomatique, Steep | La boucle d'iterative deepening avec gestion du temps crée une haute complexité cyclomatique. Steep doit vérifier les types des entrées TT via RBS |
| **Lua** | Métatables, portée, coroutines | Implémentation de la TT via métatables (weak references pour le GC), coroutines Lua pour l'iterative deepening interruptible |

**Point clé** : La combinaison TT + iterative deepening + time management crée un **graphe de dépendances cyclique** (le time manager dépend de l'iterative deepener qui dépend de la TT qui est modifiée par la recherche qui est contrôlée par le time manager) qui force les analyseurs statiques à gérer des flux de données complexes.

## Description fonctionnelle

### 1. Table de transposition

#### Structure d'une entrée TT

```
TTEntry {
  key: u64           // Clé de hachage Zobrist (ou partielle)
  depth: u8          // Profondeur de recherche restante
  score: i16         // Score évalué
  bound: BoundType   // EXACT | LOWER_BOUND | UPPER_BOUND
  best_move: Move    // Meilleur coup trouvé
  age: u8            // Génération (pour le remplacement)
}
```

#### Types de bornes (bound)

- **EXACT** : Le score est exact (pas de coupure alpha/beta)
- **LOWER_BOUND** (fail-high) : Le score réel est ≥ score stocké (coupure beta)
- **UPPER_BOUND** (fail-low) : Le score réel est ≤ score stocké (coupure alpha)

#### Politique de remplacement

```
should_replace(old_entry, new_entry):
  if new_entry.age != old_entry.age: return true    // Préférer l'entrée récente
  if new_entry.depth >= old_entry.depth: return true // Préférer la profondeur
  return false
```

#### Intégration dans minimax

```pseudocode
function minimax_with_tt(position, depth, alpha, beta, maximizing):
    tt_entry = tt.probe(position.hash)
    
    if tt_entry and tt_entry.depth >= depth:
        if tt_entry.bound == EXACT:
            return tt_entry.score
        if tt_entry.bound == LOWER_BOUND:
            alpha = max(alpha, tt_entry.score)
        if tt_entry.bound == UPPER_BOUND:
            beta = min(beta, tt_entry.score)
        if alpha >= beta:
            return tt_entry.score
    
    // ... recherche normale ...
    
    // Stocker le résultat
    bound = determine_bound(original_alpha, beta, best_score)
    tt.store(position.hash, depth, best_score, bound, best_move)
    
    return best_score
```

#### Taille de la TT

Par défaut : 16 MB → ~500K entrées (32 bytes/entrée). Configurable via option.

### 2. Iterative Deepening

```pseudocode
function iterative_deepening(position, max_depth, time_manager):
    best_move = null
    best_score = 0
    
    for depth in 1..max_depth:
        if time_manager.should_stop():
            break
        
        score, move = search_root(position, depth)
        
        if not time_manager.search_was_interrupted():
            best_move = move
            best_score = score
            
            print_info(depth, score, nodes, time, pv)
            
            // Early exit si mat trouvé
            if abs(score) >= MATE_SCORE - MAX_DEPTH:
                break
            
            // Informer le time manager de la stabilité
            time_manager.report_iteration(depth, score, move)
    
    return best_move, best_score
```

#### Principal Variation (PV)

Extraire la séquence de meilleurs coups (principal variation) depuis la TT :

```pseudocode
function extract_pv(position, depth):
    pv = []
    seen = set()
    
    while depth > 0 and position.hash not in seen:
        entry = tt.probe(position.hash)
        if entry is null or entry.best_move is null:
            break
        
        seen.add(position.hash)
        pv.append(entry.best_move)
        make_move(position, entry.best_move)
        depth -= 1
    
    // Undo all moves
    for move in reversed(pv):
        undo_move(position, move)
    
    return pv
```

### 3. Gestion du temps

#### Modes de temps

| Mode | Description | Paramètre |
|---|---|---|
| `depth` | Recherche à profondeur fixe | `ai 5` (existant) |
| `movetime` | Temps fixe par coup | `go movetime 5000` (5s) |
| `time+increment` | Contrôle de temps avec incrément | `go wtime 300000 btime 300000 winc 2000 binc 2000` |
| `infinite` | Pas de limite (arrêt manuel) | `go infinite` |

#### Algorithme d'allocation de temps

```pseudocode
function allocate_time(remaining_ms, increment_ms, moves_to_go):
    if moves_to_go > 0:
        base_time = remaining_ms / moves_to_go + increment_ms
    else:
        // Estimation : ~30 coups restants
        estimated_moves = max(20, 50 - move_number)
        base_time = remaining_ms / estimated_moves + increment_ms
    
    // Ne pas utiliser plus de 50% du temps restant
    max_time = remaining_ms * 0.5
    
    // Ajustements
    if score_is_unstable:
        base_time *= 1.5  // Plus de temps si le score fluctue
    if best_move_changed:
        base_time *= 1.3  // Plus de temps si le meilleur coup change
    
    return min(base_time, max_time)
```

## Fichiers à créer par langage

```
<lang>/
├── src/
│   ├── search/
│   │   ├── mod.{ext}                -- Module principal
│   │   ├── transposition_table.{ext} -- TT avec probe/store
│   │   ├── iterative_deepening.{ext} -- Boucle d'approfondissement
│   │   ├── time_manager.{ext}        -- Allocation et contrôle du temps
│   │   ├── search_info.{ext}         -- Structures d'info (PV, stats)
│   │   └── bounds.{ext}              -- Types de bornes (enum/union)
```

## Contraintes de compatibilité

- La commande `ai <depth>` existante doit continuer à fonctionner (recherche à profondeur fixe)
- Les nouvelles commandes (`go movetime`, `go wtime/btime`) sont additionnelles
- La TT est optionnelle : si désactivée, le comportement est identique à l'implémentation actuelle
- Les tests AI existants doivent passer avec ou sans TT

## Tests de validation

1. **TT probe/store** : stocker et retrouver une entrée
2. **Bound types** : vérifier que les bornes EXACT/LOWER/UPPER sont correctement appliquées
3. **Iterative deepening** : vérifier que le résultat à profondeur N est le même qu'une recherche directe à profondeur N
4. **Time management** : vérifier que la recherche s'arrête dans le temps alloué (±10%)
5. **PV extraction** : vérifier que la PV est une séquence de coups légaux
6. **Régression** : les tests AI existants passent toujours

## Critères de succès

- [ ] Table de transposition fonctionnelle avec probe/store
- [ ] Iterative deepening avec sortie progressive (depth, score, nodes, time, PV)
- [ ] Au moins 2 modes de temps (depth fixe + movetime)
- [ ] Les tests existants passent toujours
- [ ] Temps de build et d'analyse mesurés avant/après
- [ ] Le graphe de dépendances entre TT/ID/TM est documenté
