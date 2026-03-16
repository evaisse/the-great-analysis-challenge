# Performance Testing

Shared performance reporting is handled by:

```bash
./workflow benchmark-stress --impl implementations/<language> --track v1 --profile quick
```

Useful variants:

```bash
./workflow benchmark-stress --impl implementations/rust --output reports/rust.out.txt --json reports/rust.json
./workflow benchmark-stress --track v2-full --profile full
./workflow benchmark-concurrency --impl implementations/rust --profile quick
./workflow code-size-metrics --impl implementations/rust
./workflow refresh-report-metrics
```

The benchmark JSON keeps `tokens-v2` under `metrics` and adds optional `tokens-v3` semantic data under `semantic_metrics`.
