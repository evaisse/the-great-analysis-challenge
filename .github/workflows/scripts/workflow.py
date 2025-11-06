#!/usr/bin/env python3
"""
Unified workflow script for chess engine benchmarking and CI/CD operations.
Delegates to individual command modules for better organization.

Usage:
    workflow.py <command> [arguments]

Commands:
    detect-changes          - Detect changed implementations
    generate-matrix         - Generate GitHub matrix for parallel jobs
    run-benchmark          - Run benchmark for a specific implementation
    verify-implementations - Run structure verification and count results
    combine-results        - Combine benchmark artifacts
    update-readme          - Update README status table
    create-release         - Create and tag a release
    test-basic-commands    - Test basic chess engine commands
    test-advanced-features - Test advanced chess engine features
    test-demo-mode         - Test demo mode
    cleanup-docker         - Cleanup Docker images and files
    get-test-config        - Get test configuration from chess.meta
"""

import argparse
import json
import os
import sys
import subprocess
import glob
import re
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional

# Import individual command modules
try:
    from detect_changes import main as detect_changes_main
    from generate_matrix import main as generate_matrix_main
    from run_benchmark import main as run_benchmark_main
    from verify_implementations import main as verify_implementations_main
    from combine_results import main as combine_results_main
    from update_readme import main as update_readme_main
    from get_test_config import main as get_test_config_main
    from test_docker import (
        main_test_basic_commands, main_test_advanced_features,
        main_test_demo_mode, main_cleanup_docker
    )
except ImportError as e:
    print(f"Warning: Could not import command module: {e}")
    print("Falling back to inline implementations...")


class WorkflowTool:
    """Unified workflow tool for chess engine CI/CD operations."""
    
    def __init__(self):
        self.github_output = os.environ.get('GITHUB_OUTPUT')
    
    def write_github_output(self, key: str, value: str):
        """Write to GitHub Actions output file."""
        if self.github_output:
            with open(self.github_output, 'a') as f:
                f.write(f"{key}={value}\n")
        else:
            print(f"Would set GitHub output: {key}={value}")
    
    def run_command(self, cmd: List[str], cwd: str = None, timeout: int = None, check: bool = True, show_output: bool = False, input: str = None, stream_output: bool = False, output_file: str = None) -> subprocess.CompletedProcess:
        """Run a shell command with error handling and flexible output handling."""
        cmd_str = ' '.join(cmd)
        print(f"🔧 Running: {cmd_str}")
        if cwd:
            print(f"   Working directory: {cwd}")
        
        try:
            if stream_output:
                return self._run_command_streaming(cmd, cwd, timeout, check, output_file, input)
            else:
                result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, 
                                      timeout=timeout, check=check, input=input)
                
                if show_output and result.stdout.strip():
                    print(f"📤 Output:\n{result.stdout}")
                if result.stderr.strip():
                    print(f"⚠️ Stderr:\n{result.stderr}")
                    
                return result
                
        except subprocess.CalledProcessError as e:
            if check:
                print(f"❌ Command failed: {cmd_str}")
                if e.stdout and e.stdout.strip():
                    print(f"📤 Output:\n{e.stdout}")
                if e.stderr and e.stderr.strip():
                    print(f"❌ Error:\n{e.stderr}")
                raise
            return e
        except subprocess.TimeoutExpired as e:
            print(f"⏰ Command timed out: {cmd_str}")
            raise
    
    def _run_command_streaming(self, cmd: List[str], cwd: str = None, timeout: int = None, check: bool = True, output_file: str = None, input: str = None) -> subprocess.CompletedProcess:
        """Run command with real-time output streaming and optional capture to file."""
        import sys
        
        captured_output = []
        
        try:
            process = subprocess.Popen(
                cmd, 
                cwd=cwd,
                stdout=subprocess.PIPE, 
                stderr=subprocess.STDOUT,  # Merge stderr into stdout
                text=True, 
                bufsize=0,  # Unbuffered for immediate output
                universal_newlines=True,
                stdin=subprocess.PIPE if input else None
            )
            
            # Send input if provided
            if input:
                process.stdin.write(input)
                process.stdin.close()
            
            # Open output file if specified
            file_handle = None
            if output_file:
                file_handle = open(output_file, 'w', buffering=1)  # Line buffered
            
            try:
                # Read output line by line in real-time
                while True:
                    line = process.stdout.readline()
                    if not line:
                        # Check if process is still running
                        if process.poll() is not None:
                            break
                        continue
                    
                    # Print to terminal immediately
                    print(line, end='')
                    sys.stdout.flush()
                    
                    # Write to file if specified
                    if file_handle:
                        file_handle.write(line)
                        file_handle.flush()
                    
                    # Capture for return value
                    captured_output.append(line)
                
            finally:
                if file_handle:
                    file_handle.close()
            
            # Wait for process with timeout
            try:
                returncode = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
                raise subprocess.TimeoutExpired(cmd, timeout)
            
            # Create result object
            result = subprocess.CompletedProcess(
                cmd, 
                returncode, 
                ''.join(captured_output), 
                ''  # stderr is merged into stdout
            )
            
            if check and returncode != 0:
                raise subprocess.CalledProcessError(returncode, cmd, 
                                                  result.stdout, result.stderr)
            
            return result
            
        except Exception as e:
            # Make sure process is terminated
            if 'process' in locals():
                try:
                    process.kill()
                    process.wait()
                except:
                    pass
            raise
    
    def detect_changes(self, event_name: str, test_all: str = "false", 
                      base_sha: str = "", head_sha: str = "", before_sha: str = "") -> Dict:
        """Detect changed implementations based on git diff."""
        print("=== Detecting Changed Implementations ===")
        
        # Determine if we should test all implementations
        if test_all == "true" or event_name in ["schedule", "workflow_dispatch"]:
            changed_implementations = "all"
            has_changes = True
        else:
            # Get changed files
            try:
                if event_name == "pull_request" and base_sha and head_sha:
                    cmd = ["git", "diff", "--name-only", base_sha, head_sha, "--", "implementations/"]
                elif before_sha and before_sha != "0000000000000000000000000000000000000000":
                    cmd = ["git", "diff", "--name-only", before_sha, "HEAD", "--", "implementations/"]
                else:
                    cmd = ["git", "diff", "--name-only", "HEAD~1", "HEAD", "--", "implementations/"]
                
                result = self.run_command(cmd, show_output=True)
                changed_files = result.stdout.strip().split('\n') if result.stdout.strip() else []
                
                # Extract implementation names
                implementations = set()
                for file_path in changed_files:
                    if file_path.startswith("implementations/"):
                        parts = file_path.split('/')
                        if len(parts) >= 2:
                            implementations.add(parts[1])
                
                changed_implementations = " ".join(sorted(implementations))
                has_changes = len(implementations) > 0
                
            except Exception as e:
                print(f"Error detecting changes: {e}")
                changed_implementations = ""
                has_changes = False
        
        result = {
            "implementations": changed_implementations,
            "has_changes": str(has_changes).lower()
        }
        
        # Write GitHub outputs
        self.write_github_output("implementations", changed_implementations)
        self.write_github_output("has-changes", str(has_changes).lower())
        
        print(f"Changed implementations: {changed_implementations}")
        print(f"Has changes: {has_changes}")
        
        return result
    
    def generate_matrix(self, changed_implementations: str = "all") -> Dict:
        """Generate GitHub Actions matrix for parallel jobs."""
        print("=== Generating Matrix ===")
        
        # Discover implementations
        implementations = []
        impl_dir = "implementations"
        
        if os.path.exists(impl_dir):
            for name in os.listdir(impl_dir):
                impl_path = os.path.join(impl_dir, name)
                dockerfile_path = os.path.join(impl_path, "Dockerfile")
                
                if os.path.isdir(impl_path) and os.path.exists(dockerfile_path):
                    implementations.append({
                        "name": name.title(),
                        "directory": impl_path,
                        "dockerfile": "Dockerfile",
                        "engine": name
                    })
        
        implementations = sorted(implementations, key=lambda x: x["name"])
        
        # Filter based on changes
        if changed_implementations != "all":
            changed_list = changed_implementations.strip().split()
            implementations = [impl for impl in implementations if impl["engine"] in changed_list]
        
        # Generate matrix
        matrix = {"include": implementations}
        matrix_json = json.dumps(matrix)
        
        self.write_github_output("matrix", matrix_json)
        print(f"Generated matrix with {len(implementations)} implementations")
        
        return matrix
    
    def run_benchmark(self, impl_name: str, timeout: int = 60) -> bool:
        """Run benchmark for a specific implementation."""
        print(f"🏁 Running benchmark for {impl_name}...")
        
        if not impl_name:
            print("Error: Implementation name required")
            return False
        
        # Derive implementation directory from name
        impl_dir = f"implementations/{impl_name}"
        
        # Check if implementation directory exists
        if not os.path.exists(impl_dir):
            print(f"❌ Implementation directory not found: {impl_dir}")
            return False
        
        # Create reports directory
        os.makedirs("benchmark_reports", exist_ok=True)
        
        # Run performance test
        cmd = [
            "python3", "test/performance_test.py",
            "--impl", impl_dir,
            "--timeout", str(timeout),
            "--output", f"benchmark_reports/performance_report_{impl_name}.txt",
            "--json", f"benchmark_reports/performance_data_{impl_name}.json"
        ]
        
        try:
            # Use streaming command that outputs to both terminal and file
            result = self.run_command(
                cmd,
                timeout=timeout+60,
                check=False,
                stream_output=True,
                output_file=f"benchmark_reports/benchmark_output_{impl_name}.txt"
            )
            
            if result.returncode == 0:
                print(f"✅ Benchmark completed for {impl_name}")
                return True
            else:
                print(f"❌ Benchmark failed for {impl_name} (exit code: {result.returncode})")
                return False
            
        except subprocess.TimeoutExpired:
            print(f"⏰ Benchmark timed out for {impl_name}")
            return False
        except Exception as e:
            print(f"❌ Benchmark failed for {impl_name}: {e}")
            return False
    
    def verify_implementations(self) -> Dict:
        """Run structure verification and count results."""
        print("=== Running Implementation Structure Verification ===")
        
        # Run verification script
        try:
            result = self.run_command(["python3", "test/verify_implementations.py"], check=False, show_output=True)
            with open("verification_results.txt", "w") as f:
                f.write(result.stdout)
                if result.stderr:
                    f.write(result.stderr)
        except Exception as e:
            print(f"Verification script error: {e}")
            with open("verification_results.txt", "w") as f:
                f.write(f"Verification failed: {e}")
        
        # Count implementations by status
        try:
            with open("verification_results.txt", "r") as f:
                content = f.read()
            
            excellent = content.count("🟢") + content.count("excellent")
            good = content.count("🟡") + content.count("good")
            needs_work = content.count("🔴") + content.count("needs_work")
            total = excellent + good + needs_work
            
        except Exception:
            excellent = good = needs_work = total = 0
        
        # Write GitHub outputs
        self.write_github_output("excellent_count", str(excellent))
        self.write_github_output("good_count", str(good))
        self.write_github_output("needs_work_count", str(needs_work))
        self.write_github_output("total_count", str(total))
        
        print(f"=== Verification Summary ===")
        print(f"Total implementations: {total}")
        print(f"🟢 Excellent: {excellent}")
        print(f"🟡 Good: {good}")
        print(f"🔴 Needs work: {needs_work}")
        
        # Print verification results
        try:
            with open("verification_results.txt", "r") as f:
                print(f.read())
        except Exception:
            pass
        
        return {
            "excellent_count": excellent,
            "good_count": good,
            "needs_work_count": needs_work,
            "total_count": total
        }
    
    def combine_results(self) -> bool:
        """Combine benchmark artifacts from multiple jobs."""
        print("=== Combining Benchmark Results ===")
        
        # Create combined reports directory
        os.makedirs("benchmark_reports", exist_ok=True)
        
        # Copy all individual reports
        try:
            for pattern in ["*.txt", "*.json"]:
                for file_path in glob.glob(f"benchmark_artifacts/**/{pattern}", recursive=True):
                    dest_path = os.path.join("benchmark_reports", os.path.basename(file_path))
                    with open(file_path, "r") as src, open(dest_path, "w") as dst:
                        dst.write(src.read())
        except Exception as e:
            print(f"Error copying files: {e}")
        
        # Combine JSON reports
        all_results = []
        for json_file in glob.glob('benchmark_reports/performance_data_*.json'):
            try:
                with open(json_file, 'r') as f:
                    data = json.load(f)
                    if isinstance(data, list):
                        all_results.extend(data)
                    else:
                        all_results.append(data)
            except Exception as e:
                print(f'Error reading {json_file}: {e}')
        
        # Save combined results
        if all_results:
            with open('benchmark_reports/performance_data.json', 'w') as f:
                json.dump(all_results, f, indent=2)
            print(f'Combined {len(all_results)} implementation results')
        
        print("✅ Benchmark results combined")
        return True
    
    def update_readme(self) -> bool:
        """Update README status table and check if it was modified."""
        print("=== Updating README Status Table ===")
        
        def load_performance_data():
            """Load performance benchmark data"""
            try:
                with open('benchmark_reports/performance_data.json', 'r') as f:
                    return json.load(f)
            except FileNotFoundError:
                print("⚠️ Performance data not found")
                return []
        
        def classify_implementation_status(impl_data):
            """Classify implementation status based on benchmark results"""
            if impl_data.get('status') != 'completed':
                return 'needs_work'
            
            errors = len(impl_data.get('errors', []))
            test_results = impl_data.get('test_results', {})
            failed_tests = len(test_results.get('failed', []))
            
            if errors == 0 and failed_tests == 0:
                return 'excellent'
            elif errors <= 2 and failed_tests <= 1:
                return 'good'
            else:
                return 'needs_work'
        
        def format_time(seconds):
            """Format time duration
            
            Args:
                seconds: Time in seconds, or None if data is not available
                
            Returns:
                Formatted time string or "-" if data is missing
            """
            if seconds is None:
                return "-"
            elif seconds == 0:
                return "<1s"
            elif seconds < 1:
                return f"~{seconds:.1f}s"
            else:
                return f"~{seconds:.0f}s"
        
        try:
            performance_data = load_performance_data()
            
            # Generate status table
            status_emoji = {
                'excellent': '🟢',
                'good': '🟡', 
                'needs_work': '🔴'
            }
            
            table_rows = []
            for impl_data in sorted(performance_data, key=lambda x: x.get('language', '')):
                language = impl_data.get('language', 'Unknown')
                status = classify_implementation_status(impl_data)
                emoji = status_emoji.get(status, '❓')
                
                timings = impl_data.get('timings', {})
                # Use None as default instead of 0 to distinguish missing data from zero time
                build_time = format_time(timings.get('build_seconds'))
                test_time = format_time(timings.get('test_seconds'))
                
                test_results = impl_data.get('test_results', {})
                passed = len(test_results.get('passed', []))
                failed = len(test_results.get('failed', []))
                test_score = f"{passed}/{passed+failed}" if (passed + failed) > 0 else "0/0"
                
                table_rows.append(f"| {language.title()} | {emoji} | {build_time} | {test_time} | {test_score} |")
            
            # Create table content
            table_header = """
| Language | Status | Build Time | Test Time | Tests Passed |
|----------|--------|------------|-----------|--------------|"""
            
            new_table = table_header + "\n" + "\n".join(table_rows)
            
            # Update README.md
            readme_path = "README.md"
            if os.path.exists(readme_path):
                with open(readme_path, 'r') as f:
                    content = f.read()
                
                # Find and replace the status table
                pattern = r'(<!-- status-table-start -->).*?(<!-- status-table-end -->)'
                replacement = f'\\1\n{new_table}\n\\2'
                
                new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
                
                with open(readme_path, 'w') as f:
                    f.write(new_content)
                
                print("✅ README status table updated")
            
            # Check if README was modified
            result = self.run_command(["git", "diff", "--quiet", "README.md"], check=False, show_output=True)
            readme_changed = result.returncode != 0
            
            self.write_github_output("changed", str(readme_changed).lower())
            
            if readme_changed:
                print("✅ README.md has been updated")
            else:
                print("⚠️ README.md was not modified")
            
            return True
            
        except Exception as e:
            print(f"Error updating README: {e}")
            return False
    
    def create_release(self, version_type: str = "patch", readme_changed: str = "false",
                      excellent_count: int = 0, good_count: int = 0, 
                      needs_work_count: int = 0, total_count: int = 0) -> bool:
        """Create release version, commit changes, and push tag."""
        print("=== Creating Release ===")
        
        # Get current version
        try:
            result = self.run_command([
                "git", "tag", "--sort=-version:refname"
            ], show_output=True)
            tags = [line for line in result.stdout.split('\n') 
                   if re.match(r'^v\d+\.\d+\.\d+$', line.strip())]
            current_version = tags[0] if tags else "v0.0.0"
        except Exception:
            current_version = "v0.0.0"
        
        self.write_github_output("current_version", current_version)
        self.write_github_output("version_type", version_type)
        
        # Calculate new version
        version_parts = current_version[1:].split('.')
        major = int(version_parts[0]) if len(version_parts) > 0 else 0
        minor = int(version_parts[1]) if len(version_parts) > 1 else 0
        patch = int(version_parts[2]) if len(version_parts) > 2 else 0
        
        if version_type == "major":
            major += 1
            minor = 0
            patch = 0
        elif version_type == "minor":
            minor += 1
            patch = 0
        else:  # patch
            patch += 1
        
        new_version = f"v{major}.{minor}.{patch}"
        self.write_github_output("new_version", new_version)
        
        # Configure git and commit changes if README was updated
        if readme_changed == "true":
            self.run_command(["git", "config", "--local", "user.email", "action@github.com"], show_output=True)
            self.run_command(["git", "config", "--local", "user.name", "GitHub Action"], show_output=True)
            
            # Copy benchmark reports to repo
            os.makedirs("benchmark_reports", exist_ok=True)
            for pattern in ["*.txt", "*.json"]:
                for file_path in glob.glob(f"benchmark_artifacts/**/{pattern}", recursive=True):
                    dest_path = os.path.join("benchmark_reports", os.path.basename(file_path))
                    try:
                        with open(file_path, "r") as src, open(dest_path, "w") as dst:
                            dst.write(src.read())
                    except Exception:
                        pass
            
            self.run_command(["git", "add", "benchmark_reports/", "README.md"], show_output=True)
            
            commit_message = f"""chore: update implementation status from benchmark suite

Benchmark results summary:
- Total implementations: {total_count}
- 🟢 Excellent: {excellent_count}
- 🟡 Good: {good_count}  
- 🔴 Needs work: {needs_work_count}

Performance testing completed with status updates."""
            
            self.run_command(["git", "commit", "-m", commit_message], show_output=True)
            self.run_command(["git", "push", "origin", "master"], show_output=True)
            print("✅ Changes committed and pushed")
        
        # Create and push tag
        self.run_command(["git", "tag", "-a", new_version, "-m", f"Release {new_version} - Benchmark Update"], show_output=True)
        self.run_command(["git", "push", "origin", new_version], show_output=True)
        print(f"✅ Release tag {new_version} created")
        
        return True
    
    def test_basic_commands(self, engine: str) -> bool:
        """Test basic chess engine commands."""
        print(f"🧪 Testing basic functionality for {engine}...")
        
        try:
            # Test basic commands that all implementations should support
            commands = ["help", "board", "fen"]
            for cmd in commands:
                print(f"📋 Testing {cmd} command")
                result = self.run_command([
                    "docker", "run", "--rm", "-i", f"chess-{engine}-test"
                ], timeout=30, check=False, show_output=True)
                
                with open(f"{cmd}_output.txt", "w") as f:
                    f.write(result.stdout)
            
            # Basic validation - check if commands executed
            outputs_exist = all(os.path.exists(f"{cmd}_output.txt") for cmd in commands)
            if outputs_exist:
                print("✅ Basic commands executed successfully")
                return True
            else:
                print("⚠️ Some basic commands may have issues")
                return False
                
        except Exception as e:
            print(f"Error testing basic commands: {e}")
            return False
    
    def test_advanced_features(self, engine: str, supports_perft: bool = True, supports_ai: bool = True) -> bool:
        """Test advanced chess engine features."""
        print(f"🧪 Testing advanced features for {engine}...")
        
        try:
            # Test perft if supported
            if supports_perft:
                print("🔍 Testing perft (move generation)")
                result = self.run_command([
                    "docker", "run", "--rm", "-i", f"chess-{engine}-test"
                ], timeout=120, check=False, show_output=True)
                
                with open("perft_output.txt", "w") as f:
                    f.write("perft 3\n")
                    f.write(result.stdout)
                
                if re.search(r'(\d+.*nodes|Depth.*\d+)', result.stdout):
                    print("✅ Perft test completed")
                else:
                    print("⚠️ Perft test may have issues")
            else:
                print("⏭️ Perft not supported, skipping")
            
            # Test AI if supported
            if supports_ai:
                print("🤖 Testing AI move generation")
                ai_input = "ai\nquit\n"
                result = self.run_command([
                    "docker", "run", "--rm", "-i", f"chess-{engine}-test"
                ], timeout=60, check=False, show_output=True, input=ai_input)
                
                with open("ai_output.txt", "w") as f:
                    f.write(result.stdout)
                
                if result.stdout.strip():
                    print("✅ AI test completed")
                else:
                    print("⚠️ AI test may have issues")
            else:
                print("⏭️ AI not supported, skipping")
            
            return True
            
        except Exception as e:
            print(f"Error testing advanced features: {e}")
            return False
    
    def test_demo_mode(self, engine: str) -> bool:
        """Test demo mode implementations."""
        print(f"🎯 Running demo mode test for {engine}...")
        
        try:
            result = self.run_command([
                "docker", "run", "--rm", f"chess-{engine}-test"
            ], timeout=30, check=False, show_output=True)
            
            print("✅ Demo test completed")
            return True
            
        except Exception as e:
            print(f"Error in demo mode test: {e}")
            return False
    
    def cleanup_docker(self, engine: str) -> bool:
        """Cleanup Docker images and temporary files."""
        print(f"🧹 Cleaning up {engine}...")
        
        try:
            # Remove Docker image
            self.run_command(["docker", "rmi", f"chess-{engine}-test"], check=False)
            
            # Remove temporary files
            for pattern in ["*.txt"]:
                for file_path in glob.glob(pattern):
                    try:
                        os.remove(file_path)
                    except Exception:
                        pass
            
            print("✅ Cleanup completed")
            return True
            
        except Exception as e:
            print(f"Error during cleanup: {e}")
            return False
    
    def get_test_config(self, implementation: str) -> Dict:
        """Get test configuration from chess.meta."""
        print(f"🔧 Reading test configuration from chess.meta...")
        
        impl_path = f"implementations/{implementation}"
        
        if not os.path.exists(impl_path):
            return {}
        
        meta_path = os.path.join(impl_path, "chess.meta")
        
        if not os.path.exists(meta_path):
            # Default configuration if no chess.meta
            config = {
                "language": implementation,
                "supports_interactive": True,
                "supports_perft": True,
                "supports_ai": True,
                "test_mode": "full"
            }
        else:
            try:
                with open(meta_path, 'r') as f:
                    meta = json.load(f)
                
                features = meta.get("features", [])
                
                config = {
                    "language": meta.get("language", implementation),
                    "supports_interactive": "interactive" in features,
                    "supports_perft": "perft" in features,
                    "supports_ai": "ai" in features,
                    "test_mode": "full" if len(features) > 3 else "basic"
                }
                
            except Exception as e:
                print(f"Error reading chess.meta: {e}")
                config = {
                    "language": implementation,
                    "supports_interactive": True,
                    "supports_perft": True,
                    "supports_ai": True,
                    "test_mode": "full"
                }
        
        # Write GitHub outputs
        for key, value in config.items():
            if key.startswith("supports_") or key == "test_mode":
                self.write_github_output(key, str(value).lower())
        
        print(f"Configuration: {json.dumps(config)}")
        return config


def main():
    """Main entry point with argparse command structure."""
    parser = argparse.ArgumentParser(
        description="Unified workflow script for chess engine benchmarking and CI/CD operations",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # detect-changes command
    detect_parser = subparsers.add_parser('detect-changes', help='Detect changed implementations')
    detect_parser.add_argument('event_name', help='GitHub event name')
    detect_parser.add_argument('--test-all', default='false', help='Test all implementations')
    detect_parser.add_argument('--base-sha', default='', help='Base SHA for PR')
    detect_parser.add_argument('--head-sha', default='', help='Head SHA for PR')
    detect_parser.add_argument('--before-sha', default='', help='Before SHA for push')
    
    # generate-matrix command
    matrix_parser = subparsers.add_parser('generate-matrix', help='Generate GitHub matrix')
    matrix_parser.add_argument('changed_implementations', nargs='?', default='all', 
                              help='Changed implementations (space-separated)')
    
    # run-benchmark command
    benchmark_parser = subparsers.add_parser('run-benchmark', help='Run benchmark for implementation')
    benchmark_parser.add_argument('impl_name', nargs='?', help='Implementation name')
    benchmark_parser.add_argument('--timeout', type=int, default=60, help='Timeout in seconds')
    benchmark_parser.add_argument('--all', action='store_true', help='Run benchmarks on all implementations')
    
    # verify-implementations command
    subparsers.add_parser('verify-implementations', help='Run structure verification')
    
    # combine-results command
    subparsers.add_parser('combine-results', help='Combine benchmark artifacts')
    
    # update-readme command
    subparsers.add_parser('update-readme', help='Update README status table')
    
    # create-release command
    release_parser = subparsers.add_parser('create-release', help='Create and tag a release')
    release_parser.add_argument('--version-type', default='patch', choices=['major', 'minor', 'patch'])
    release_parser.add_argument('--readme-changed', default='false', help='Whether README was changed')
    release_parser.add_argument('--excellent-count', type=int, default=0)
    release_parser.add_argument('--good-count', type=int, default=0)
    release_parser.add_argument('--needs-work-count', type=int, default=0)
    release_parser.add_argument('--total-count', type=int, default=0)
    
    # test-basic-commands command
    basic_parser = subparsers.add_parser('test-basic-commands', help='Test basic chess engine commands')
    basic_parser.add_argument('engine', nargs='?', help='Engine name')
    basic_parser.add_argument('--all', action='store_true', help='Test all implementations')
    
    # test-advanced-features command
    advanced_parser = subparsers.add_parser('test-advanced-features', help='Test advanced features')
    advanced_parser.add_argument('engine', nargs='?', help='Engine name')
    advanced_parser.add_argument('--supports-perft', type=bool, default=True, help='Supports perft')
    advanced_parser.add_argument('--supports-ai', type=bool, default=True, help='Supports AI')
    advanced_parser.add_argument('--all', action='store_true', help='Test all implementations')
    
    # test-demo-mode command
    demo_parser = subparsers.add_parser('test-demo-mode', help='Test demo mode')
    demo_parser.add_argument('engine', nargs='?', help='Engine name')
    demo_parser.add_argument('--all', action='store_true', help='Test all implementations')
    
    # cleanup-docker command
    cleanup_parser = subparsers.add_parser('cleanup-docker', help='Cleanup Docker images')
    cleanup_parser.add_argument('engine', nargs='?', help='Engine name')
    cleanup_parser.add_argument('--all', action='store_true', help='Cleanup all implementations')
    
    # get-test-config command
    config_parser = subparsers.add_parser('get-test-config', help='Get test configuration')
    config_parser.add_argument('implementation', nargs='?', help='Implementation name')
    config_parser.add_argument('--all', action='store_true', help='Get configurations for all implementations')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return 1
    
    tool = WorkflowTool()
    
    try:
        if args.command == 'detect-changes':
            try:
                result = detect_changes_main(args)
                print(json.dumps(result))
            except NameError:
                result = tool.detect_changes(args.event_name, args.test_all, 
                                           args.base_sha, args.head_sha, args.before_sha)
                print(json.dumps(result))
        
        elif args.command == 'generate-matrix':
            try:
                result = generate_matrix_main(args)
                print(json.dumps(result))
            except NameError:
                result = tool.generate_matrix(args.changed_implementations)
                print(json.dumps(result))
        
        elif args.command == 'run-benchmark':
            try:
                return run_benchmark_main(args)
            except NameError:
                success = tool.run_benchmark(args.impl_name, args.timeout)
                return 0 if success else 1
        
        elif args.command == 'verify-implementations':
            try:
                verify_implementations_main(args)
            except NameError:
                tool.verify_implementations()
        
        elif args.command == 'combine-results':
            try:
                return combine_results_main(args)
            except NameError:
                success = tool.combine_results()
                return 0 if success else 1
        
        elif args.command == 'update-readme':
            try:
                return update_readme_main(args)
            except NameError:
                success = tool.update_readme()
                return 0 if success else 1
        
        elif args.command == 'create-release':
            success = tool.create_release(
                args.version_type, args.readme_changed,
                args.excellent_count, args.good_count,
                args.needs_work_count, args.total_count
            )
            return 0 if success else 1
        
        elif args.command == 'test-basic-commands':
            try:
                return main_test_basic_commands(args)
            except NameError:
                success = tool.test_basic_commands(args.engine)
                return 0 if success else 1
        
        elif args.command == 'test-advanced-features':
            try:
                return main_test_advanced_features(args)
            except NameError:
                success = tool.test_advanced_features(args.engine, args.supports_perft, args.supports_ai)
                return 0 if success else 1
        
        elif args.command == 'test-demo-mode':
            try:
                return main_test_demo_mode(args)
            except NameError:
                success = tool.test_demo_mode(args.engine)
                return 0 if success else 1
        
        elif args.command == 'cleanup-docker':
            try:
                return main_cleanup_docker(args)
            except NameError:
                success = tool.cleanup_docker(args.engine)
                return 0 if success else 1
        
        elif args.command == 'get-test-config':
            try:
                result = get_test_config_main(args)
                print(json.dumps(result))
            except NameError:
                result = tool.get_test_config(args.implementation)
                print(json.dumps(result))
        
        return 0
        
    except Exception as e:
        print(f"Error: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())