# PRD-09 : Système de tracing/diagnostics structurés

## Résumé

Implémenter un système de tracing structuré et de diagnostics pour instrumenter le moteur : logging hiérarchique avec spans, métriques de performance, profiling de la recherche, et export dans des formats standard (JSON, Chrome Tracing). Cela permet d'analyser en détail le comportement du moteur et de comparer les performances entre langages.

## Métriques cibles

| Indicateur | Valeur |
|---|---|
| LOC ajoutées par langage | +500 – 1 500 |
| LOC totales ajoutées (×7) | ~3 500 – 10 500 |
| Priorité | **P3 — Bonus** |

## Pertinence pour le projet

### Valeur fonctionnelle (moteur d'échecs)

Actuellement, le moteur est une boîte noire : on donne une position, on reçoit un coup, sans visibilité sur le processus interne. Un système de tracing structuré permet de :

- **Profiler la recherche** : combien de nœuds par seconde ? quel pourcentage de coupures alpha-beta ? quelle proportion de temps dans l'évaluation vs la génération de coups ?
- **Debugger l'AI** : pourquoi le moteur choisit tel coup ? quels coups ont été considérés ? quelle est la PV (Principal Variation) à chaque profondeur ?
- **Comparer les langages** : au-delà du temps total, comparer la distribution du temps entre les phases (génération, évaluation, tri des coups)
- **Détecter les régressions** : si une modification ralentit une phase spécifique, le tracing le révèle immédiatement

### Valeur pour l'objectif du projet (stress des toolchains)

Le tracing structuré touche **tous les fichiers** du moteur (chaque fonction instrumentée) et utilise des patterns avancés de chaque langage :

| Langage | Ce que ça stress | Détail |
|---|---|---|
| **Rust** | Macros, traits, generics, `tracing` crate patterns | `#[instrument]` proc macro sur chaque fonction, `span!()` macros déclaratives, traits `Subscriber + Layer` avec generics. Le compilateur doit expander les macros et monomorphiser les implémentations de `Layer` |
| **TypeScript** | Decorators (stage 3), Proxy, mapped types | `@Trace()` decorators sur les méthodes, `Proxy` pour l'instrumentation automatique, mapped types pour typer les métriques (`type Metrics<T> = { [K in keyof T]: Timer }`) |
| **Python** | Decorators, `contextmanager`, `Protocol` | `@trace` decorators, `with span("search"):` context managers, `Protocol[SpanProcessor]` pour les exporteurs, `__init_subclass__` pour l'auto-registration |
| **PHP** | Attributes (PHP 8), interfaces, analyseur statique | `#[Trace]` attributes PHP 8, interfaces `SpanExporter`, `SpanProcessor`, PHPStan doit analyser les types à travers les decorators/attributes |
| **Dart** | Zones, extensions, annotations | `Zone.fork()` pour le contexte, `extension` methods pour ajouter le tracing de manière non-intrusive, `@pragma('vm:prefer-inline')` pour le zero-cost |
| **Ruby** | `TracePoint`, modules, `prepend` | `Module#prepend` pour le monkey-patching propre, `TracePoint` API pour l'instrumentation automatique, blocs `do...end` pour les spans |
| **Lua** | Debug hooks, métatables, coroutines | `debug.sethook()` pour l'instrumentation, métatables pour les proxies, coroutines pour le contexte de span |

**Point clé** : Le tracing est **transversal** — il touche tous les modules. Contrairement aux autres PRDs qui ajoutent du code localisé, celui-ci ajoute des imports et des appels de tracing dans **chaque fichier existant**, ce qui force l'analyseur à re-analyser l'ensemble du projet.

## Description fonctionnelle

### 1. Concepts de base

#### Span (portée)

Un span représente une unité de travail avec un début et une fin :

```
Span {
  name: String           // "minimax", "generate_moves", "evaluate"
  parent: Option<SpanId> // Span parent (hiérarchie)
  start_time: u64        // Timestamp en nanosecondes
  end_time: u64          // Timestamp à la fin
  attributes: Map        // Métadonnées arbitraires
  events: Vec<Event>     // Événements ponctuels dans le span
}
```

#### Event (événement)

Un événement ponctuel dans un span :

```
Event {
  name: String           // "beta_cutoff", "tt_hit", "new_best_move"
  timestamp: u64
  attributes: Map        // { "move": "e2e4", "score": 35 }
}
```

#### Métriques

Compteurs et histogrammes agrégés :

```
Counter {
  name: String           // "nodes_searched", "tt_hits", "beta_cutoffs"
  value: u64
}

Histogram {
  name: String           // "eval_time_ns", "move_gen_time_ns"
  buckets: [u64]
  sum: u64
  count: u64
}
```

### 2. Instrumentation du moteur

#### Spans hiérarchiques

```
search (depth=5)
├── iterative_deepening
│   ├── search_depth_1
│   │   ├── generate_moves
│   │   ├── order_moves
│   │   ├── minimax
│   │   │   ├── evaluate
│   │   │   ├── generate_moves
│   │   │   └── minimax (récursif)
│   │   └── tt_store
│   ├── search_depth_2
│   │   └── ...
│   └── search_depth_5
│       └── ...
└── time_management
```

#### Métriques de recherche

| Métrique | Type | Description |
|---|---|---|
| `nodes_searched` | Counter | Nombre total de nœuds explorés |
| `nodes_per_second` | Gauge | Vitesse de recherche |
| `tt_hits` | Counter | Nombre de hits dans la TT |
| `tt_misses` | Counter | Nombre de misses |
| `tt_hit_rate` | Gauge | Ratio hits/(hits+misses) |
| `beta_cutoffs` | Counter | Nombre de coupures beta |
| `alpha_cutoffs` | Counter | Nombre de coupures alpha |
| `cutoff_rate` | Gauge | Efficacité du pruning |
| `eval_calls` | Counter | Nombre d'appels à evaluate() |
| `move_gen_time_ns` | Histogram | Distribution du temps de génération de coups |
| `eval_time_ns` | Histogram | Distribution du temps d'évaluation |
| `search_time_ms` | Histogram | Temps par profondeur |
| `branching_factor` | Gauge | Facteur de branchement effectif |
| `pv_length` | Gauge | Longueur de la PV |

### 3. API de tracing

#### Pattern de base

```pseudocode
// Décoration de fonction
@trace
function minimax(position, depth, alpha, beta, maximizing):
    span.set_attribute("depth", depth)
    span.set_attribute("alpha", alpha)
    span.set_attribute("beta", beta)
    
    // ... logique ...
    
    if beta <= alpha:
        span.add_event("beta_cutoff", {"move": move, "score": score})
        metrics.increment("beta_cutoffs")
    
    return score

// Context manager / RAII
function search(position, depth):
    with span("search", depth=depth):
        for d in 1..depth:
            with span("search_depth", d=d):
                score = minimax(...)
                metrics.record("search_time_ms", elapsed_ms)
```

#### Configuration

```
TraceConfig {
  enabled: bool           // Activer/désactiver globalement
  level: TraceLevel       // OFF, ERROR, WARN, INFO, DEBUG, TRACE
  exporters: [Exporter]   // Liste des exporteurs
  sampling_rate: f64      // 0.0 à 1.0 (pour les positions haut-débit)
}
```

### 4. Exporteurs

#### JSON Lines (par défaut)

```json
{"type":"span","name":"minimax","depth":3,"start_ns":1234567890,"end_ns":1234568000,"attributes":{"chess_depth":3}}
{"type":"event","name":"beta_cutoff","span":"minimax","timestamp_ns":1234567950,"attributes":{"move":"e2e4","score":35}}
{"type":"metric","name":"nodes_searched","value":45678}
```

#### Chrome Tracing Format

Compatible avec `chrome://tracing` et Perfetto :

```json
[
  {"name":"minimax","cat":"search","ph":"B","pid":1,"tid":1,"ts":1234567},
  {"name":"minimax","cat":"search","ph":"E","pid":1,"tid":1,"ts":1234568},
  {"name":"evaluate","cat":"eval","ph":"X","pid":1,"tid":1,"ts":1234568,"dur":50}
]
```

#### Rapport texte (human-readable)

```
=== Search Report ===
Position: rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
Depth: 5
Best Move: e2e4 (eval=+35)
Time: 2.3s

Nodes: 1,234,567 (536,768 nps)
TT Hits: 45,678 (12.3%)
Beta Cutoffs: 89,012 (67.8% of interior nodes)
Branching Factor: 4.2

Time Distribution:
  Move Generation: 23.4%
  Evaluation:      45.2%
  Move Ordering:    8.1%
  TT Probe/Store:   5.3%
  Other:           18.0%

Depth Breakdown:
  Depth 1: 0.001s, 20 nodes
  Depth 2: 0.005s, 400 nodes
  Depth 3: 0.05s, 8,000 nodes
  Depth 4: 0.4s, 160,000 nodes
  Depth 5: 1.85s, 1,066,147 nodes
```

### 5. Commandes CLI

```
trace on              -- Activer le tracing
trace off             -- Désactiver le tracing
trace level <level>   -- Changer le niveau (info, debug, trace)
trace export <file>   -- Exporter les traces en JSON
trace report          -- Afficher le rapport texte
trace chrome <file>   -- Exporter au format Chrome Tracing
trace reset           -- Réinitialiser les métriques
```

### 6. Zero-cost quand désactivé

Le tracing doit avoir un **coût quasi-nul** quand désactivé :

| Langage | Stratégie zero-cost |
|---|---|
| Rust | `#[cfg(feature = "tracing")]` conditional compilation, macros qui se réduisent à rien |
| TypeScript | Flag vérifié une seule fois, fonctions inline vidées par le JIT |
| Python | Decorator qui retourne la fonction originale si désactivé |
| PHP | `if (self::$enabled)` court-circuit |
| Dart | `const bool.fromEnvironment('TRACING')` compile-time flag |
| Ruby | `if Tracer.enabled?` avec branchement |
| Lua | Table de no-op fonctions |

## Fichiers à créer par langage

```
<lang>/
├── src/
│   ├── tracing/
│   │   ├── mod.{ext}           -- Module principal, configuration
│   │   ├── span.{ext}          -- Span et SpanContext
│   │   ├── event.{ext}         -- Events ponctuels
│   │   ├── metrics.{ext}       -- Compteurs et histogrammes
│   │   ├── exporter_json.{ext} -- Export JSON Lines
│   │   ├── exporter_chrome.{ext} -- Export Chrome Tracing
│   │   ├── report.{ext}        -- Rapport texte
│   │   └── decorator.{ext}     -- Decorators/macros d'instrumentation
```

## Dépendances

- **Bénéficie de** : PRD-03 (TT + iterative deepening) pour les métriques TT
- **Indépendant de** : tous les autres PRDs (le tracing est transversal)

## Tests de validation

1. **Spans** : vérifier la hiérarchie parent/enfant
2. **Métriques** : `nodes_searched` après un `ai 3` > 0
3. **Export JSON** : le fichier exporté est du JSON valide
4. **Chrome Tracing** : le fichier est valide dans Perfetto
5. **Zero-cost** : pas de ralentissement mesurable quand le tracing est off
6. **Rapport** : toutes les métriques sont affichées et cohérentes
7. **Régression** : aucun changement de comportement quand le tracing est off

## Critères de succès

- [ ] API de spans avec hiérarchie parent/enfant
- [ ] Au moins 8 métriques de recherche
- [ ] Export JSON Lines fonctionnel
- [ ] Export Chrome Tracing fonctionnel
- [ ] Rapport texte lisible
- [ ] Zero-cost quand désactivé (benchmark avant/après)
- [ ] Instrumentation d'au moins 5 fonctions clés (minimax, evaluate, generate_moves, order_moves, tt_probe)
- [ ] Temps de build mesurés avant/après (impact des imports/decorators dans tous les fichiers)
