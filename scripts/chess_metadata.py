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
            # Match LABEL org.chess.key="value" or LABEL org.chess.key=value
            matches = re.findall(r'LABEL\s+org\.chess\.([a-z0-9_.]+)\s*=\s*(?:"([^"]*)"|([^\s\n]*))', content)
            for key, val_quoted, val_unquoted in matches:
                val = val_quoted if val_quoted else val_unquoted
                
                # Handle lists (like features)
                if key == 'features' and val:
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
                        
            # Default commands if not specified
            if 'build' not in metadata: metadata['build'] = 'make build'
            if 'test' not in metadata: metadata['test'] = 'make test'
            if 'analyze' not in metadata: metadata['analyze'] = 'make analyze'
                    
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
