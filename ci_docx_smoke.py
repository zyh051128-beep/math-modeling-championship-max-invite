"""Public synthetic DOCX/PDF deployment test, not a mathematical-modeling paper."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys
from docx import Document

def find_libreoffice():
    candidates = [shutil.which('soffice'), shutil.which('libreoffice'),
                  '/Applications/LibreOffice.app/Contents/MacOS/soffice',
                  str(Path.home() / 'Applications/LibreOffice.app/Contents/MacOS/soffice')]
    for variable in ('ProgramFiles', 'ProgramFiles(x86)'):
        if os.environ.get(variable):
            candidates.append(str(Path(os.environ[variable]) / 'LibreOffice/program/soffice.exe'))
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            # Windows GUI launcher may not return console --version output.
            console = Path(candidate).with_suffix('.com')
            if sys.platform == 'win32' and console.is_file():
                return str(console.resolve())
            return str(Path(candidate).resolve())
    raise RuntimeError('LibreOffice executable was not found in PATH or standard application folders.')

def run(skill_root, root):
    root.mkdir()
    code = root / 'code'
    code.mkdir()
    for filename in ('export_word_pdf.py', 'word_equations.py'):
        shutil.copyfile(skill_root / 'scripts' / filename, code / filename)
    def load(name):
        spec = importlib.util.spec_from_file_location(name, code / (name + '.py'))
        module = importlib.util.module_from_spec(spec)
        sys.modules[name] = module
        spec.loader.exec_module(module)
        return module
    equations = load('word_equations')
    exporter = load('export_word_pdf')
    document = Document()
    document.add_heading('MAXx portable document verification', 0)
    document.add_paragraph('Synthetic deployment test. This text verifies an editable Word source and actual LibreOffice conversion, not scientific accuracy.')
    document.add_paragraph('The equation below uses native editable subscript structure. No page screenshot is embedded in this document.')
    equations.append_equation(document.add_paragraph(), {'type':'sub', 'base':{'type':'text','value':'x'}, 'sub':{'type':'text','value':'i'}})
    document.add_paragraph('External accounts, licensed applications, desktop login and complete contest papers are outside this smoke test.')
    source = root / 'source.docx'
    document.save(source)
    result = exporter.export(root, 'source.docx', 'rendered.pdf', 'conversion.json', engine='libreoffice',
                             executable=find_libreoffice(), timeout=180)
    if result['status'] != 'PASS' or result['pdf']['page_count'] < 1:
        raise RuntimeError('Actual DOCX export failed.')
    print(json.dumps({'status':'PASS','engine':result['engine']['name'],'page_count':result['pdf']['page_count'],
                      'boundary':'Synthetic editable DOCX actually converted by LibreOffice; visual fidelity of future papers remains subject to per-formula and per-page audit.'}))

if __name__ == '__main__':
    try:
        run(Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve())
    except Exception as exc:
        # Only known classifications; never emit private source/tracebacks.
        known = {
            'LibreOffice executable was not found': 'OFFICE_NOT_FOUND',
            'LibreOffice requires an explicitly supplied': 'ABSOLUTE_EXECUTABLE_REQUIRED',
            'did not identify itself as LibreOffice': 'OFFICE_VERSION_IDENTITY',
            'LibreOffice timed out': 'OFFICE_TIMEOUT',
            'LibreOffice did not produce': 'OFFICE_NO_OUTPUT',
            'Exported PDF contains no searchable text': 'PDF_NO_SEARCHABLE_TEXT',
        }
        diagnostic = next((label for token, label in known.items() if token in str(exc)), 'UNCLASSIFIED')
        print(json.dumps({'status':'FAIL', 'diagnostic':diagnostic}))
        raise SystemExit(1)
