#!/usr/bin/env python3
"""
Get test configuration from chess.meta files.
"""

import os
import json
from typing import Dict


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


def main(args):
    """Main function for get-test-config command."""
    config = get_test_config(args.implementation)
    
    # Write GitHub outputs
    for key, value in config.items():
        if key.startswith("supports_") or key == "test_mode":
            write_github_output(key, str(value).lower())
    
    return config


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Get test configuration')
    parser.add_argument('implementation', help='Implementation name')
    
    args = parser.parse_args()
    result = main(args)
    print(json.dumps(result))