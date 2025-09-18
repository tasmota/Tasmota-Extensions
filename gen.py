#!/usr/bin/env python3
"""
Tasmota Extension Builder
Builds .tapp files from raw extension directories and generates manifest.jsonl
"""

import os
import json
import zipfile
import glob
from pathlib import Path
from typing import Dict, List, Optional

def clean_tapp_files():
    """Remove all existing .tapp files from extensions/tapp directory"""
    tapp_dir = Path("extensions/tapp")
    if tapp_dir.exists():
        for tapp_file in tapp_dir.glob("*.tapp"):
            print(f"Removing existing file: {tapp_file}")
            tapp_file.unlink()

def validate_directory(dir_path: Path) -> bool:
    """Check if directory contains required manifest.json and autoexec.be files"""
    manifest_file = dir_path / "manifest.json"
    autoexec_file = dir_path / "autoexec.be"
    
    if not manifest_file.exists():
        print(f"ERROR: Missing manifest.json in {dir_path}")
        return False
    
    if not autoexec_file.exists():
        print(f"ERROR: Missing autoexec.be in {dir_path}")
        return False
    
    return True

def load_manifest(manifest_path: Path) -> Optional[Dict]:
    """Load and validate manifest.json file"""
    try:
        with open(manifest_path, 'r', encoding='utf-8') as f:
            manifest = json.load(f)
        
        # Check required fields
        required_fields = ['name', 'version', 'description', 'author']
        for field in required_fields:
            if field not in manifest:
                print(f"ERROR: Missing required field '{field}' in {manifest_path}")
                return None
        
        return manifest
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON in {manifest_path}: {e}")
        return None
    except Exception as e:
        print(f"ERROR: Failed to read {manifest_path}: {e}")
        return None

def create_tapp_file(source_dir: Path, output_dir: Path) -> Optional[str]:
    """Create uncompressed .tapp file from source directory"""
    # Generate filename: replace spaces with underscores and add .tapp extension
    tapp_filename = source_dir.name.replace(' ', '_') + '.tapp'
    tapp_path = output_dir / tapp_filename
    
    try:
        with zipfile.ZipFile(tapp_path, 'w', zipfile.ZIP_STORED) as zf:
            # Add all files from source directory with flat structure (-j flag equivalent)
            for file_path in source_dir.iterdir():
                if file_path.is_file():
                    # Add file with just its name (flat structure)
                    zf.write(file_path, file_path.name)
                    print(f"  Added: {file_path.name}")
        
        print(f"Created: {tapp_path}")
        return tapp_filename
    except Exception as e:
        print(f"ERROR: Failed to create {tapp_path}: {e}")
        return None

def build_extensions():
    """Main function to build all extensions"""
    raw_dir = Path("raw")
    output_dir = Path("extensions/tapp")
    
    # Ensure output directory exists
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Clean existing .tapp files
    clean_tapp_files()
    
    # Collect manifest data for global manifest.jsonl
    manifests = []
    
    # Process each directory in raw/
    for dir_path in raw_dir.iterdir():
        if not dir_path.is_dir() or dir_path.name.startswith('.'):
            continue
        
        print(f"\nProcessing: {dir_path.name}")
        
        # Validate directory structure
        if not validate_directory(dir_path):
            continue
        
        # Load and validate manifest
        manifest_path = dir_path / "manifest.json"
        manifest = load_manifest(manifest_path)
        if not manifest:
            continue
        
        # Create .tapp file
        tapp_filename = create_tapp_file(dir_path, output_dir)
        if not tapp_filename:
            continue
        
        # Add synthetic "file" attribute and collect for global manifest
        manifest_entry = {
            'name': manifest['name'],
            'file': tapp_filename,
            'version': manifest['version'],
            'description': manifest['description'],
            'author': manifest['author']
        }
        manifests.append(manifest_entry)
    
    # Generate global manifest.jsonl
    if manifests:
        # Sort by name
        manifests.sort(key=lambda x: x['name'])
        
        manifest_jsonl_path = Path("extensions/extensions.jsonl")
        with open(manifest_jsonl_path, 'w', encoding='utf-8') as f:
            for manifest_entry in manifests:
                # Write JSON with specific field order
                ordered_entry = {
                    'name': manifest_entry['name'],
                    'file': manifest_entry['file'],
                    'version': manifest_entry['version'],
                    'description': manifest_entry['description'],
                    'author': manifest_entry['author']
                }
                f.write(json.dumps(ordered_entry, separators=(',', ':')) + '\n')
        
        print(f"\nGenerated: {manifest_jsonl_path}")
        print(f"Total extensions: {len(manifests)}")
    else:
        print("\nNo valid extensions found!")

if __name__ == "__main__":
    build_extensions()