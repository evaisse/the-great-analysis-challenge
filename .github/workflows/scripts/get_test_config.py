#!/usr/bin/env python3
"""
Get test configuration from chess.meta files.
"""

import os
import json
from typing import Dict, List


def get_test_config(implementation: str) -> Dict:
    """Get test configuration for a specific implementation."""
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
    
    print(f"Configuration: {json.dumps(config)}")
    return config


def write_github_output(key: str, value: str):
    """Write to GitHub Actions output file."""
    github_output = os.environ.get('GITHUB_OUTPUT')
    if github_output:
        with open(github_output, 'a') as f:
            f.write(f"{key}={value}\n")
    else:
        print(f"Would set GitHub output: {key}={value}")


def discover_implementations() -> List[str]:
    """Discover all implementations."""
    implementations = []
    impl_dir = "implementations"
    
    if not os.path.exists(impl_dir):
        return implementations
    
    for name in os.listdir(impl_dir):
        impl_path = os.path.join(impl_dir, name)
        if os.path.isdir(impl_path):
            implementations.append(name)
    
    return sorted(implementations)


def get_all_test_configs() -> Dict[str, Dict]:
    """Get test configurations for all implementations."""
    implementations = discover_implementations()
    
    if not implementations:
        print("❌ No implementations found!")
        return {}
    
    configs = {}
    print(f"🔧 Reading test configurations for {len(implementations)} implementations...")
    
    for impl_name in implementations:
        config = get_test_config(impl_name)
        if config:
            configs[impl_name] = config
            print(f"✅ {impl_name}: {config.get('language', 'unknown')}")
        else:
            print(f"❌ {impl_name}: No configuration found")
    
    return configs


def main(args):
    """Main function for get-test-config command."""
    if args.all:
        configs = get_all_test_configs()
        return configs
    else:
        config = get_test_config(args.implementation)
        
        # Write GitHub outputs
        for key, value in config.items():
            if key.startswith("supports_") or key == "test_mode":
                write_github_output(key, str(value).lower())
        
        return config


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Get test configuration')
    parser.add_argument('implementation', nargs='?', help='Implementation name')
    parser.add_argument('--all', action='store_true', help='Get configurations for all implementations')
    
    args = parser.parse_args()
    
    if args.all:
        if args.implementation:
            print("ERROR: Cannot specify implementation when using --all")
            exit(1)
    else:
        if not args.implementation:
            print("ERROR: Implementation name required (or use --all)")
            parser.print_help()
            exit(1)
    
    result = main(args)
    print(json.dumps(result, indent=2))