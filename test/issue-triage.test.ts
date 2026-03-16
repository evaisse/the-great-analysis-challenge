import { describe, expect, test } from "bun:test";

import { analyzeIssueContent } from "../tooling/issue-triage.ts";

describe("issue triage analysis", () => {
  test("detects bug issues", () => {
    const result = analyzeIssueContent(
      "Error when moving pawn",
      "I get a crash when I try to move a pawn in the Python implementation.",
      [],
    );
    expect(result.suggested_labels).toContain("bug");
  });

  test("detects enhancement requests", () => {
    const result = analyzeIssueContent(
      "Add support for chess960",
      "It would be great to add Fischer Random Chess support to all implementations.",
      [],
    );
    expect(result.suggested_labels).toContain("enhancement");
  });

  test("detects documentation issues", () => {
    const result = analyzeIssueContent(
      "Update README with better examples",
      "The current README could use more detailed examples of how to use the chess engines.",
      [],
    );
    expect(result.suggested_labels).toContain("documentation");
  });

  test("detects implementation requests", () => {
    const result = analyzeIssueContent(
      "Add Elixir implementation",
      "I'd like to add a new chess engine implementation in Elixir.",
      [],
    );
    expect(result.suggested_labels).toContain("implementation");
  });

  test("requests clarification for short issues", () => {
    const result = analyzeIssueContent("Bug", "It doesn't work", []);
    expect(result.needs_clarification).toBe(true);
    expect(result.clarification_comment).not.toBeNull();
  });

  test("requests clarification for empty bodies", () => {
    const result = analyzeIssueContent("Feature request", "", []);
    expect(result.needs_clarification).toBe(true);
  });

  test("improves lowercase titles", () => {
    const result = analyzeIssueContent(
      "fix the bug in python",
      "There is a bug in the Python implementation that needs to be fixed.",
      [],
    );
    expect(result.improved_title).not.toBeNull();
    expect(result.improved_title?.[0]).toBe(result.improved_title?.[0]?.toUpperCase());
  });

  test("flags vague titles", () => {
    const result = analyzeIssueContent(
      "Bug",
      "There is an error when trying to move pieces in the game.",
      [],
    );
    expect(result.improved_title).toContain("[Needs Detail]");
  });

  test("detects multiple labels", () => {
    const result = analyzeIssueContent(
      "Performance issue in Python implementation",
      "The Python chess engine is running very slowly. We should optimize the move generation algorithm.",
      [],
    );
    expect(result.suggested_labels).toContain("performance");
    expect(result.suggested_labels).toContain("implementation");
  });

  test("detects workflow issues", () => {
    const result = analyzeIssueContent(
      "Create a issue triage workflow",
      "Please create a copilot assisted issue triage workflow.",
      [],
    );
    expect(result.suggested_labels).toContain("ci/cd");
    expect(result.suggested_labels).toContain("triage");
  });
});
