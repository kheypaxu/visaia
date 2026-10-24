"""Apply only the staged notification changes after sandbox write approval."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[1]
dashboard = (root.parent / 'visaia-dashboard').resolve()
stage = root / 'push-backend'
manifest = json.loads((stage / 'install-manifest.json').read_text(encoding='utf-8'))
changes = []
for entry in manifest:
    target = (dashboard / entry['path']).resolve()
    source = (stage / entry.get('source', entry['path'])).resolve()
    if not target.is_relative_to(dashboard) or not source.is_relative_to(stage.resolve()):
        raise RuntimeError('Path outside the expected dashboard or staging folder')
    actual = hashlib.sha256(target.read_bytes()).hexdigest() if target.exists() else None
    if actual != entry['before']:
        raise RuntimeError(f'Dashboard changed since staging: {entry["path"]}')
    changes.append((source, target))
for source, target in changes:
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(source.read_bytes())
print(f'Applied {len(changes)} notification files to {dashboard}. No deployment or billing changes.')
