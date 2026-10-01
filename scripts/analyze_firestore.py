import os
import re
import sys

def find_firestore_calls(root_dir):
    calls = []
    for root, dirs, files in os.walk(root_dir):
        if any(x in root for x in ['node_modules', '.git', '.dart_tool', 'build', '.next', '.idea']):
            continue
        for f in files:
            if f.endswith(('.dart', '.ts', '.tsx', '.js', '.jsx')):
                p = os.path.join(root, f)
                with open(p, 'r', encoding='utf-8', errors='ignore') as file:
                    content = file.read()
                    matches = re.findall(r'collection\s*\(\s*[\'"`]([^\'"`]+)[\'"`]\s*\)', content)
                    for m in matches:
                        calls.append((os.path.relpath(p, root_dir), m))
                    
                    # Also look for direct collection paths with interpolation
                    interp_matches = re.findall(r'collection\s*\(\s*([^)]+)\)', content)
                    for im in interp_matches:
                        calls.append((os.path.relpath(p, root_dir), im.strip()))
    return calls

print('=== VISAIA (Flutter) FIRESTORE PATHS ===')
flutter_calls = find_firestore_calls(r'c:\PROJECTS\visaia')
for file, path in sorted(set(flutter_calls)):
    print(f'{file:50} -> {path}')

print('\n=== VISAIA DASHBOARD (Next.js) FIRESTORE PATHS ===')
dash_calls = find_firestore_calls(r'c:\PROJECTS\visaia-dashboard')
for file, path in sorted(set(dash_calls)):
    print(f'{file:50} -> {path}')
