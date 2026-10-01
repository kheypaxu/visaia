import os
import re

def scan_all_firestore_fields(repo_dir, name):
    print(f"\n==================== {name} ====================")
    fields_found = {}
    for root, dirs, files in os.walk(repo_dir):
        if any(x in root for x in ['node_modules', '.next', '.git', '.dart_tool', 'build']):
            continue
        for f in files:
            if f.endswith(('.dart', '.ts', '.tsx', '.js')):
                p = os.path.join(root, f)
                with open(p, 'r', encoding='utf-8', errors='ignore') as fp:
                    content = fp.read()
                    
                    # Find map keys like 'fieldName': or data['fieldName'] or doc.get('fieldName')
                    bracket_keys = re.findall(r"(?:data|doc|map|item|json|val|snapshot|req|body)\[['\"](\w+)['\"]\]", content)
                    literal_keys = re.findall(r"['\"](\w+)['\"]\s*:\s*", content)
                    
                    for k in bracket_keys + literal_keys:
                        if len(k) > 1 and not k.startswith('_') and not k.isdigit():
                            fields_found.setdefault(k, 0)
                            fields_found[k] += 1
                            
    print(f"Total unique field/key names detected in {name}: {len(fields_found)}")
    # Print top common keys
    sorted_k = sorted(fields_found.items(), key=lambda x: x[1], reverse=True)
    print("Top 50 keys:")
    for k, count in sorted_k[:50]:
        print(f"  {k:30}: {count}")

scan_all_firestore_fields(r'c:\PROJECTS\visaia', 'VISAIA MOBILE APP')
scan_all_firestore_fields(r'c:\PROJECTS\visaia-dashboard', 'VISAIA DASHBOARD')
