# Language Statistics Data

This file contains popularity rankings and metadata for all programming languages used in The Great Analysis Challenge.

## Purpose

The `language_statistics.yaml` file serves as a static snapshot of:
- **TIOBE Index rankings** - Industry-standard language popularity index
- **GitHub repository counts** - Open source ecosystem size indicators
- **Language metadata** - Emojis, official websites, and descriptions

## Data Sources

- **TIOBE Index**: https://www.tiobe.com/tiobe-index/
  - Monthly updated programming language popularity rankings
  - Based on search engine results and industry metrics
  
- **GitHub Ranking**: https://github.com/EvanLi/Github-Ranking
  - Repository counts per programming language
  - Updated regularly from GitHub's public data

## Update Policy

The statistics file should be updated **when it becomes older than one month**.

### How to Check if Update is Needed

```bash
python3 check_statistics_freshness.py
```

This script will:
- Display the current age of the data
- Show the last update date
- Indicate if an update is needed (exit code 2)
- Return success if data is fresh (exit code 0)

### How to Update

1. **Check TIOBE Index** (https://www.tiobe.com/tiobe-index/)
   - Note the current month/year rankings
   - Update `tiobe_rank` values (1-50, or null for languages not in top 50)
   - Update `tiobe_rating` percentages if available

2. **Check GitHub Ranking** (https://github.com/EvanLi/Github-Ranking)
   - Review repository counts per language
   - Update `github_stars` (format: "10M+", "500K+", etc.)
   - Update `github_repos_approx` (numeric values)

3. **Update the metadata section**
   - Set `last_updated` to current date (YYYY-MM-DD format)
   - Verify source URLs are still valid

4. **Rebuild the website**
   ```bash
   python3 build_website.py
   ```

5. **Verify changes**
   - Check `docs/index.html` for updated statistics
   - Verify footer shows correct "last updated" date
   - Ensure README.md links are working

## File Format

The YAML file has two main sections:

### Metadata Section
```yaml
metadata:
  last_updated: "YYYY-MM-DD"
  tiobe_source: "URL"
  github_source: "URL"
  update_frequency: "monthly"
```

### Languages Section
```yaml
languages:
  language_name:
    emoji: "🦀"
    website: "https://..."
    tiobe_rank: 14          # 1-50 or null
    tiobe_rating: "1.10%"   # Optional percentage
    github_stars: "4.5M+"   # Human-readable format
    github_repos_approx: 4500000  # Numeric value
    description: "Brief description"
```

## Integration

The data is automatically used by:
- `build_website.py` - Generates the static website with language statistics
- `README.md` - References the sources and file location
- Website footer - Displays attribution links and last updated date

## Notes

- Languages not in TIOBE top 50 should have `tiobe_rank: null`
- GitHub statistics are approximate and rounded for readability
- Keep descriptions concise (one line)
- Maintain consistency in emoji and formatting
- All source URLs should be publicly accessible
