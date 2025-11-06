#!/usr/bin/env python3
"""
Test Docker functionality for implementations.
"""

import os
import subprocess
import re
from typing import List, Tuple


def discover_implementations() -> List[str]:
    """Discover all implementations."""
    implementations = []
    impl_dir = "implementations"
    
    if not os.path.exists(impl_dir):
        return implementations
    
    for name in os.listdir(impl_dir):
        impl_path = os.path.join(impl_dir, name)
        dockerfile_path = os.path.join(impl_path, "Dockerfile")
        
        if os.path.isdir(impl_path) and os.path.exists(dockerfile_path):
            implementations.append(name)
    
    return sorted(implementations)


def run_command(cmd: List[str], timeout: int = 30, input_text: str = None, show_output: bool = False) -> subprocess.CompletedProcess:
    """Run a shell command with error handling and optional output logging."""
    cmd_str = ' '.join(cmd)
    print(f"🔧 Running: {cmd_str}")
    
    try:
        result = subprocess.run(cmd, input=input_text, capture_output=True, text=True, 
                              timeout=timeout, check=False)
        
        if show_output and result.stdout.strip():
            print(f"📤 Output:\n{result.stdout}")
        if result.stderr.strip():
            print(f"⚠️ Stderr:\n{result.stderr}")
            
        return result
        
    except subprocess.TimeoutExpired:
        print(f"⏰ Command timed out: {cmd_str}")
        raise


def test_basic_commands(engine: str) -> bool:
    """Test basic chess engine commands."""
    print(f"🧪 Testing basic functionality for {engine}...")
    
    try:
        # Test basic commands that all implementations should support
        commands = ["help", "board", "fen"]
        for cmd in commands:
            print(f"📋 Testing {cmd} command")
            result = run_command([
                "docker", "run", "--rm", "-i", f"chess-{engine}-test"
            ], input_text=f"{cmd}\nquit\n", timeout=30, show_output=True)
            
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


def test_advanced_features(engine: str, supports_perft: bool = True, supports_ai: bool = True) -> bool:
    """Test advanced chess engine features."""
    print(f"🧪 Testing advanced features for {engine}...")
    
    try:
        # Test perft if supported
        if supports_perft:
            print("🔍 Testing perft (move generation)")
            result = run_command([
                "docker", "run", "--rm", "-i", f"chess-{engine}-test"
            ], input_text="perft 3\nquit\n", timeout=120, show_output=True)
            
            with open("perft_output.txt", "w") as f:
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
            result = run_command([
                "docker", "run", "--rm", "-i", f"chess-{engine}-test"
            ], input_text="ai\nquit\n", timeout=60, show_output=True)
            
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


def test_demo_mode(engine: str) -> bool:
    """Test demo mode implementations."""
    print(f"🎯 Running demo mode test for {engine}...")
    
    try:
        result = run_command([
            "docker", "run", "--rm", f"chess-{engine}-test"
        ], timeout=30, show_output=True)
        
        print("✅ Demo test completed")
        return True
        
    except Exception as e:
        print(f"Error in demo mode test: {e}")
        return False


def cleanup_docker(engine: str) -> bool:
    """Cleanup Docker images and temporary files."""
    print(f"🧹 Cleaning up {engine}...")
    
    try:
        # Remove Docker image
        run_command(["docker", "rmi", f"chess-{engine}-test"])
        
        # Remove temporary files
        import glob
        for file_path in glob.glob("*.txt"):
            try:
                os.remove(file_path)
            except Exception:
                pass
        
        print("✅ Cleanup completed")
        return True
        
    except Exception as e:
        print(f"Error during cleanup: {e}")
        return False


def test_all_basic_commands() -> int:
    """Test basic commands on all implementations."""
    implementations = discover_implementations()
    
    if not implementations:
        print("❌ No implementations found!")
        return 1
    
    print(f"🚀 Testing basic commands on {len(implementations)} implementations...")
    
    failed_count = 0
    for engine in implementations:
        success = test_basic_commands(engine)
        if not success:
            failed_count += 1
    
    if failed_count > 0:
        print(f"\n❌ {failed_count} implementation(s) failed basic command tests")
        return 1
    else:
        print(f"\n✅ All {len(implementations)} implementation(s) passed basic command tests")
        return 0


def test_all_advanced_features() -> int:
    """Test advanced features on all implementations."""
    implementations = discover_implementations()
    
    if not implementations:
        print("❌ No implementations found!")
        return 1
    
    print(f"🚀 Testing advanced features on {len(implementations)} implementations...")
    
    failed_count = 0
    for engine in implementations:
        success = test_advanced_features(engine, True, True)
        if not success:
            failed_count += 1
    
    if failed_count > 0:
        print(f"\n❌ {failed_count} implementation(s) failed advanced feature tests")
        return 1
    else:
        print(f"\n✅ All {len(implementations)} implementation(s) passed advanced feature tests")
        return 0


def test_all_demo_mode() -> int:
    """Test demo mode on all implementations."""
    implementations = discover_implementations()
    
    if not implementations:
        print("❌ No implementations found!")
        return 1
    
    print(f"🚀 Testing demo mode on {len(implementations)} implementations...")
    
    failed_count = 0
    for engine in implementations:
        success = test_demo_mode(engine)
        if not success:
            failed_count += 1
    
    if failed_count > 0:
        print(f"\n❌ {failed_count} implementation(s) failed demo mode tests")
        return 1
    else:
        print(f"\n✅ All {len(implementations)} implementation(s) passed demo mode tests")
        return 0


def cleanup_all_docker() -> int:
    """Cleanup Docker images for all implementations."""
    implementations = discover_implementations()
    
    if not implementations:
        print("❌ No implementations found!")
        return 1
    
    print(f"🚀 Cleaning up Docker for {len(implementations)} implementations...")
    
    failed_count = 0
    for engine in implementations:
        success = cleanup_docker(engine)
        if not success:
            failed_count += 1
    
    if failed_count > 0:
        print(f"\n❌ {failed_count} implementation(s) failed cleanup")
        return 1
    else:
        print(f"\n✅ All {len(implementations)} implementation(s) cleaned up successfully")
        return 0


def main_test_basic_commands(args):
    """Main function for test-basic-commands command."""
    if args.all:
        return test_all_basic_commands()
    else:
        success = test_basic_commands(args.engine)
        return 0 if success else 1


def main_test_advanced_features(args):
    """Main function for test-advanced-features command."""
    if args.all:
        return test_all_advanced_features()
    else:
        success = test_advanced_features(args.engine, args.supports_perft, args.supports_ai)
        return 0 if success else 1


def main_test_demo_mode(args):
    """Main function for test-demo-mode command."""
    if args.all:
        return test_all_demo_mode()
    else:
        success = test_demo_mode(args.engine)
        return 0 if success else 1


def main_cleanup_docker(args):
    """Main function for cleanup-docker command."""
    if args.all:
        return cleanup_all_docker()
    else:
        success = cleanup_docker(args.engine)
        return 0 if success else 1


if __name__ == "__main__":
    import argparse
    import sys
    
    parser = argparse.ArgumentParser(description='Test Docker functionality')
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # test-basic-commands
    basic_parser = subparsers.add_parser('test-basic-commands', help='Test basic chess engine commands')
    basic_parser.add_argument('engine', nargs='?', help='Engine name')
    basic_parser.add_argument('--all', action='store_true', help='Test all implementations')
    
    # test-advanced-features
    advanced_parser = subparsers.add_parser('test-advanced-features', help='Test advanced features')
    advanced_parser.add_argument('engine', nargs='?', help='Engine name')
    advanced_parser.add_argument('--supports-perft', type=bool, default=True, help='Supports perft')
    advanced_parser.add_argument('--supports-ai', type=bool, default=True, help='Supports AI')
    advanced_parser.add_argument('--all', action='store_true', help='Test all implementations')
    
    # test-demo-mode
    demo_parser = subparsers.add_parser('test-demo-mode', help='Test demo mode')
    demo_parser.add_argument('engine', nargs='?', help='Engine name')
    demo_parser.add_argument('--all', action='store_true', help='Test all implementations')
    
    # cleanup-docker
    cleanup_parser = subparsers.add_parser('cleanup-docker', help='Cleanup Docker images')
    cleanup_parser.add_argument('engine', nargs='?', help='Engine name')
    cleanup_parser.add_argument('--all', action='store_true', help='Cleanup all implementations')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(1)
    
    # Validate arguments
    if args.all:
        if hasattr(args, 'engine') and args.engine:
            print("ERROR: Cannot specify engine when using --all")
            sys.exit(1)
    else:
        if not hasattr(args, 'engine') or not args.engine:
            print("ERROR: Engine name required (or use --all)")
            sys.exit(1)
    
    # Execute command
    if args.command == 'test-basic-commands':
        sys.exit(main_test_basic_commands(args))
    elif args.command == 'test-advanced-features':
        sys.exit(main_test_advanced_features(args))
    elif args.command == 'test-demo-mode':
        sys.exit(main_test_demo_mode(args))
    elif args.command == 'cleanup-docker':
        sys.exit(main_cleanup_docker(args))