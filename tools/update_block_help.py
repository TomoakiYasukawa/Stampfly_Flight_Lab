"""Update Japanese System block dialog headers from the project-owned help data."""
from pathlib import Path
import json
import re


def main():
    root = Path(__file__).resolve().parents[1]
    spec = json.loads((root / 'scripts/model_edit/imu_block_documentation.json').read_text(encoding='utf-8'))
    for system, item in spec['Systems'].items():
        if system.startswith('fusion.'):
            continue
        package, name = system.split('.')
        path = root / 'code' / ('+' + package) / (name + '.m')
        code = path.read_text(encoding='utf-8')
        pattern = r'\n    methods \(Static, Access=protected\)\n        function header=getHeaderImpl\(\).*?\n    end\n'
        code, count = re.subn(pattern, '', code, flags=re.S)
        assert count == 1, (system, count)
        quote = lambda s: s.replace("'", "''")
        header = (
            '\n    methods (Static, Access=protected)\n'
            '        function header=getHeaderImpl()\n'
            '            % ダブルクリックした設定画面に用途と入出力を表示します。\n'
            '            header=matlab.system.display.Header( ...\n'
            f"                'Title','{quote(item['Title'])}', ...\n"
            f"                'Text','{quote(item['Description'])}','ShowSourceLink',true);\n"
            '        end\n    end\n'
        )
        index = code.rfind('\nend')
        assert index >= 0
        path.write_text(code[:index] + header + code[index:], encoding='utf-8')
    print('Japanese System block headers updated:', len(spec['Systems']) - 1)


if __name__ == '__main__':
    main()
