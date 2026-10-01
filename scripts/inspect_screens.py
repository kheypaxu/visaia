import os
import re

files_to_check = [
    r'c:\PROJECTS\visaia\lib\screens\logging_screens\field_scouting_screen.dart',
    r'c:\PROJECTS\visaia\lib\screens\logging_screens\inspect_trap_screen.dart',
    r'c:\PROJECTS\visaia\lib\screens\logging_screens\harvest_recording.dart',
    r'c:\PROJECTS\visaia\lib\screens\logging_screens\daily_log_screen.dart',
    r'c:\PROJECTS\visaia\lib\screens\logging_screens\ai_result.dart',
    r'c:\PROJECTS\visaia\lib\screens\logging_screens\upload_pest.dart',
    r'c:\PROJECTS\visaia\lib\screens\dashboard_screens\threat_details.dart',
    r'c:\PROJECTS\visaia\lib\screens\dashboard_screens\view_income.dart',
    r'c:\PROJECTS\visaia\lib\screens\report_history\report_details.dart',
    r'c:\PROJECTS\visaia\lib\screens\report_history\report_history.dart'
]

for file_path in files_to_check:
    if not os.path.exists(file_path):
        continue
    rel = os.path.relpath(file_path, r'c:\PROJECTS\visaia')
    print(f"\n==================== {rel} ====================")
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
        
        # Look for maps with key-value pairs
        maps = re.findall(r'(\{[^{}]*[\'"](?:id|farmerId|farmId|cycleId|fieldId|detection|status|income|severity|larvae|moths|acres|crop)[\'"][^{}]*\})', content)
        for m in maps[:3]:
            print(f"Data Map Snippet:\n{m.strip()}\n")
            
        # Look for Firestore operations
        fs_ops = re.findall(r'(\w+(?:\.instance)?\.collection\([^\)]+\)[^;]+;)', content)
        for op in fs_ops[:3]:
            print(f"Firestore Operation:\n{op.strip()}\n")
