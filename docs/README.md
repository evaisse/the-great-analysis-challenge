# Website Generation

This directory contains the generated static website for [The Great Analysis Challenge](https://evaisse.github.io/the-great-analysis-challenge/).

## Overview

The website provides:
- **Comprehensive Comparison Table**: All implementations with metrics (LOC, build times, features)
- **Interactive Source Code Explorer**: Browse source code for each implementation
- **Modern Responsive Design**: Works on desktop and mobile devices

## Generation

The website is automatically generated from:
- Benchmark data in `../benchmark_reports/`
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
├── index.html              # Main comparison page
├── source_*.html           # Source explorer for each language
├── style.css               # Stylesheet
└── .nojekyll              # Disable Jekyll processing
```

## Files

- **index.html**: Main landing page with comparison table
- **source_<language>.html**: Source code explorer for each implementation
- **style.css**: Responsive CSS styling
- **.nojekyll**: Tells GitHub Pages not to process with Jekyll

## Maintenance

The website is regenerated automatically when:
1. Code is pushed to main
2. Benchmark data is updated (weekly)
3. Manually triggered via GitHub Actions

No manual updates to HTML files are needed - they're all generated from the source data.
