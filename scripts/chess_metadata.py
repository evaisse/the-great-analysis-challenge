import os
import json
import re
from pathlib import Path
from typing import Dict, List, Any

def get_dockerfile_metadata(dockerfile_path: Path) -> Dict[str, Any]:
    """Extract metadata from Dockerfile LABEL instructions and CMD."""
    metadata = {}
    if dockerfile_path.exists():
        try:
            content = dockerfile_path.read_text()
            # Match LABEL org.chess.key="value" (supports escaped quotes) or unquoted values.
            label_pattern = re.compile(
                r'LABEL\s+org\.chess\.([a-z0-9_.]+)\s*=\s*("(?:(?:\\.)|[^"])*"|[^\s\n]+)'
            )
            for key, raw_val in label_pattern.findall(content):
                if raw_val.startswith('"') and raw_val.endswith('"'):
                    val = raw_val[1:-1]
                    val = val.replace(r'\"', '"').replace(r'\\', '\\')
                else:
                    val = raw_val
                
                # Handle comma-separated lists.
                if key in {'features', 'source_exts'} and val:
                    metadata[key] = [f.strip() for f in val.split(',')]
                # Handle integers
                elif key in ['max_ai_depth', 'estimated_perft4_ms'] and val:
                    try:
                        metadata[key] = int(val)
                    except ValueError:
                        metadata[key] = val
                else:
                    metadata[key] = val
            
            # If run is not specified, try to get it from CMD
            if 'run' not in metadata:
                cmd_match = re.search(r'CMD\s+(?:\[(.*)\]|(.*))', content)
                if cmd_match:
                    if cmd_match.group(1): # JSON array format
                        cmd_parts = [p.strip(' "') for p in cmd_match.group(1).split(',')]
                        metadata['run'] = ' '.join(cmd_parts)
                    else: # Shell format
                        metadata['run'] = cmd_match.group(2).strip()
                        
                    
        except Exception:
            pass
    return metadata

def get_metadata(impl_dir: str) -> Dict[str, Any]:
    """Get combined metadata from chess.meta and Dockerfile labels."""
    impl_path = Path(impl_dir)
    metadata = {}
    
    # Try chess.meta
    meta_file = impl_path / 'chess.meta'
    if meta_file.exists():
        try:
            with open(meta_file, 'r', encoding='utf-8') as f:
                metadata = json.load(f)
        except Exception:
            pass
            
    # Merge with Dockerfile labels (Dockerfile takes precedence)
    dockerfile_path = impl_path / 'Dockerfile'
    if dockerfile_path.exists():
        dockerfile_metadata = get_dockerfile_metadata(dockerfile_path)
        metadata.update(dockerfile_metadata)
        
    return metadata
