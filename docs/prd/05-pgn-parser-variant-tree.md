# PRD-05 : Parseur PGN & Arbre de variantes

## Résumé

Implémenter un parseur complet pour le format PGN (Portable Game Notation), le standard universel pour enregistrer les parties d'échecs, avec support des variantes imbriquées, commentaires, NAG (Numeric Annotation Glyphs), et résultats. Construire un arbre de variantes navigable permettant d'explorer les lignes alternatives.

## Métriques cibles

| Indicateur | Valeur |
|---|---|
| LOC ajoutées par langage | +900 – 2 500 |
| LOC totales ajoutées (×7) | ~6 300 – 17 500 |
| Priorité | **P2 — Stress typé (compile-time)** |

## Pertinence pour le projet

### Valeur fonctionnelle (moteur d'échecs)

Le PGN est le format standard pour les parties d'échecs depuis 1993. Actuellement, le moteur ne peut ni lire ni écrire de parties complètes — on ne peut que charger des positions via FEN. Le support PGN ajoute :

- **Import de parties** : charger des parties célèbres, des ouvertures, des bases de données
- **Export de parties** : sauvegarder les parties jouées avec le moteur (métadonnées, coups, résultat)
- **Variantes** : annoter une partie avec des lignes alternatives ("et si l'autre coup avait été joué ?")
- **Commentaires et annotations** : `{Ce coup est douteux}`, `!`, `?`, `!!`, `??`, etc.
- **Multi-parties** : un fichier PGN peut contenir des milliers de parties

C'est un vrai parseur de format texte, ce qui est fondamentalement différent du reste du code (qui est algorithmique/mathématique).

### Valeur pour l'objectif du projet (stress des toolchains)

Le PGN est un format complexe qui nécessite un **vrai parseur récursif**, ce qui stress les outils d'analyse de manière unique :

| Langage | Ce que ça stress | Détail |
|---|---|---|
| **Rust** | Lifetimes, enums récursifs, pattern matching | L'AST PGN est un `enum` récursif (`Node::Move`, `Node::Variation(Vec<Node>)`, `Node::Comment(String)`) — le compilateur doit vérifier l'exhaustivité du pattern matching. L'arbre de variantes avec des références nécessite `Rc<RefCell<>>` ou arènes |
| **TypeScript** | Unions discriminées, type narrowing | `type PGNNode = MoveNode | VariationNode | CommentNode | NAGNode` — le type-checker doit vérifier le narrowing dans chaque branche de `switch`. Les types récursifs (`VariationNode { children: PGNNode[] }`) stressent l'inférence |
| **Python** | `mypy` unions, pattern matching (3.10+) | `PGNNode = MoveNode | VariationNode | CommentNode`, `match node:` avec vérification d'exhaustivité, `@dataclass` récursifs, `Visitor` pattern avec `@overload` |
| **PHP** | PHPStan unions, analyse de flux | Union types `MoveNode|VariationNode|CommentNode`, `instanceof` narrowing, analyse de flux récursif — PHPStan doit prouver que tous les cas sont couverts |
| **Dart** | Sealed classes, pattern matching (Dart 3) | `sealed class PGNNode`, `switch (node) { MoveNode() => ..., VariationNode() => ... }` — l'analyseur vérifie l'exhaustivité |
| **Ruby** | Parsing complexe, Steep | Visitor pattern, case/in pattern matching (Ruby 3+), complexité cyclomatique élevée sur le parseur |
| **Lua** | Récursion, métatables | Parseur récursif descendant avec tables Lua imbriquées, gestion de la pile d'appels |

**Point clé** : Un parseur est l'archétype du code qui stress les analyseurs statiques car il contient : récursion, unions/variants, pattern matching, manipulation de chaînes, et un AST avec des types imbriqués. C'est fondamentalement différent du code numérique/algorithmique du reste du moteur.

## Description fonctionnelle

### 1. Format PGN — Syntaxe

```pgn
[Event "World Championship"]
[Site "Reykjavik"]
[Date "1972.07.11"]
[White "Fischer, Robert"]
[Black "Spassky, Boris"]
[Result "1-0"]

1. e4 c5 2. Nf3 d6 3. d4 cxd4 4. Nxd4 Nf6 5. Nc3 a6
{The Najdorf Variation} 6. Bg5 e6 7. f4 Be7 8. Qf3 Qc7
9. O-O-O Nbd7 (9... b5 10. Bxf6 gxf6 {An alternative}) 1-0
```

### 2. Lexer (Tokenizer)

Tokens à reconnaître :

| Token | Exemples | Pattern |
|---|---|---|
| `TAG_OPEN` | `[` | Caractère littéral |
| `TAG_CLOSE` | `]` | Caractère littéral |
| `TAG_NAME` | `Event`, `White` | `[A-Za-z_]+` |
| `TAG_VALUE` | `"Fischer"` | Chaîne entre guillemets |
| `MOVE_NUMBER` | `1.`, `12...` | `\d+\.+` |
| `SAN_MOVE` | `e4`, `Nxd4`, `O-O-O`, `e8=Q` | Notation SAN complète |
| `NAG` | `$1`, `$2`, `$6` | `\$\d+` |
| `COMMENT_OPEN` | `{` | Caractère littéral |
| `COMMENT_CLOSE` | `}` | Caractère littéral |
| `VARIATION_OPEN` | `(` | Caractère littéral |
| `VARIATION_CLOSE` | `)` | Caractère littéral |
| `RESULT` | `1-0`, `0-1`, `1/2-1/2`, `*` | Résultat de partie |
| `LINE_COMMENT` | `; comment` | Jusqu'à fin de ligne |

**Volume** : ~150-400 LOC.

### 3. Parseur récursif descendant

Grammaire simplifiée :

```
PGN          = Game*
Game         = TagSection MoveSection Result
TagSection   = Tag*
Tag          = "[" TAG_NAME TAG_VALUE "]"
MoveSection  = MoveElement*
MoveElement  = MoveNumber? SANMove NAG* Comment* Variation*
Variation    = "(" MoveElement+ ")"
Comment      = "{" text "}"
```

Le parseur doit être **récursif** pour gérer les variantes imbriquées (variante dans une variante) :

```pgn
1. e4 e5 (1... c5 (1... e6 {French Defense}) 2. Nf3 d6) 2. Nf3
```

**Volume** : ~300-800 LOC.

### 4. AST (Abstract Syntax Tree)

```
PGNGame {
  tags: Map<String, String>
  moves: PGNNode[]
  result: GameResult
}

PGNNode = 
  | MoveNode { san: String, move: Move, nags: NAG[], comment: String? }
  | VariationNode { moves: PGNNode[] }
  | CommentNode { text: String }
```

**Volume** : ~100-200 LOC.

### 5. Conversion SAN ↔ Coordonnées

Le PGN utilise la notation SAN (Standard Algebraic Notation) : `Nf3`, `exd5`, `O-O`, `e8=Q+`. Le moteur utilise la notation par coordonnées : `g1f3`, `e5d5`, `e1g1`, `e7e8Q`.

Il faut un convertisseur bidirectionnel :

```
san_to_move(board, "Nf3")  → Move(g1, f3)
move_to_san(board, Move(g1, f3)) → "Nf3"
```

La conversion SAN → coordonnées est non-triviale car elle nécessite de résoudre les ambiguïtés :

```
Nf3   → quel cavalier ? (disambiguïsation par la position)
Raxd1 → tour en colonne a capture en d1
R1d3  → tour en rangée 1 va en d3
```

**Volume** : ~200-500 LOC.

### 6. Visitor / Walker pattern

Pour parcourir l'arbre de variantes, implémenter un pattern Visitor :

```
trait PGNVisitor {
  fn visit_game(game: &PGNGame)
  fn visit_move(node: &MoveNode)
  fn enter_variation(node: &VariationNode)
  fn exit_variation(node: &VariationNode)
  fn visit_comment(node: &CommentNode)
}
```

Visiteurs concrets :
- **PGNPrinter** : sérialise l'arbre en PGN formaté
- **MoveCollector** : collecte la ligne principale
- **VariationCounter** : compte les variantes (pour statistiques)

**Volume** : ~150-400 LOC.

### 7. Commandes CLI

Nouvelles commandes à ajouter :

```
pgn load <filename>     -- Charger une partie depuis un fichier PGN
pgn save <filename>     -- Sauvegarder la partie courante en PGN
pgn show                -- Afficher la partie courante en PGN
pgn moves               -- Lister les coups de la partie courante
pgn variation enter     -- Entrer dans une variante
pgn variation exit      -- Sortir de la variante courante
pgn comment "texte"     -- Ajouter un commentaire au coup courant
```

## Fichiers à créer par langage

```
<lang>/
├── src/
│   ├── pgn/
│   │   ├── mod.{ext}          -- Module principal, ré-exports
│   │   ├── lexer.{ext}        -- Tokenizer
│   │   ├── parser.{ext}       -- Parseur récursif descendant
│   │   ├── ast.{ext}          -- Types de l'AST
│   │   ├── san.{ext}          -- Conversion SAN ↔ coordonnées
│   │   ├── visitor.{ext}      -- Pattern Visitor + visiteurs concrets
│   │   ├── printer.{ext}      -- Sérialisation PGN
│   │   └── game_tree.{ext}    -- Arbre de variantes navigable
```

## Contraintes de compatibilité

- Les commandes existantes ne sont pas modifiées
- Le PGN est un ajout pur (nouvelles commandes `pgn *`)
- Le parseur doit gérer les PGN malformés gracieusement (pas de crash)
- Support UTF-8 pour les commentaires

## Tests de validation

1. **Parsing basique** : parser un PGN simple (tags + coups + résultat)
2. **Variantes** : parser des variantes imbriquées sur 3+ niveaux
3. **SAN** : convertir SAN → coordonnées et retour pour 50+ coups
4. **Round-trip** : parse → print → parse doit donner le même AST
5. **Fichiers réels** : parser des PGN de parties célèbres (Fischer-Spassky, Kasparov-Deep Blue)
6. **Erreurs** : PGN malformé → message d'erreur clair, pas de crash
7. **Multi-parties** : parser un fichier avec 10+ parties

## Critères de succès

- [ ] Lexer complet (tous les tokens PGN)
- [ ] Parseur récursif descendant fonctionnel
- [ ] AST avec types discriminés/sealed
- [ ] Conversion SAN ↔ coordonnées bidirectionnelle
- [ ] Visitor pattern avec au moins 2 visiteurs concrets
- [ ] Commandes CLI `pgn load/save/show`
- [ ] Tests sur des PGN réels
- [ ] Temps de build et d'analyse mesurés avant/après
