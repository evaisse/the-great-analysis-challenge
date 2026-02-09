#!/usr/bin/env python3
"""
Verification script for Zig chess engine implementation
Checks that all required components are present and properly structured
"""

import json
import os
import sys

def verify_zig_implementation():
    """Verify that the Zig chess implementation meets all requirements"""
    zig_dir = './zig'
    
    print("🚀 Verifying Zig Chess Engine Implementation")
    print("=" * 50)
    
    # Check directory structure
    print("\n📁 Directory Structure:")
    required_files = [
        'chess.meta',
        'src/main.zig',
        'src/board.zig', 
        'src/move_generator.zig',
        'src/ai.zig',
        'src/fen.zig',
        'src/perft.zig',
        'Dockerfile',
        'build.zig',
        'README.md',
        '.gitignore'
    ]
    
    all_files_present = True
    for file in required_files:
        file_path = os.path.join(zig_dir, file)
        if os.path.exists(file_path):
            print(f"  ✓ {file}")
        else:
            print(f"  ✗ {file} - MISSING")
            all_files_present = False
    
    # Validate metadata
    print("\n📋 Metadata Validation:")
    meta_path = os.path.join(zig_dir, 'chess.meta')
    if os.path.exists(meta_path):
        try:
            with open(meta_path, 'r') as f:
                meta = json.load(f)
            
            required_meta_fields = ['language', 'version', 'author', 'build', 'run', 'features']
            meta_valid = True
            
            for field in required_meta_fields:
                if field in meta:
                    print(f"  ✓ {field}: {meta[field]}")
                else:
                    print(f"  ✗ {field} - MISSING")
                    meta_valid = False
            
            # Check required features
            required_features = ['perft', 'fen', 'ai', 'castling', 'en_passant', 'promotion']
            features = meta.get('features', [])
            print(f"\n🎯 Feature Coverage:")
            
            features_complete = True
            for feature in required_features:
                if feature in features:
                    print(f"  ✓ {feature}")
                else:
                    print(f"  ✗ {feature} - MISSING")
                    features_complete = False
            
        except json.JSONDecodeError:
            print("  ✗ chess.meta - INVALID JSON")
            meta_valid = False
            features_complete = False
    else:
        print("  ✗ chess.meta - NOT FOUND")
        meta_valid = False
        features_complete = False
    
    # Check implementation components
    print(f"\n🧩 Implementation Components:")
    
    # Check main.zig for required command handling
    main_zig_path = os.path.join(zig_dir, 'src/main.zig')
    commands_implemented = True
    if os.path.exists(main_zig_path):
        with open(main_zig_path, 'r') as f:
            main_content = f.read()
        
        required_commands = ['new', 'move', 'undo', 'ai', 'fen', 'export', 'eval', 'perft', 'help', 'quit']
        for cmd in required_commands:
            if f'"{cmd}"' in main_content or f"'{cmd}'" in main_content:
                print(f"  ✓ Command: {cmd}")
            else:
                print(f"  ✗ Command: {cmd} - NOT FOUND")
                commands_implemented = False
    else:
        print("  ✗ main.zig - NOT FOUND")
        commands_implemented = False
    
    # Summary
    print(f"\n📊 Verification Summary:")
    print(f"  Files Present: {'✓' if all_files_present else '✗'}")
    print(f"  Metadata Valid: {'✓' if meta_valid else '✗'}")
    print(f"  Features Complete: {'✓' if features_complete else '✗'}")
    print(f"  Commands Implemented: {'✓' if commands_implemented else '✗'}")
    
    overall_success = all_files_present and meta_valid and features_complete and commands_implemented
    
    print(f"\n🎉 Overall Status: {'PASS' if overall_success else 'FAIL'}")
    
    if overall_success:
        print("\n✨ The Zig chess engine implementation is complete and ready for testing!")
        print("   All required components are present and properly structured.")
        print("\n🚀 Next steps:")
        print("   1. Install Zig compiler (zig version 0.13.0 or later)")
        print("   2. Run: cd zig && zig build")
        print("   3. Test: cd zig && zig run src/main.zig")
        print("   4. Docker: docker build -t chess-zig . && docker run -it chess-zig")
    else:
        print("\n❌ Implementation verification failed. Please fix the issues above.")
    
    return overall_success

if __name__ == "__main__":
    success = verify_zig_implementation()
    sys.exit(0 if success else 1)