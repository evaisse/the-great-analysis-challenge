#!/usr/bin/env python3
"""
Read chess.meta files to determine test configuration for each implementation.
This replaces hardcoded special cases with convention-based configuration.
"""

import os
import json
import sys

def load_chess_meta(impl_path):
    """Load and parse chess.meta file for an implementation."""
    meta_path = os.path.join(impl_path, "chess.meta")
    
    if not os.path.exists(meta_path):
        return None
    
    try:
        with open(meta_path, 'r') as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        print(f"Warning: Invalid JSON in {meta_path}: {e}")
        return None
    except Exception as e:
        print(f"Warning: Error reading {meta_path}: {e}")
        return None

def get_test_config(implementation):
    """Get test configuration for a specific implementation."""
    impl_path = f"implementations/{implementation}"
    
    if not os.path.exists(impl_path):
        return None
    
    meta = load_chess_meta(impl_path)
    if not meta:
        # Default configuration if no chess.meta
        return {
            "language": implementation,
            "supports_interactive": True,
            "supports_perft": True,
            "supports_ai": True,
            "test_mode": "full"
        }
    
    features = meta.get("features", [])
    
    # Determine test capabilities from features
    config = {
        "language": meta.get("language", implementation),
        "supports_interactive": "ai" in features and "perft" in features,
        "supports_perft": "perft" in features,
        "supports_ai": "ai" in features,
        "test_mode": "demo" if features == ["demo"] else "full",
        "max_ai_depth": meta.get("max_ai_depth", 3),
        "estimated_perft4_ms": meta.get("estimated_perft4_ms", 1000)
    }
    
    return config

def main():
    """Main function - return test config for implementation or all implementations."""
    if len(sys.argv) > 1:
        implementation = sys.argv[1]
        config = get_test_config(implementation)
        if config:
            print(json.dumps(config))
        else:
            print(json.dumps({}))
    else:
        # Return config for all implementations
        implementations_dir = "implementations"
        all_configs = {}
        
        if os.path.exists(implementations_dir):
            for name in os.listdir(implementations_dir):
                config = get_test_config(name)
                if config:
                    all_configs[name] = config
        
        print(json.dumps(all_configs, indent=2))

if __name__ == "__main__":
    main()