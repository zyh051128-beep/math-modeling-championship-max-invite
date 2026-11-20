"""Public synthetic DOCX/PDF deployment test, not a mathematical-modeling paper."""
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

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

def run_apmcm(skill_root, root, engine='libreoffice'):
    import pymupdf
    root.mkdir()
    team = 'apmcm26999999'
    stem = 'A' + team
    spec = {
        'problem': 'A', 'team': team, 'title': 'Synthetic deployment sample',
        'abstract': ['We verify the rendering of an English APMCM rehearsal report.'],
        'body': [{'type': 'heading', 'level': 1, 'text': 'Test method'},
                 {'type': 'paragraph', 'text': 'We verified the square of three with a short program.'}],
        'software': ['Python'], 'source_files': ['sample.py'],
    }
    # Omit format_profile on purpose: new recipient projects must use APMCM by default.
    (root / 'spec.json').write_text(json.dumps(spec), encoding='utf-8')
    (root / 'sample.py').write_text('print(3 ** 2)\n', encoding='utf-8')
    pipeline = skill_root / 'scripts' / 'publication_pipeline.py'
    command = [sys.executable, str(pipeline), '--project-root', str(root), '--spec', 'spec.json',
               '--output-dir', 'output', '--engine', engine]
    if engine == 'libreoffice':
        command.extend(['--executable', find_libreoffice()])
    result = subprocess.run(command, capture_output=True, timeout=540,
                            env={**os.environ, 'PYTHONUTF8': '1'})
    if result.returncode:
        raise RuntimeError('APMCM publication failed.')
    output = root / 'output'
    receipt = json.loads((output / 'audit/publication-receipt.json').read_text(encoding='utf-8'))
    if (receipt.get('format_profile') != 'apmcm2026' or receipt.get('status') != 'PASS'
            or not (output / (stem + '.docx')).is_file()
            or not (output / (stem + '-rehearsal-control-checklist.docx')).is_file()):
        raise RuntimeError('APMCM publication receipt invalid.')
    with pymupdf.open(output / (stem + '.pdf')) as pdf:
        pages = [''.join(page.get_text().lower().split()) for page in pdf]
        for index, page in enumerate(pdf, start=1):
            bounds = page.rect
            header = page.get_text(clip=pymupdf.Rect(bounds.x0, bounds.y0, bounds.x1, bounds.y0 + 90), sort=True)
            pattern = rf'Team\s*#\s*{re.escape(team)}\s*Page\s*{index}\s*of\s*{len(pdf)}\b'
            if not re.match(pattern, header.lstrip(), re.IGNORECASE):
                raise RuntimeError('APMCM PDF team header or pagination is incorrect.')
    pagination = receipt['pagination']
    body_start, appendix_start = pagination['body_start'], pagination['appendix_start']
    if (len(pages) != receipt['rendering']['page_count'] or len(pages) < 4
            or '2026apmcmsummarysheet' not in pages[0] or 'contents' not in pages[1]
            or not 2 < body_start < appendix_start <= len(pages)
            or 'testmethod' not in pages[body_start - 1] or 'softwareused:' not in pages[appendix_start - 1]
            or appendix_start - body_start != pagination['body_pages'] or not 1 <= pagination['body_pages'] <= 25):
        raise RuntimeError('APMCM physical pages differ from expected layout.')
    return {'apmcm_default_verified': True, 'apmcm_format_profile': receipt['format_profile'],
            'apmcm_team_header_verified': True, 'apmcm_summary_pages': 1,
            'apmcm_pdf_pages': len(pages), 'apmcm_body_pages': pagination['body_pages']}


def run(skill_root, root):
    root.mkdir()
    code = root / 'code'
    code.mkdir()
    for filename in ('export_word_pdf.py', 'word_equations.py', 'huawei23_docx.py', 'refresh_docx_fields.py'):
        shutil.copyfile(skill_root / 'scripts' / filename, code / filename)
    def load(name):
        spec = importlib.util.spec_from_file_location(name, code / (name + '.py'))
        module = importlib.util.module_from_spec(spec)
        sys.modules[name] = module
        spec.loader.exec_module(module)
        return module
    equations = load('word_equations')
    exporter = load('export_word_pdf')
    builder = load('huawei23_docx')
    refresher = load('refresh_docx_fields')
    document = builder.new_document()
    document.add_heading('MAXx portable document verification', 0)
    document.add_paragraph('Synthetic deployment test. This text verifies an editable Word source and actual LibreOffice conversion, not scientific accuracy.')
    document.add_paragraph('The equation below uses native editable subscript structure. No page screenshot is embedded in this document.')
    equations.append_equation(document.add_paragraph(), {'type':'sub', 'base':{'type':'text','value':'x'}, 'sub':{'type':'text','value':'i'}})
    t = lambda value: {'type': 'text', 'value': value}
    for ast in [
        {'type': 'subsup', 'base': t('x'), 'sub': t('i'), 'sup': t('2')},
        {'type': 'integral', 'lower': t('0'), 'upper': t('1'), 'body': t('f(x)dx')},
        {'type': 'product', 'lower': t('i=1'), 'upper': t('n'), 'body': t('x')},
        {'type': 'limit', 'lower': t('n→∞'), 'body': t('f(n)')},
        {'type': 'cases', 'rows': [[t('x'), t('x≥0')], [t('−x'), t('x<0')]]},
    ]:
        equations.append_equation(document.add_paragraph(), ast)
    builder.add_three_line_table(document, [
        ['Sample', 'Estimate', 'Relative error'],
        ['S001', '12.8456', '0.125%'], ['S002', '1278.936', '1.025%'],
    ], caption='Table 1. Synthetic table regression')
    document.add_paragraph('External accounts, licensed applications, desktop login and complete contest papers are outside this smoke test.')
    source = root / 'source.docx'
    document.save(source)
    result = exporter.export(root, 'source.docx', 'rendered.pdf', 'conversion.json', engine='libreoffice',
                             executable=find_libreoffice(), timeout=180)
    if result['status'] != 'PASS' or result['pdf']['page_count'] < 1:
        raise RuntimeError('Actual DOCX export failed.')
    import pymupdf
    with pymupdf.open(root / 'rendered.pdf') as pdf:
        rendered = 0
        for page in pdf:
            image = page.get_pixmap(matrix=pymupdf.Matrix(1, 1), alpha=False)
            if image.width < 100 or image.height < 100:
                raise RuntimeError('Page rendering failed.')
            rendered += 1
    toc_body = []
    for level in range(1, 10):
        toc_body.extend([{'type': 'heading', 'level': level, 'text': f'Heading level {level}'},
                         {'type': 'paragraph', 'text': 'Synthetic contents typography and paragraph pagination check.'}])
    builder.build_from_spec({'title': 'Contents field deployment test', 'include_toc': True,
                             'toc_depth': 9, 'abstract': ['Synthetic deployment verification only.'],
                             'keywords': ['Contents'], 'body': toc_body, 'references': []},
                            root / 'toc-source.docx')
    toc = refresher.refresh(root, 'toc-source.docx', 'toc-refreshed.docx', 'toc-refresh.json',
                            'libreoffice', executable=find_libreoffice(), timeout=180)
    if toc['toc']['cached_levels'] != list(range(1, 10)):
        raise RuntimeError('Refreshed TOC does not include all nine heading levels.')
    toc_export = exporter.export(root, 'toc-refreshed.docx', 'toc-rendered.pdf', 'toc-conversion.json',
                                 engine='libreoffice', executable=find_libreoffice(), timeout=180)
    with pymupdf.open(root / 'toc-rendered.pdf') as pdf:
        for page in pdf:
            page.get_pixmap(matrix=pymupdf.Matrix(1, 1), alpha=False)
            rendered += 1
    apmcm = run_apmcm(skill_root, root / 'apmcm')
    print(json.dumps({'status':'PASS', **apmcm, 'engine':result['engine']['name'],'page_count':result['pdf']['page_count'],
                      'native_equations':6, 'three_line_tables':1, 'pages_rendered':rendered,
                      'native_toc_refreshed':True, 'toc_levels':toc['toc']['cached_levels'],
                      'boundary':'Synthetic editable DOCX actually converted by LibreOffice; visual fidelity of future papers remains subject to per-formula and per-page audit.'}))

if __name__ == '__main__':
    try:
        run(Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve())
    except Exception as exc:
        # Only known classifications; never emit private source/tracebacks.
        known = {
            'APMCM publication failed': 'APMCM_PUBLICATION_FAILED',
            'APMCM publication receipt invalid': 'APMCM_RECEIPT_INVALID',
            'APMCM physical pages differ': 'APMCM_PAGINATION_FAILED',
            'APMCM PDF team header': 'APMCM_HEADER_FAILED',
            'LibreOffice executable was not found': 'OFFICE_NOT_FOUND',
            'LibreOffice requires an explicitly supplied': 'ABSOLUTE_EXECUTABLE_REQUIRED',
            'did not identify itself as LibreOffice': 'OFFICE_VERSION_IDENTITY',
            'LibreOffice timed out': 'OFFICE_TIMEOUT',
            'LibreOffice did not produce': 'OFFICE_NO_OUTPUT',
            'LibreOffice did not return its native field-refresh receipt': 'NATIVE_REFRESH_NO_RECEIPT',
            'LibreOffice native field refresh failed': 'NATIVE_REFRESH_MACRO_FAILED',
            'LibreOffice native field refresh did not converge': 'NATIVE_REFRESH_NOT_CONVERGED',
            'Exported PDF contains no searchable text': 'PDF_NO_SEARCHABLE_TEXT',
            'TOC cached result': 'TOC_REFRESH_INVALID',
            'Refreshed TOC does not include': 'TOC_LEVELS_MISSING',
        }
        diagnostic = next((label for token, label in known.items() if token in str(exc)), 'UNCLASSIFIED')
        failure = {'status':'FAIL', 'diagnostic':diagnostic}
        if diagnostic == 'NATIVE_REFRESH_MACRO_FAILED':
            code = re.search(r'Basic error (\d+)', str(exc))
            if code:
                failure['basic_error_code'] = int(code.group(1))
        print(json.dumps(failure))
        raise SystemExit(1)
