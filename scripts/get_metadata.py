#!/usr/bin/env python3
import argparse
import json
import sys
import os

# Add scripts directory to path to import shared module
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from chess_metadata import get_metadata

def main():
    parser = argparse.ArgumentParser(description='Extract chess implementation metadata')
    parser.add_argument('impl_dir', help='Implementation directory')
    parser.add_argument('--field', help='Specific field to extract')
    parser.add_argument('--format', choices=['json', 'text'], default='text', help='Output format')
    
    args = parser.parse_args()
    
    metadata = get_metadata(args.impl_dir)
    
    if args.field:
        val = metadata.get(args.field, '')
        if isinstance(val, list):
            print(','.join(val))
        else:
            print(val)
    else:
        if args.format == 'json':
            print(json.dumps(metadata, indent=2))
        else:
            for k, v in metadata.items():
                print(f"{k}: {v}")

if __name__ == '__main__':
    main()
