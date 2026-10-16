"""Update location-only references after organize_project.ps1; no flight logic edits."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[3]
changed = []

def update(path, transform):
    before = path.read_text(encoding='utf-8-sig')
    after = transform(before)
    if after != before:
        path.write_text(after, encoding='utf-8')
        changed.append(str(path.relative_to(root)))

def script_paths(text):
    text = text.replace("fileparts(mfilename('fullpath'))", 'stampfly_project_root()')
    return model_paths(text)

def model_paths(text):
    text = re.sub(r"fullfile\(root,\s*'models',\s*\[([A-Za-z]\w*)\s*'\.slx'\]\)", r'stampfly_model_file(\1)', text)
    text = text.replace("fullfile(root,'model_algorithms'", "fullfile(root,'code','model_algorithms'")
    return text

for path in (root/'scripts').rglob('*.m'):
    if path.name == 'setup_imu_monitor.m':
        continue
    update(path, script_paths)
for path in (root/'tests').glob('*.m'):
    update(path, model_paths)
for path in (root/'code').rglob('*.m'):
    update(path, lambda s: re.sub(r"(?:fileparts\(){2,}mfilename\('fullpath'\)\){2,}", "fileparts(fileparts(fileparts(mfilename('fullpath'))))", s))
update(root/'code/+reorg/lift.m', lambda s: s.replace("fileparts(which('ensure_simulink_toolkit'))", 'stampfly_project_root()'))

for path in (root/'tools').glob('*.py'):
    if path.name in {Path(__file__).name, 'organize_project.ps1'}:
        continue
    def tool_paths(text):
        if path.name in {'download_source.py', 'inspect_firmware.py', 'inspect_official.py'}:
            text = re.sub(r'Path\(__file__\)\.resolve\(\)\.parent(?:s\[1\])?(?:s\[1\])*', 'Path(__file__).resolve().parents[3]', text)
        text = text.replace("root/'+official'", "root/'code/+official'")
        text = text.replace("root/'+official/", "root/'code/+official/")
        text = text.replace("root / '+official'", "root / 'code' / '+official'")
        text = text.replace("root/'+imu'", "root/'code/+imu'")
        text = text.replace("root/'model_algorithms", "root/'code/model_algorithms")
        text = text.replace("root/'assemble_official_modular.m'", "root/'archive/maintenance/scripts/model_edit/assemble_official_modular.m'")
        text = text.replace("root/'assemble_official_control.m'", "root/'archive/maintenance/scripts/model_edit/assemble_official_control.m'")
        text = text.replace("root / 'setup_record.json'", "root / 'docs' / 'history' / 'setup_record.json'")
        return script_paths(text) if path.name == 'create_model_editor.py' else text
    update(path, tool_paths)

print(f'Updated location references in {len(changed)} files.')
for name in changed:
    print(name)
