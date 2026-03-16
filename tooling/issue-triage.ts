import { writeGithubOutput } from "./shared.ts";

const MIN_TITLE_LENGTH = 10;
const VAGUE_TITLES = new Set(["issue", "bug", "help", "question", "problem"]);
const MIN_BODY_LENGTH = 20;
const IMPLEMENTATION_KEYWORDS = ["which", "what", "version", "language"];

export interface IssueAnalysis {
  suggested_labels: string[];
  improved_title: string | null;
  needs_clarification: boolean;
  clarification_comment: string | null;
}

async function githubApi<T>(repo: string, path: string, init: RequestInit = {}): Promise<T> {
  const token = process.env.GITHUB_TOKEN;
  if (!token) {
    throw new Error("GITHUB_TOKEN environment variable not set");
  }
  const response = await fetch(`https://api.github.com/repos/${repo}${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/vnd.github+json",
      "User-Agent": "tgac-bun-tooling",
      ...(init.headers ?? {}),
    },
  });
  if (!response.ok) {
    throw new Error(`GitHub API ${response.status}: ${await response.text()}`);
  }
  return (await response.json()) as T;
}

export function analyzeIssueContent(title: string, body: string | null | undefined, existingLabels: string[]): IssueAnalysis {
  const analysis: IssueAnalysis = {
    suggested_labels: [],
    improved_title: null,
    needs_clarification: false,
    clarification_comment: null,
  };

  const fullText = `${title} ${body ?? ""}`.toLowerCase();
  const labelKeywords: Record<string, string[]> = {
    bug: ["bug", "error", "broken", "fail", "crash", "issue", "problem", "not working"],
    enhancement: ["feature", "enhancement", "improve", "add", "new", "support", "would like"],
    documentation: ["documentation", "docs", "readme", "guide", "explain", "clarify"],
    performance: ["performance", "slow", "speed", "optimization", "benchmark", "faster"],
    testing: ["test", "testing", "ci", "workflow", "validation"],
    "good first issue": ["simple", "easy", "beginner", "good first", "starter"],
    "help wanted": ["help", "assistance", "support", "question"],
    implementation: ["implementation", "language", "engine"],
    "ci/cd": ["workflow", "github actions", "ci", "cd", "pipeline", "automation"],
    triage: ["triage"],
  };

  for (const [label, keywords] of Object.entries(labelKeywords)) {
    if (keywords.some((keyword) => fullText.includes(keyword))) {
      analysis.suggested_labels.push(label);
    }
  }

  const titleLower = title.toLowerCase().trim();
  if (title.length < MIN_TITLE_LENGTH || VAGUE_TITLES.has(titleLower)) {
    analysis.improved_title = `[Needs Detail] ${title}`;
  } else if (title[0] === title[0]?.toLowerCase() || /[.,;:]$/.test(title)) {
    analysis.improved_title = `${title[0].toUpperCase()}${title.slice(1)}`.replace(/[.,;:]+$/, "");
  }

  const bodyText = (body ?? "").trim();
  if (!bodyText || bodyText.length < MIN_BODY_LENGTH) {
    analysis.needs_clarification = true;
    analysis.clarification_comment = [
      "Thank you for opening this issue!",
      "",
      "To help us better understand and address this issue, could you please provide more details?",
      "",
      "**For bug reports, please include:**",
      "- Steps to reproduce the issue",
      "- Expected behavior",
      "- Actual behavior",
      "- Language implementation affected (if applicable)",
      "- Any error messages or logs",
      "",
      "**For feature requests, please include:**",
      "- Clear description of the proposed feature",
      "- Use cases and benefits",
      "- Possible implementation approach (if you have ideas)",
      "",
      "**For new language implementations:**",
      "- Language name and version",
      "- Your experience with the language",
      "- Timeline estimate",
    ].join("\n");
  } else if (fullText.includes("implementation") && !IMPLEMENTATION_KEYWORDS.some((keyword) => fullText.includes(keyword))) {
    analysis.needs_clarification = true;
    analysis.clarification_comment = [
      "Thank you for your interest in contributing a new implementation!",
      "",
      "To help us track and support your work, could you please provide:",
      "1. Language name and version",
      "2. Your timeline",
      "3. Your experience level with the language",
      "4. Any questions you have about the specification or process",
      "",
      "Please review:",
      "- CHESS_ENGINE_SPECS.md",
      "- docs/IMPLEMENTATION_GUIDELINES.md",
      "- docs/CONTRIBUTING.md",
    ].join("\n");
  }

  analysis.suggested_labels = [...new Set(analysis.suggested_labels)];
  return analysis;
}

async function ensureLabels(repo: string, labels: string[]): Promise<void> {
  const existing = await githubApi<any[]>(repo, "/labels?per_page=100");
  const existingMap = new Set(existing.map((label) => String(label.name).toLowerCase()));
  const colors: Record<string, string> = {
    bug: "d73a4a",
    enhancement: "a2eeef",
    documentation: "0075ca",
    performance: "fbca04",
    testing: "1d76db",
    "good first issue": "7057ff",
    "help wanted": "008672",
    implementation: "c5def5",
    "ci/cd": "f9d0c4",
    triage: "ffffff",
    "needs clarification": "ededed",
  };

  for (const label of labels) {
    if (existingMap.has(label.toLowerCase())) continue;
    await githubApi(repo, "/labels", {
      method: "POST",
      body: JSON.stringify({
        name: label,
        color: colors[label.toLowerCase()] ?? "ededed",
        description: "Automatically added by issue triage workflow",
      }),
    });
  }
}

export async function triageIssue(repo: string, issueNumber: number): Promise<number> {
  const issue = await githubApi<any>(repo, `/issues/${issueNumber}`);
  console.log(`Triaging issue #${issueNumber}: ${issue.title}`);
  const currentLabels = (issue.labels ?? []).map((label: any) => String(label.name));
  console.log(`Current labels: ${JSON.stringify(currentLabels)}`);

  const analysis = analyzeIssueContent(issue.title, issue.body, currentLabels);
  console.log(`Analysis complete: ${JSON.stringify(analysis)}`);

  const allLabels = [...analysis.suggested_labels];
  if (analysis.needs_clarification) {
    allLabels.push("needs clarification");
  }
  await ensureLabels(repo, allLabels);

  const mergedLabels = [...new Set([...currentLabels, ...analysis.suggested_labels, ...(analysis.needs_clarification ? ["needs clarification"] : [])])];
  await githubApi(repo, `/issues/${issueNumber}`, {
    method: "PATCH",
    body: JSON.stringify({
      title: analysis.improved_title ?? issue.title,
      labels: mergedLabels,
    }),
  });

  if (analysis.needs_clarification && analysis.clarification_comment) {
    await githubApi(repo, `/issues/${issueNumber}/comments`, {
      method: "POST",
      body: JSON.stringify({ body: analysis.clarification_comment }),
    });
  }

  writeGithubOutput("triaged", "true");
  return 0;
}
