# Testing Framework

Shared testing now runs through the Bun CLI entrypoint at `./workflow`.

## Primary Commands

```bash
./workflow verify
./workflow test-harness --track v1
./workflow unit-contract --impl implementations/<language>
./workflow benchmark-stress --impl implementations/<language> --track v2-full --profile quick
./workflow benchmark-concurrency --impl implementations/<language> --profile quick
./workflow code-size-metrics --impl implementations/<language>
```

The root `Makefile` is the public interface for routine implementation validation:

```bash
make verify
make image DIR=<language>
make build DIR=<language>
make analyze DIR=<language>
make test DIR=<language>
make test-unit-contract DIR=<language>
make test-chess-engine DIR=<language>
```

## Test Assets

- `test_suite.json`: baseline protocol and behavior suite
- `contracts/unit_v1.json`: shared unit-contract suite
- `suites/`: staged v2/v3 suite definitions
- `fixtures/`: fixture-backed inputs used by staged suites

## Bun Tooling Tests

```bash
bun test
```

Current Bun tests cover:

- token metrics stability and git-aware file discovery
- semantic token metrics (`tokens-v3`)
- issue triage label/title heuristics
