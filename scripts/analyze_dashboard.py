import os
import re
import glob

def analyze_dashboard_files():
    dash_path = r'c:\PROJECTS\visaia-dashboard'
    print("================ VISAIA DASHBOARD DATA STRUCTURES ================\n")
    
    files = []
    for root, dirs, fnames in os.walk(dash_path):
        if any(x in root for x in ['node_modules', '.next', '.git']):
            continue
        for f in fnames:
            if f.endswith(('.ts', '.tsx')):
                files.append(os.path.join(root, f))
                
    for f in sorted(files):
        rel = os.path.relpath(f, dash_path)
        with open(f, 'r', encoding='utf-8', errors='ignore') as src:
            content = src.read()
            # find interfaces and types
            interfaces = re.findall(r'(interface\s+\w+\s*\{[^}]+\})', content)
            types = re.findall(r'(type\s+\w+\s*=\s*\{[^}]+\})', content)
            
            # find firestore sets / adds / updates
            writes = re.findall(r'(setDoc|addDoc|updateDoc|deleteDoc)\s*\([^)]+\)', content)
            
            if interfaces or types or writes:
                print(f"FILE: {rel}")
                for iface in interfaces:
                    print(f"  [Interface]:\n{iface}\n")
                for t in types:
                    print(f"  [Type]:\n{t}\n")
                if writes:
                    print(f"  [Writes]: {len(writes)} write operations")
                print("-" * 50)

if __name__ == '__main__':
    analyze_dashboard_files()
