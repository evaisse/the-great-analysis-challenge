# Bun Chess Engine (JavaScript)

Implémentation du moteur d'échecs en JavaScript pur exécutée avec Bun.

## Objectif
- JavaScript pur (aucun TypeScript)
- Respect du protocole CLI (`stdin` / `stdout`)
- Conformité progressive à `CHESS_ENGINE_SPECS.md`

## Commandes
- `make build` : vérifie la disponibilité de Bun
- `make test` : exécute les tests Bun
- `make analyze` : vérification minimale de l'environnement
- `make docker-build` : construit l'image Docker
- `make docker-test` : lance un smoke test protocole

## Exécution
```bash
bun run chess.js
```

## Statut
Base initiale Bun créée à partir de l'implémentation JavaScript existante, puis adaptée au runtime Bun.
