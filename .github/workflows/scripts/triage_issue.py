#!/usr/bin/env python3
"""
Issue triage script using GitHub Copilot assistance.
Analyzes issues, adds labels, requests clarification, and improves titles.
"""

import os
import sys
import argparse
import json
from typing import List, Dict, Any, Optional
from github import Github, GithubException


def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description='Triage GitHub issues with AI assistance')
    parser.add_argument('--repo', required=True, help='Repository in format owner/repo')
    parser.add_argument('--issue', required=True, type=int, help='Issue number to triage')
    return parser.parse_args()


def get_available_labels(repo) -> List[str]:
    """Get all available labels in the repository."""
    try:
        return [label.name for label in repo.get_labels()]
    except GithubException as e:
        print(f"Warning: Could not fetch labels: {e}")
        return []


def analyze_issue_content(title: str, body: str, existing_labels: List[str]) -> Dict[str, Any]:
    """
    Analyze issue content and determine appropriate actions.
    
    This uses simple rule-based analysis since we may not have OpenAI API access.
    In production, this could be enhanced with OpenAI API calls.
    """
    analysis = {
        'suggested_labels': [],
        'improved_title': None,
        'needs_clarification': False,
        'clarification_comment': None
    }
    
    # Normalize text for analysis
    full_text = (title + " " + (body or "")).lower()
    
    # Define label mapping based on keywords
    label_keywords = {
        'bug': ['bug', 'error', 'broken', 'fail', 'crash', 'issue', 'problem', 'not working'],
        'enhancement': ['feature', 'enhancement', 'improve', 'add', 'new', 'support', 'would like'],
        'documentation': ['documentation', 'docs', 'readme', 'guide', 'explain', 'clarify'],
        'performance': ['performance', 'slow', 'speed', 'optimization', 'benchmark', 'faster'],
        'testing': ['test', 'testing', 'ci', 'workflow', 'validation'],
        'good first issue': ['simple', 'easy', 'beginner', 'good first', 'starter'],
        'help wanted': ['help', 'assistance', 'support', 'question'],
        'implementation': ['implementation', 'language', 'engine'],
        'ci/cd': ['workflow', 'github actions', 'ci', 'cd', 'pipeline', 'automation'],
        'triage': ['triage'],
    }
    
    # Analyze and suggest labels
    for label, keywords in label_keywords.items():
        if any(keyword in full_text for keyword in keywords):
            analysis['suggested_labels'].append(label)
    
    # Check if title needs improvement
    if title:
        title_lower = title.lower()
        # Check for vague titles
        if len(title) < 10 or title_lower.strip() in ['issue', 'bug', 'help', 'question', 'problem']:
            analysis['improved_title'] = f"[Needs Detail] {title}"
        # Check if title doesn't start with capital or ends with punctuation
        elif title[0].islower() or title.endswith('.') or title.endswith(','):
            improved = title[0].upper() + title[1:].rstrip('.,;:')
            analysis['improved_title'] = improved
    
    # Check if clarification is needed
    body_text = (body or "").strip()
    if not body_text or len(body_text) < 20:
        analysis['needs_clarification'] = True
        analysis['clarification_comment'] = (
            "Thank you for opening this issue! 👋\n\n"
            "To help us better understand and address this issue, could you please provide more details?\n\n"
            "**For bug reports, please include:**\n"
            "- Steps to reproduce the issue\n"
            "- Expected behavior\n"
            "- Actual behavior\n"
            "- Language implementation affected (if applicable)\n"
            "- Any error messages or logs\n\n"
            "**For feature requests, please include:**\n"
            "- Clear description of the proposed feature\n"
            "- Use cases and benefits\n"
            "- Possible implementation approach (if you have ideas)\n\n"
            "**For new language implementations:**\n"
            "- Language name and version\n"
            "- Your experience with the language\n"
            "- Timeline estimate\n\n"
            "This will help us triage and address your issue more effectively. Thank you!"
        )
    elif 'implementation' in full_text and not any(kw in full_text for kw in ['which', 'what', 'version', 'language']):
        analysis['needs_clarification'] = True
        analysis['clarification_comment'] = (
            "Thank you for your interest in contributing a new implementation! 🎉\n\n"
            "To help us track and support your work, could you please provide:\n\n"
            "1. **Language name and version** (e.g., Python 3.11, Rust 1.70)\n"
            "2. **Your timeline** (when do you plan to have it ready?)\n"
            "3. **Your experience level** with the language\n"
            "4. **Any questions** you have about the specification or process\n\n"
            "Please review the following resources:\n"
            "- [Chess Engine Specification](https://github.com/evaisse/the-great-analysis-challenge/blob/master/CHESS_ENGINE_SPECS.md)\n"
            "- [Implementation Guidelines](https://github.com/evaisse/the-great-analysis-challenge/blob/master/README_IMPLEMENTATION_GUIDELINES.md)\n"
            "- [Contributing Guide](https://github.com/evaisse/the-great-analysis-challenge/blob/master/CONTRIBUTING.md)\n\n"
            "Looking forward to your contribution!"
        )
    
    # Remove duplicate labels
    analysis['suggested_labels'] = list(set(analysis['suggested_labels']))
    
    return analysis


def create_labels_if_needed(repo, labels_to_create: List[str]):
    """Create standard labels if they don't exist."""
    label_colors = {
        'bug': 'd73a4a',
        'enhancement': 'a2eeef',
        'documentation': '0075ca',
        'performance': 'fbca04',
        'testing': '1d76db',
        'good first issue': '7057ff',
        'help wanted': '008672',
        'implementation': 'c5def5',
        'ci/cd': 'f9d0c4',
        'triage': 'ffffff',
        'needs clarification': 'ededed',
    }
    
    existing_labels = {label.name.lower(): label for label in repo.get_labels()}
    
    for label_name in labels_to_create:
        label_lower = label_name.lower()
        if label_lower not in existing_labels:
            try:
                color = label_colors.get(label_lower, 'ededed')
                description = f"Automatically added by issue triage workflow"
                repo.create_label(label_name, color, description)
                print(f"✓ Created label: {label_name}")
            except GithubException as e:
                if e.status != 422:  # 422 means label already exists
                    print(f"Warning: Could not create label '{label_name}': {e}")


def triage_issue(repo_name: str, issue_number: int) -> bool:
    """
    Main triage function.
    
    Returns True if successful, False otherwise.
    """
    # Get GitHub token
    github_token = os.environ.get('GITHUB_TOKEN')
    if not github_token:
        print("Error: GITHUB_TOKEN environment variable not set")
        return False
    
    # Initialize GitHub client
    try:
        g = Github(github_token)
        repo = g.get_repo(repo_name)
        issue = repo.get_issue(issue_number)
    except GithubException as e:
        print(f"Error: Could not access issue: {e}")
        return False
    
    print(f"Triaging issue #{issue_number}: {issue.title}")
    
    # Get current labels
    current_labels = [label.name for label in issue.labels]
    print(f"Current labels: {current_labels}")
    
    # Analyze issue content
    analysis = analyze_issue_content(
        issue.title,
        issue.body,
        current_labels
    )
    
    print(f"Analysis complete:")
    print(f"  Suggested labels: {analysis['suggested_labels']}")
    print(f"  Improved title: {analysis['improved_title']}")
    print(f"  Needs clarification: {analysis['needs_clarification']}")
    
    # Create labels if they don't exist
    all_labels = analysis['suggested_labels'].copy()
    if analysis['needs_clarification']:
        all_labels.append('needs clarification')
    
    create_labels_if_needed(repo, all_labels)
    
    # Apply labels (only add new ones, don't remove existing)
    labels_to_add = [label for label in analysis['suggested_labels'] if label not in current_labels]
    
    if labels_to_add:
        try:
            issue.add_to_labels(*labels_to_add)
            print(f"✓ Added labels: {labels_to_add}")
        except GithubException as e:
            print(f"Warning: Could not add labels: {e}")
    
    # Update title if improved
    if analysis['improved_title'] and analysis['improved_title'] != issue.title:
        try:
            issue.edit(title=analysis['improved_title'])
            print(f"✓ Updated title to: {analysis['improved_title']}")
        except GithubException as e:
            print(f"Warning: Could not update title: {e}")
    
    # Add clarification comment if needed
    if analysis['needs_clarification']:
        try:
            # Check if we already commented
            comments = list(issue.get_comments())
            already_commented = any(
                'could you please provide more details' in comment.body.lower() or
                'help us track and support your work' in comment.body.lower()
                for comment in comments
                if comment.user.login == 'github-actions[bot]'
            )
            
            if not already_commented:
                issue.create_comment(analysis['clarification_comment'])
                issue.add_to_labels('needs clarification')
                print("✓ Added clarification comment")
            else:
                print("ℹ Already commented on this issue")
        except GithubException as e:
            print(f"Warning: Could not add comment: {e}")
    
    print(f"✓ Triage complete for issue #{issue_number}")
    return True


def main():
    """Main entry point."""
    args = parse_args()
    
    success = triage_issue(args.repo, args.issue)
    
    if not success:
        sys.exit(1)
    
    print("\n✓ Issue triage completed successfully")


if __name__ == '__main__':
    main()
