# Issue Triage Workflow

This workflow automatically triages issues using intelligent analysis to:
- Add appropriate labels based on issue content
- Request clarification when needed
- Improve issue titles for better clarity

## How It Works

The workflow runs automatically when:
- A new issue is opened
- An existing issue is edited
- An issue is reopened

It can also be triggered manually via workflow dispatch for any specific issue.

## Features

### 1. Automatic Label Detection

The workflow analyzes the issue title and body to suggest relevant labels:

- **bug**: Issues mentioning errors, crashes, or broken functionality
- **enhancement**: Feature requests and improvements
- **documentation**: Documentation-related issues
- **performance**: Performance concerns or optimization requests
- **testing**: Test-related issues
- **implementation**: New language implementation requests
- **ci/cd**: Workflow and automation issues
- **help wanted**: Questions or requests for assistance
- **good first issue**: Simple issues suitable for beginners

### 2. Clarification Requests

When issues lack sufficient detail, the workflow automatically:
- Adds a "needs clarification" label
- Posts a helpful comment asking for more information
- Provides templates for different issue types (bugs, features, implementations)

### 3. Title Improvements

The workflow can improve issue titles by:
- Capitalizing the first letter
- Removing trailing punctuation
- Flagging vague titles with `[Needs Detail]` prefix

## Usage

### Automatic Triage

Simply open or edit an issue - the workflow runs automatically.

### Manual Triage

To manually triage a specific issue:

1. Go to Actions → Issue Triage with Copilot
2. Click "Run workflow"
3. Enter the issue number
4. Click "Run workflow"

## Examples

### Example 1: Bug Report

**Original Issue:**
- Title: "error in python"
- Body: "doesn't work"

**After Triage:**
- Title: "Error in python"
- Labels: `bug`, `implementation`, `needs clarification`
- Comment: Requesting steps to reproduce, expected behavior, etc.

### Example 2: Feature Request

**Original Issue:**
- Title: "Add Rust implementation"
- Body: "Would like to add Rust chess engine"

**After Triage:**
- Labels: `enhancement`, `implementation`
- Comment: Requesting language version, timeline, experience level

### Example 3: Documentation

**Original Issue:**
- Title: "Update README with benchmarks"
- Body: "The README should include detailed benchmark results"

**After Triage:**
- Labels: `documentation`, `enhancement`
- No clarification needed (sufficient detail provided)

## Testing

You can test the triage logic locally:

```bash
python3 .github/test-triage.py
```

This runs unit tests for the label detection and clarification logic without requiring GitHub API access.

## Configuration

### Required Secrets

- `GITHUB_TOKEN`: Automatically provided by GitHub Actions

### Optional Secrets

- `OPENAI_API_KEY`: For advanced AI-powered analysis (future enhancement)

### Customization

To customize label detection, edit the `label_keywords` dictionary in `.github/workflows/scripts/triage_issue.py`:

```python
label_keywords = {
    'bug': ['bug', 'error', 'broken', 'fail', 'crash'],
    'enhancement': ['feature', 'enhancement', 'improve', 'add'],
    # Add more labels and keywords as needed
}
```

## Permissions

The workflow requires:
- `issues: write` - To add labels and comments
- `contents: read` - To read repository content

## Workflow File

The workflow is defined in `.github/workflows/issue-triage.yaml`.

## Contributing

To improve the triage logic:

1. Edit `.github/workflows/scripts/triage_issue.py`
2. Add tests to `.github/test-triage.py`
3. Run tests locally: `python3 .github/test-triage.py`
4. Submit a PR with your improvements

## Future Enhancements

Potential improvements:
- Integration with OpenAI API for more sophisticated analysis
- Automatic assignment to team members based on expertise
- Priority detection and labeling
- Duplicate issue detection
- Link to related issues or documentation
