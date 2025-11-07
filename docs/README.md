# Website Generation

This directory contains the generated static website for [The Great Analysis Challenge](https://evaisse.github.io/the-great-analysis-challenge/).

## Overview

The website provides:
- **Plain Comparison Ledger**: A single table listing every implementation with latest major release date, LOC, build/test/analyze timings, and declared features.
- **Direct Repository Links**: Each row points straight to the implementation directory on GitHub for deeper inspection.
- **Lo-fi Presentation**: Monospace typography, muted palette, and zero JavaScript for a low-tech reading experience.

## Generation

The website is automatically generated from:
- Benchmark data in `../reports/`
- Implementation metadata from `chess.meta` files
- Source code analysis (line counting)

### Automatic Deployment

The website is automatically built and deployed via GitHub Actions:
- **On push to main branch**
- **Weekly on Sunday** (after benchmark workflow runs)
- **Manual trigger** via GitHub Actions UI

See `.github/workflows/deploy-website.yaml` for the deployment workflow.

### Manual Generation

Generate the website locally:

```bash
# From repository root
make website

# Or run the script directly
python3 build_website.py
```

### Local Preview

```bash
cd docs
python3 -m http.server 8080
# Visit http://localhost:8080
```

## Structure

```
docs/
├── index.html    # Main comparison page
├── style.css     # Monospace lo-fi stylesheet
├── favicon.svg   # Retro favicon used by the site
├── README.md     # This file
└── .nojekyll     # Disable Jekyll processing on GitHub Pages
```

## Files

- **index.html**: Main landing page with the comparison ledger
- **style.css**: Lo-fi styling for the site
- **favicon.svg**: Site icon bundled with the pages
- **.nojekyll**: Tells GitHub Pages not to process with Jekyll

## Maintenance

The website is regenerated automatically when:
1. Code is pushed to main
2. Benchmark data is updated (weekly)
3. Manually triggered via GitHub Actions

No manual updates to HTML files are needed - they're all generated from the source data.
