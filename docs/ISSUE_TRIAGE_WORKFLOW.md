# Issue Triage Workflow

The issue triage workflow is driven by the shared Bun CLI and the Bun/TypeScript analyzer in `tooling/issue-triage.ts`.

## What It Does

- Applies labels inferred from issue title/body content
- Requests clarification for vague or incomplete issues
- Normalizes issue titles when they are too vague or stylistically inconsistent

## Runtime Entry Points

- GitHub Actions workflow: `.github/workflows/issue-triage.yaml`
- Local/CI CLI entry point: `./workflow triage-issue --repo <owner/repo> --issue <number>`
- Test suite: `bun test test/issue-triage.test.ts`

## Automatic Triggers

The workflow runs when:

- an issue is opened
- an issue is edited
- an issue is reopened

It can also be run manually with `workflow_dispatch`.

## Labels

The analyzer currently infers:

- `bug`
- `enhancement`
- `documentation`
- `performance`
- `testing`
- `implementation`
- `ci/cd`
- `help wanted`
- `good first issue`
- `triage`

If more detail is needed, it also applies `needs clarification`.

## Local Testing

```bash
bun test test/issue-triage.test.ts
```

To manually exercise the workflow logic against a real repository issue:

```bash
GITHUB_TOKEN=... ./workflow triage-issue --repo owner/repo --issue 123
```

## Customization

Adjust keyword-based heuristics in `tooling/issue-triage.ts`.

When changing the heuristics:

1. Update `tooling/issue-triage.ts`.
2. Update `test/issue-triage.test.ts`.
3. Run `bun test test/issue-triage.test.ts`.
