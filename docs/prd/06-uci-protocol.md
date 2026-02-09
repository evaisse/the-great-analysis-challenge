# PRD-06 : Support du protocole UCI & Machine à états

## Résumé

Implémenter le protocole UCI (Universal Chess Interface), le standard de communication entre moteurs d'échecs et interfaces graphiques. Cela inclut une machine à états formelle pour gérer les transitions du protocole, le parsing des commandes UCI, et la gestion des options configurables.

## Métriques cibles

| Indicateur | Valeur |
|---|---|
| LOC ajoutées par langage | +700 – 1 800 |
| LOC totales ajoutées (×7) | ~4 900 – 12 600 |
| Priorité | **P2 — Stress typé (compile-time)** |

## Pertinence pour le projet

### Valeur fonctionnelle (moteur d'échecs)

UCI est le protocole utilisé par **tous les moteurs d'échecs modernes** (Stockfish, Leela, Komodo...) pour communiquer avec les interfaces graphiques (Arena, CuteChess, Lichess). Actuellement, le moteur utilise un protocole propriétaire simple. Ajouter UCI permet :

- **Interopérabilité** : le moteur peut être utilisé avec n'importe quelle GUI d'échecs
- **Benchmarking standardisé** : des outils comme `cutechess-cli` peuvent faire jouer nos implémentations l'une contre l'autre automatiquement
- **Professionnalisation** : UCI est le signe d'un moteur "sérieux"
- **Tournois** : possibilité de faire participer le moteur à des tournois automatisés

Le protocole est bien défini mais verbeux — beaucoup de commandes et de réponses.

### Valeur pour l'objectif du projet (stress des toolchains)

UCI est un protocole à **états** avec des transitions strictes, ce qui force l'implémentation d'une **machine à états formelle** — un pattern qui stress les analyseurs statiques de manière unique :

| Langage | Ce que ça stress | Détail |
|---|---|---|
| **Rust** | Enums exhaustifs, ownership, channels | `enum UCIState { Idle, WaitingForIsReady, Searching, Pondering }` avec transitions vérifiées par le compilateur. Communication moteur↔UCI via `mpsc::channel` — le borrow checker vérifie le threading |
| **TypeScript** | State machines typées, unions | `type UCIState = 'idle' | 'ready' | 'searching'`, transitions comme `Record<UCIState, Partial<Record<UCICommand, UCIState>>>` — `tsc` doit vérifier la complétude du mapping |
| **Python** | `Enum`, `match`, Protocol | `class UCIState(Enum)`, `match state, command:` pattern matching avec vérification d'exhaustivité, `Protocol` pour l'interface de communication |
| **PHP** | PHPStan enums (PHP 8.1), analyse de flux | `enum UCIState: string`, `match` expressions, PHPStan doit vérifier que toutes les transitions sont couvertes |
| **Dart** | Sealed classes, exhaustiveness | `sealed class UCIState`, `switch` exhaustif, `Stream<UCICommand>` pour la communication asynchrone |
| **Ruby** | State machines, DSL | Gem-style state machine DSL ou implémentation manuelle, complexité cyclomatique élevée |
| **Lua** | Tables comme state machines | Machine à états via tables de fonctions, coroutines pour la communication |

**Point clé** : Une machine à états avec N états et M commandes produit un espace de N×M transitions que l'analyseur statique doit vérifier pour exhaustivité. Avec ~5 états et ~15 commandes, c'est 75 transitions possibles à valider.

## Description fonctionnelle

### 1. Commandes UCI (entrantes)

| Commande | Description |
|---|---|
| `uci` | Identifier le moteur, demander le mode UCI |
| `debug [ on | off ]` | Activer/désactiver le mode debug |
| `isready` | Synchronisation — le moteur doit répondre `readyok` |
| `setoption name <id> [value <x>]` | Configurer une option |
| `register` | (Ignoré — pas d'enregistrement) |
| `ucinewgame` | Nouvelle partie — réinitialiser les caches |
| `position [startpos | fen <fen>] [moves <m1> <m2> ...]` | Définir la position |
| `go <params>` | Lancer la recherche |
| `stop` | Arrêter la recherche |
| `ponderhit` | L'adversaire a joué le coup prévu |
| `quit` | Quitter |

### 2. Paramètres de `go`

| Paramètre | Description |
|---|---|
| `searchmoves <m1> <m2> ...` | Restreindre la recherche à ces coups |
| `ponder` | Réfléchir pendant le tour de l'adversaire |
| `wtime <ms>` | Temps restant pour les blancs |
| `btime <ms>` | Temps restant pour les noirs |
| `winc <ms>` | Incrément par coup (blancs) |
| `binc <ms>` | Incrément par coup (noirs) |
| `movestogo <n>` | Coups restants avant le prochain contrôle |
| `depth <n>` | Profondeur maximale |
| `nodes <n>` | Nœuds maximaux |
| `mate <n>` | Chercher un mat en n coups |
| `movetime <ms>` | Temps exact par coup |
| `infinite` | Recherche infinie (arrêt sur `stop`) |

### 3. Réponses UCI (sortantes)

| Réponse | Description |
|---|---|
| `id name <name>` | Nom du moteur |
| `id author <author>` | Auteur |
| `uciok` | Le moteur est prêt pour UCI |
| `readyok` | Réponse à `isready` |
| `bestmove <move> [ponder <move>]` | Meilleur coup trouvé |
| `copyprotection` | (Non utilisé) |
| `registration` | (Non utilisé) |
| `info <params>` | Informations pendant la recherche |
| `option name <id> type <t> [default <x>] [min <x>] [max <x>] [var <x>]` | Déclarer une option |

### 4. Informations pendant la recherche (`info`)

```
info depth 12 seldepth 18 score cp 35 nodes 1234567 nps 2456789 time 503 pv e2e4 e7e5 g1f3
info depth 12 score mate 3 nodes 45678 time 12 pv d1h5 f7f6 h5e8
info string Analyzing position...
info currmove e2e4 currmovenumber 1
```

### 5. Machine à états

```
States:
  BOOT        → En attente de "uci"
  UCI_SENT    → "uci" reçu, envoi des options
  IDLE        → Prêt, en attente de commandes
  SEARCHING   → Recherche en cours
  PONDERING   → Réflexion pendant le tour adverse

Transitions:
  BOOT       + "uci"        → UCI_SENT  (envoyer id + options + uciok)
  UCI_SENT   + "isready"    → IDLE      (envoyer readyok)
  IDLE       + "isready"    → IDLE      (envoyer readyok)
  IDLE       + "position"   → IDLE      (charger position)
  IDLE       + "go"         → SEARCHING (lancer recherche)
  IDLE       + "go ponder"  → PONDERING (lancer réflexion)
  SEARCHING  + "stop"       → IDLE      (envoyer bestmove)
  SEARCHING  + (search done)→ IDLE      (envoyer bestmove)
  PONDERING  + "ponderhit"  → SEARCHING (continuer en mode normal)
  PONDERING  + "stop"       → IDLE      (envoyer bestmove)
  ANY        + "quit"       → EXIT
  ANY        + "ucinewgame" → IDLE      (réinitialiser)
```

### 6. Options configurables

| Option | Type | Default | Description |
|---|---|---|---|
| `Hash` | spin | 16 | Taille de la TT en MB |
| `Threads` | spin | 1 | Nombre de threads |
| `MultiPV` | spin | 1 | Nombre de lignes principales |
| `UCI_AnalyseMode` | check | false | Mode analyse |
| `RichEval` | check | false | Évaluation riche (PRD-02) |

### 7. Dual-mode : protocole custom + UCI

Le moteur doit supporter les deux protocoles. Détection automatique :

```
Si le premier message est "uci" → mode UCI
Sinon → mode protocole custom existant
```

## Fichiers à créer par langage

```
<lang>/
├── src/
│   ├── uci/
│   │   ├── mod.{ext}           -- Module principal
│   │   ├── protocol.{ext}      -- Parsing des commandes UCI
│   │   ├── state_machine.{ext} -- Machine à états formelle
│   │   ├── options.{ext}       -- Gestion des options
│   │   ├── info.{ext}          -- Formatage des messages info
│   │   ├── go_params.{ext}     -- Parsing des paramètres go
│   │   └── response.{ext}      -- Formatage des réponses
```

## Contraintes de compatibilité

- Le protocole custom existant doit continuer à fonctionner
- Détection automatique du mode (UCI vs custom)
- Les tests existants (protocole custom) ne sont pas affectés
- UCI est un ajout pur

## Tests de validation

1. **Handshake** : `uci` → réception de `id name`, `id author`, `uciok`
2. **Synchronisation** : `isready` → `readyok` dans tous les états
3. **Position** : `position startpos moves e2e4 e7e5` → position correcte
4. **Recherche** : `go depth 3` → `info` messages + `bestmove`
5. **Temps** : `go wtime 300000 btime 300000 winc 2000 binc 2000` → recherche avec time management
6. **Stop** : `go infinite` + `stop` → `bestmove` immédiat
7. **Options** : `setoption name Hash value 32` → TT redimensionnée
8. **Machine à états** : commandes invalides dans un état donné → ignorées gracieusement
9. **Compatibilité cutechess** : le moteur fonctionne avec `cutechess-cli`

## Critères de succès

- [ ] Machine à états formelle avec toutes les transitions
- [ ] Toutes les commandes UCI parsées
- [ ] Messages `info` pendant la recherche
- [ ] `bestmove` avec coup de ponder optionnel
- [ ] Au moins 3 options configurables
- [ ] Dual-mode (UCI + custom) avec détection automatique
- [ ] Tests de conformité UCI
- [ ] Temps de build et d'analyse mesurés avant/après
