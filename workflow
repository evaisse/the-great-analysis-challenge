#!/usr/bin/env python3
"""
Simple entrypoint wrapper for the unified workflow script.
Allows running commands as: ./workflow <command> [args]
"""

import sys
import os
from pathlib import Path

# Add the script directory to Python path
script_dir = Path(__file__).parent / ".github" / "workflows" / "scripts"
sys.path.insert(0, str(script_dir))

# Import and run the main workflow script
if __name__ == "__main__":
    # Change to the script directory so relative paths work correctly
    os.chdir(script_dir.parent.parent.parent)
    
    # Import the workflow module
    from workflow import main
    
    # Run the main function
    sys.exit(main())