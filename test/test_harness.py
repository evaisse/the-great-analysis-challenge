#!/usr/bin/env python3
"""
Chess Engine Test Harness
Tests multiple chess engine implementations against the specification
"""

import subprocess
import json
import time
import sys
import os
from pathlib import Path
from typing import Dict, List, Tuple, Optional
import argparse

class ChessEngineTester:
    def __init__(self, implementation_path: str, metadata: Dict):
        self.path = implementation_path
        self.metadata = metadata
        self.process = None
        self.results = {
            "passed": [],
            "failed": [],
            "performance": {},
            "errors": []
        }
        
    def start(self):
        """Start the chess engine process"""
        run_command = self.metadata.get("run", "").split()
        if not run_command:
            raise ValueError(f"No run command specified for {self.path}")
            
        try:
            self.process = subprocess.Popen(
                run_command,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=0,
                cwd=os.path.dirname(self.path)
            )
        except Exception as e:
            self.results["errors"].append(f"Failed to start: {e}")
            return False
        return True
    
    def send_command(self, command: str, timeout: float = 5.0) -> str:
        """Send command and get response"""
        if not self.process:
            return ""
            
        try:
            self.process.stdin.write(command + "\n")
            self.process.stdin.flush()
            
            start_time = time.time()
            output_lines = []
            
            while time.time() - start_time < timeout:
                if self.process.poll() is not None:
                    break
                    
                line = self.process.stdout.readline()
                if line:
                    output_lines.append(line.strip())
                    
                if any(keyword in line for keyword in ["OK:", "ERROR:", "CHECKMATE:", "STALEMATE:", "FEN:", "AI:"]):
                    break
                    
            return "\n".join(output_lines)
            
        except Exception as e:
            self.results["errors"].append(f"Command error: {e}")
            return ""
    
    def stop(self):
        """Stop the chess engine process"""
        if self.process:
            self.send_command("quit", timeout=1.0)
            time.sleep(0.5)
            if self.process.poll() is None:
                self.process.terminate()
            self.process = None

class TestSuite:
    def __init__(self):
        self.tests = []
        self.load_tests()
        
    def load_tests(self):
        """Load all test cases"""
        
        # Test 1: Basic Movement
        self.tests.append({
            "name": "Basic Movement",
            "commands": [
                "new",
                "move e2e4",
                "move e7e5",
                "move g1f3",
                "move b8c6",
                "export"
            ],
            "validate": lambda output: "r1bqkb" in output and "4p3/4P3" in output,
            "timeout": 2.0
        })
        
        # Test 2: Castling
        self.tests.append({
            "name": "Castling",
            "commands": [
                "fen r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1",
                "move e1g1",
                "export"
            ],
            "validate": lambda output: "R4RK1" in output or "5RK1" in output,
            "timeout": 2.0
        })
        
        # Test 3: En Passant
        self.tests.append({
            "name": "En Passant",
            "commands": [
                "fen rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 3",
                "move e5f6",
                "export"
            ],
            "validate": lambda output: "5P2" in output,
            "timeout": 2.0
        })
        
        # Test 4: Checkmate Detection
        self.tests.append({
            "name": "Checkmate Detection",
            "commands": [
                "new",
                "move f2f3",
                "move e7e5", 
                "move g2g4",
                "move d8h4"
            ],
            "validate": lambda output: "CHECKMATE" in output.upper(),
            "timeout": 2.0
        })
        
        # Test 5: AI Move
        self.tests.append({
            "name": "AI Move Generation",
            "commands": [
                "new",
                "ai 3"
            ],
            "validate": lambda output: "AI:" in output and "depth" in output.lower(),
            "timeout": 10.0
        })
        
        # Test 6: Invalid Move Handling
        self.tests.append({
            "name": "Invalid Move Handling",
            "commands": [
                "new",
                "move e2e5"
            ],
            "validate": lambda output: "ERROR" in output.upper(),
            "timeout": 2.0
        })
        
        # Test 7: Promotion
        self.tests.append({
            "name": "Pawn Promotion",
            "commands": [
                "fen 8/P7/8/8/8/8/8/8 w - - 0 1",
                "move a7a8",
                "export"
            ],
            "validate": lambda output: "Q7" in output or "Q" in output,
            "timeout": 2.0
        })
        
        # Test 8: Perft (if supported)
        self.tests.append({
            "name": "Perft Accuracy",
            "commands": [
                "new",
                "perft 3"
            ],
            "validate": lambda output: "8902" in output,
            "timeout": 5.0,
            "optional": True
        })

    def run_test(self, tester: ChessEngineTester, test: Dict) -> bool:
        """Run a single test case"""
        try:
            all_output = []
            start_time = time.time()
            
            for command in test["commands"]:
                output = tester.send_command(command, test.get("timeout", 5.0))
                all_output.append(output)
                
            elapsed = time.time() - start_time
            full_output = "\n".join(all_output)
            
            if test["validate"](full_output):
                tester.results["passed"].append(test["name"])
                tester.results["performance"][test["name"]] = elapsed
                return True
            else:
                tester.results["failed"].append({
                    "test": test["name"],
                    "output": full_output[:500]
                })
                return False
                
        except Exception as e:
            tester.results["failed"].append({
                "test": test["name"],
                "error": str(e)
            })
            return False

def find_implementations(base_dir: str) -> List[Tuple[str, Dict]]:
    """Find all chess implementations with metadata"""
    implementations = []
    
    for meta_file in Path(base_dir).rglob("chess.meta"):
        try:
            with open(meta_file, 'r') as f:
                metadata = json.load(f)
                impl_dir = meta_file.parent
                implementations.append((str(impl_dir), metadata))
        except Exception as e:
            print(f"Error loading {meta_file}: {e}")
            
    return implementations

def run_performance_tests(tester: ChessEngineTester) -> Dict:
    """Run performance benchmarks"""
    perf_results = {}
    
    # Test move generation speed
    tester.send_command("new")
    start = time.time()
    for _ in range(10):
        tester.send_command("move e2e4")
        tester.send_command("undo")
    perf_results["move_speed"] = (time.time() - start) / 10
    
    # Test AI at different depths
    for depth in [1, 3, 5]:
        if depth <= tester.metadata.get("max_ai_depth", 5):
            tester.send_command("new")
            start = time.time()
            output = tester.send_command(f"ai {depth}", timeout=30)
            if "AI:" in output:
                perf_results[f"ai_depth_{depth}"] = time.time() - start
    
    return perf_results

def generate_report(results: Dict[str, Dict]) -> str:
    """Generate test report"""
    report = []
    report.append("=" * 80)
    report.append("CHESS ENGINE TEST HARNESS REPORT")
    report.append("=" * 80)
    report.append("")
    
    # Summary table
    report.append("SUMMARY")
    report.append("-" * 40)
    report.append(f"{'Language':<15} {'Passed':<10} {'Failed':<10} {'Errors':<10}")
    report.append("-" * 40)
    
    for impl, data in results.items():
        lang = data.get("metadata", {}).get("language", "Unknown")
        passed = len(data["results"]["passed"])
        failed = len(data["results"]["failed"])
        errors = len(data["results"]["errors"])
        report.append(f"{lang:<15} {passed:<10} {failed:<10} {errors:<10}")
    
    report.append("")
    
    # Detailed results
    for impl, data in results.items():
        report.append(f"\n{'=' * 40}")
        report.append(f"Implementation: {impl}")
        report.append(f"Language: {data.get('metadata', {}).get('language', 'Unknown')}")
        report.append(f"{'=' * 40}")
        
        if data["results"]["passed"]:
            report.append("\nPASSED TESTS:")
            for test in data["results"]["passed"]:
                time_taken = data["results"]["performance"].get(test, 0)
                report.append(f"  ✓ {test} ({time_taken:.2f}s)")
        
        if data["results"]["failed"]:
            report.append("\nFAILED TESTS:")
            for failure in data["results"]["failed"]:
                report.append(f"  ✗ {failure['test']}")
                if "error" in failure:
                    report.append(f"    Error: {failure['error']}")
                elif "output" in failure:
                    report.append(f"    Output: {failure['output'][:100]}...")
        
        if data["results"]["errors"]:
            report.append("\nERRORS:")
            for error in data["results"]["errors"]:
                report.append(f"  ! {error}")
        
        if "performance" in data:
            report.append("\nPERFORMANCE:")
            for metric, value in data["performance"].items():
                if metric.startswith("ai_depth"):
                    report.append(f"  {metric}: {value:.2f}s")
                elif metric == "move_speed":
                    report.append(f"  Average move time: {value*1000:.1f}ms")
    
    report.append("\n" + "=" * 80)
    return "\n".join(report)

def main():
    parser = argparse.ArgumentParser(
        description="Chess Engine Protocol Compliance Testing",
        epilog="""
Examples:
  python3 test_harness.py
    Test all implementations in implementations/ directory
    
  python3 test_harness.py --impl implementations/python
    Test only the Python implementation
    
  python3 test_harness.py --test "Basic Movement"
    Run only the Basic Movement test on all implementations
    
  python3 test_harness.py --performance --output report.txt
    Run performance tests and save report to file

Test Cases:
  1. Basic Movement      - Standard piece moves (e2e4, e7e5, etc.)
  2. Castling           - King and rook castling moves  
  3. En Passant         - Pawn en passant capture
  4. Checkmate Detection - Fool's mate recognition
  5. AI Move Generation - AI depth 3 move calculation
  6. Invalid Move Handling - Error handling for illegal moves
  7. Pawn Promotion     - Promotion to queen
  8. Perft Accuracy     - Move generation validation (optional)

Performance Tests:
  - Move generation speed (average time per move)
  - AI thinking time at depths 1, 3, and 5
  - Memory usage during gameplay

Requirements:
  - Each implementation must have chess.meta file
  - Build command specified in chess.meta (if needed)
  - Run command specified in chess.meta
        """,
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument(
        "--dir", 
        default="implementations", 
        metavar="DIR",
        help="Directory containing implementations (default: implementations)"
    )
    
    parser.add_argument(
        "--impl", 
        metavar="PATH",
        help="Test specific implementation directory"
    )
    
    parser.add_argument(
        "--test", 
        metavar="NAME",
        help="Run specific test case (e.g., 'Basic Movement', 'Castling')"
    )
    
    parser.add_argument(
        "--performance", 
        action="store_true", 
        help="Run additional performance benchmarks"
    )
    
    parser.add_argument(
        "--output", 
        metavar="FILE",
        help="Save report to file"
    )
    
    args = parser.parse_args()
    
    # Find implementations
    if args.impl:
        meta_path = os.path.join(args.impl, "chess.meta")
        if os.path.exists(meta_path):
            with open(meta_path, 'r') as f:
                implementations = [(args.impl, json.load(f))]
        else:
            print(f"No chess.meta found in {args.impl}")
            return 1
    else:
        implementations = find_implementations(args.dir)
    
    if not implementations:
        print(f"No implementations found in {args.dir}")
        return 1
    
    print(f"Found {len(implementations)} implementation(s)")
    
    # Test each implementation
    suite = TestSuite()
    all_results = {}
    
    for impl_path, metadata in implementations:
        print(f"\nTesting {metadata.get('language', 'Unknown')} implementation at {impl_path}")
        print("-" * 40)
        
        tester = ChessEngineTester(impl_path, metadata)
        
        # Build if necessary
        if "build" in metadata:
            print(f"Building: {metadata['build']}")
            subprocess.run(metadata["build"].split(), cwd=impl_path, check=True)
        
        # Start engine
        if not tester.start():
            print(f"Failed to start implementation at {impl_path}")
            all_results[impl_path] = {
                "metadata": metadata,
                "results": tester.results
            }
            continue
        
        # Run tests
        if args.test:
            # Run specific test
            test = next((t for t in suite.tests if t["name"] == args.test), None)
            if test:
                print(f"Running test: {test['name']}")
                success = suite.run_test(tester, test)
                print(f"  {'✓ PASSED' if success else '✗ FAILED'}")
        else:
            # Run all tests
            for test in suite.tests:
                if test.get("optional") and test["name"] not in metadata.get("features", []):
                    continue
                    
                print(f"Running test: {test['name']}", end="")
                success = suite.run_test(tester, test)
                print(f" {'✓' if success else '✗'}")
        
        # Run performance tests
        if args.performance:
            print("\nRunning performance tests...")
            perf_results = run_performance_tests(tester)
            all_results[impl_path] = {
                "metadata": metadata,
                "results": tester.results,
                "performance": perf_results
            }
        else:
            all_results[impl_path] = {
                "metadata": metadata,
                "results": tester.results
            }
        
        # Stop engine
        tester.stop()
    
    # Generate report
    report = generate_report(all_results)
    print("\n" + report)
    
    if args.output:
        with open(args.output, 'w') as f:
            f.write(report)
        print(f"\nReport saved to {args.output}")
    
    # Return exit code based on results
    total_failed = sum(len(r["results"]["failed"]) for r in all_results.values())
    return 0 if total_failed == 0 else 1

if __name__ == "__main__":
    sys.exit(main())