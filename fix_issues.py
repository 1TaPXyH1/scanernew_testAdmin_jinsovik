#!/usr/bin/env python3
import os
import re
import glob

def fix_const_constructors(file_path):
    """Fix prefer_const_constructors issues"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Common patterns for const constructors
    patterns = [
        (r'(\s+)Icon\(', r'\1const Icon('),
        (r'(\s+)Text\(', r'\1const Text('),
        (r'(\s+)SizedBox\(', r'\1const SizedBox('),
        (r'(\s+)EdgeInsets\.', r'\1const EdgeInsets.'),
        (r'(\s+)Padding\(', r'\1const Padding('),
        (r'(\s+)Center\(', r'\1const Center('),
        (r'(\s+)Column\(', r'\1const Column('),
        (r'(\s+)Row\(', r'\1const Row('),
        (r'(\s+)Container\(\s*\)', r'\1const Container()'),
        (r'(\s+)Spacer\(\s*\)', r'\1const Spacer()'),
        (r'(\s+)Divider\(\s*\)', r'\1const Divider()'),
        (r'(\s+)CircularProgressIndicator\(\s*\)', r'\1const CircularProgressIndicator()'),
    ]
    
    for pattern, replacement in patterns:
        content = re.sub(pattern, replacement, content)
    
    # Fix withOpacity to withValues
    content = re.sub(r'\.withOpacity\(([0-9.]+)\)', r'.withValues(alpha: \1)', content)
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

def fix_all_dart_files():
    """Fix all Dart files in the project"""
    dart_files = glob.glob('lib/**/*.dart', recursive=True)
    
    for file_path in dart_files:
        print(f"Fixing {file_path}...")
        fix_const_constructors(file_path)
    
    print(f"Fixed {len(dart_files)} files")

if __name__ == "__main__":
    fix_all_dart_files()
    print("All fixes applied!")
