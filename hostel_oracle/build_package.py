from pathlib import Path
import re
import zipfile

root = Path(__file__).resolve().parent
runner = (root / 'run_all.sql').read_text(encoding='utf-8')

def expand(match):
    name = match[1]
    return f'\n{(root / name).read_text(encoding="utf-8")}\n'

standalone = re.sub(r'^@@(.+\.sql)$', expand, runner, flags=re.MULTILINE)
(root / 'hostel_complete.sql').write_text(standalone, encoding='utf-8')
files = sorted(p for p in root.iterdir() if p.suffix in {'.sql', '.md', '.mmd', '.log', '.ps1', '.py'})
for file in files:
    if file.suffix == '.log' and re.search(r'C6a_[a-f0-9]{32}', file.read_text(encoding='utf-8-sig')):
        raise RuntimeError('A credential was found in a log; packaging refused.')
archive = root.parent / 'case_study_6_oracle.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as out:
    for file in files:
        out.write(file, f'hostel_oracle/{file.name}')
print(f'Packaged {len(files)} files: {archive}')
