# Language Statistics Reference

`language_statistics.yaml` is the source of truth for language popularity metadata used by reporting assets.

## What It Stores

- TIOBE ranking metadata
- GitHub repository-size approximations
- Per-language descriptors (emoji, site, short description)
- Update metadata (`last_updated`, sources)

## Primary Sources

- TIOBE Index: <https://www.tiobe.com/tiobe-index/>
- GitHub language ranking: <https://github.com/EvanLi/Github-Ranking>

## Update Cadence

Update at least monthly.

Freshness check:

```bash
./workflow check-statistics-freshness
```

## Update Procedure

1. Refresh TIOBE ranks/ratings.
2. Refresh GitHub repo count approximations.
3. Update `metadata.last_updated` in `language_statistics.yaml`.
4. Rebuild dependent outputs.
5. Verify generated artifacts reference the new date.
