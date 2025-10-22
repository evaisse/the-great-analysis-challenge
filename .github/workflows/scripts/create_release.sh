#!/bin/bash
# Create release version, commit changes, and push tag
# Usage: create_release.sh <version_type> <readme_changed> <excellent_count> <good_count> <needs_work_count> <total_count>

set -e

VERSION_TYPE="$1"
README_CHANGED="$2"
EXCELLENT_COUNT="$3"
GOOD_COUNT="$4"
NEEDS_WORK_COUNT="$5"
TOTAL_COUNT="$6"

# Get current version
CURRENT_VERSION=$(git tag --sort=-version:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1 || echo "v0.0.0")
echo "current_version=$CURRENT_VERSION" >> $GITHUB_OUTPUT

# Determine version bump
if [[ -z "$VERSION_TYPE" ]]; then
    VERSION_TYPE="patch"
fi
echo "version_type=$VERSION_TYPE" >> $GITHUB_OUTPUT

# Calculate new version
IFS='.' read -r -a version_parts <<< "${CURRENT_VERSION#v}"
MAJOR=${version_parts[0]:-0}
MINOR=${version_parts[1]:-0}
PATCH=${version_parts[2]:-0}

case $VERSION_TYPE in
    major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
    minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
    patch) PATCH=$((PATCH + 1)) ;;
esac

NEW_VERSION="v$MAJOR.$MINOR.$PATCH"
echo "new_version=$NEW_VERSION" >> $GITHUB_OUTPUT

# Configure git and commit changes if README was updated
if [[ "$README_CHANGED" == "true" ]]; then
    git config --local user.email "action@github.com"
    git config --local user.name "GitHub Action"
    
    # Copy benchmark reports to repo
    mkdir -p benchmark_reports
    find benchmark_artifacts/ -name "*.txt" -exec cp {} benchmark_reports/ \; 2>/dev/null || true
    find benchmark_artifacts/ -name "*.json" -exec cp {} benchmark_reports/ \; 2>/dev/null || true
    
    git add benchmark_reports/ README.md
    
    git commit -m "$(cat <<EOF
chore: update implementation status from benchmark suite

Benchmark results summary:
- Total implementations: $TOTAL_COUNT
- 🟢 Excellent: $EXCELLENT_COUNT
- 🟡 Good: $GOOD_COUNT  
- 🔴 Needs work: $NEEDS_WORK_COUNT

Performance testing completed with status updates.
EOF
)"
    
    git push origin master
    echo "✅ Changes committed and pushed"
fi

# Create and push tag
git tag -a "$NEW_VERSION" -m "Release $NEW_VERSION - Benchmark Update"
git push origin "$NEW_VERSION"
echo "✅ Release tag $NEW_VERSION created"