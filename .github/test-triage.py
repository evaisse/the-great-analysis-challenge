#!/usr/bin/env python3
"""
Test the issue triage logic without requiring GitHub API access.
"""

import sys
import os

# Add scripts directory to path
script_dir = os.path.join(os.path.dirname(__file__), 'workflows', 'scripts')
sys.path.insert(0, script_dir)

from triage_issue import analyze_issue_content


def test_bug_detection():
    """Test that bug-related issues are labeled correctly."""
    title = "Error when moving pawn"
    body = "I get a crash when I try to move a pawn in the Python implementation."
    
    result = analyze_issue_content(title, body, [])
    
    assert 'bug' in result['suggested_labels'], "Should detect bug label"
    print("✓ Bug detection test passed")


def test_enhancement_detection():
    """Test that enhancement requests are labeled correctly."""
    title = "Add support for chess960"
    body = "It would be great to add Fischer Random Chess support to all implementations."
    
    result = analyze_issue_content(title, body, [])
    
    assert 'enhancement' in result['suggested_labels'], "Should detect enhancement label"
    print("✓ Enhancement detection test passed")


def test_documentation_detection():
    """Test that documentation issues are labeled correctly."""
    title = "Update README with better examples"
    body = "The current README could use more detailed examples of how to use the chess engines."
    
    result = analyze_issue_content(title, body, [])
    
    assert 'documentation' in result['suggested_labels'], "Should detect documentation label"
    print("✓ Documentation detection test passed")


def test_implementation_detection():
    """Test that new implementation requests are labeled correctly."""
    title = "Add Elixir implementation"
    body = "I'd like to add a new chess engine implementation in Elixir."
    
    result = analyze_issue_content(title, body, [])
    
    assert 'implementation' in result['suggested_labels'], "Should detect implementation label"
    print("✓ Implementation detection test passed")


def test_clarification_needed_short():
    """Test that short issues trigger clarification request."""
    title = "Bug"
    body = "It doesn't work"
    
    result = analyze_issue_content(title, body, [])
    
    assert result['needs_clarification'], "Should request clarification for vague issue"
    assert result['clarification_comment'] is not None, "Should have clarification comment"
    print("✓ Clarification needed (short) test passed")


def test_clarification_needed_empty():
    """Test that empty body triggers clarification request."""
    title = "Feature request"
    body = ""
    
    result = analyze_issue_content(title, body, [])
    
    assert result['needs_clarification'], "Should request clarification for empty body"
    print("✓ Clarification needed (empty) test passed")


def test_title_improvement_lowercase():
    """Test that lowercase titles are improved."""
    title = "fix the bug in python"
    body = "There is a bug in the Python implementation that needs to be fixed."
    
    result = analyze_issue_content(title, body, [])
    
    assert result['improved_title'] is not None, "Should improve lowercase title"
    assert result['improved_title'][0].isupper(), "Improved title should start with capital"
    print("✓ Title improvement (lowercase) test passed")


def test_title_improvement_vague():
    """Test that vague titles are flagged."""
    title = "Bug"
    body = "There is an error when trying to move pieces in the game."
    
    result = analyze_issue_content(title, body, [])
    
    assert result['improved_title'] is not None, "Should flag vague title"
    assert '[Needs Detail]' in result['improved_title'], "Should add needs detail marker"
    print("✓ Title improvement (vague) test passed")


def test_multiple_labels():
    """Test that multiple labels can be detected."""
    title = "Performance issue in Python implementation"
    body = "The Python chess engine is running very slowly. We should optimize the move generation algorithm."
    
    result = analyze_issue_content(title, body, [])
    
    assert 'performance' in result['suggested_labels'], "Should detect performance label"
    assert 'implementation' in result['suggested_labels'], "Should detect implementation label"
    print("✓ Multiple labels test passed")


def test_workflow_detection():
    """Test that CI/CD workflow issues are labeled correctly."""
    title = "Create a issue triage workflow"
    body = "Please create a copilot assisted issue triage workflow."
    
    result = analyze_issue_content(title, body, [])
    
    assert 'ci/cd' in result['suggested_labels'], "Should detect ci/cd label"
    assert 'triage' in result['suggested_labels'], "Should detect triage label"
    print("✓ Workflow detection test passed")


def run_all_tests():
    """Run all tests."""
    print("\nRunning issue triage logic tests...\n")
    
    tests = [
        test_bug_detection,
        test_enhancement_detection,
        test_documentation_detection,
        test_implementation_detection,
        test_clarification_needed_short,
        test_clarification_needed_empty,
        test_title_improvement_lowercase,
        test_title_improvement_vague,
        test_multiple_labels,
        test_workflow_detection,
    ]
    
    failed = []
    for test in tests:
        try:
            test()
        except AssertionError as e:
            print(f"✗ {test.__name__} failed: {e}")
            failed.append(test.__name__)
        except Exception as e:
            print(f"✗ {test.__name__} error: {e}")
            failed.append(test.__name__)
    
    print(f"\n{'='*60}")
    if failed:
        print(f"❌ {len(failed)} test(s) failed: {', '.join(failed)}")
        return False
    else:
        print(f"✅ All {len(tests)} tests passed!")
        return True


if __name__ == '__main__':
    success = run_all_tests()
    sys.exit(0 if success else 1)
