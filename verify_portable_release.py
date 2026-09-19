"""Verify the actual encrypted release without publishing its decrypted contents.

Only allowlisted summary fields are printed. Never upload the temporary folder,
plugin source, installation logs, invitation credential, or decrypted ZIP.
"""
from __future__ import annotations
import argparse
import contextlib
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import platform
import subprocess
import tempfile
import zipfile

SPEC = importlib.util.spec_from_file_location('maxx_installer', Path(__file__).with_name('install.py'))
installer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(installer)

def verify(install=False, setup_runtime=False, office_smoke=False):
    code = os.environ.get('MAXX_TEST_INVITE_CODE', '')
    if not code:
        raise RuntimeError('Release test credential is missing; do not replace it with a public value.')
    root = Path(__file__).resolve().parent
    payload = root / 'payload' / installer.PAYLOAD_NAME
    digest = installer.verify_payload_checksum(payload, payload.with_name('SHA256.txt'))
    plain, backend = installer.decrypt_blob(payload.read_bytes(), code)
    with zipfile.ZipFile(io.BytesIO(plain)) as archive:
        names = [info.orig_filename for info in archive.infolist()]
        if not names or any('\\' in name for name in names):
            raise RuntimeError('The release contains non-POSIX ZIP paths. Rebuild before publishing.')
        if archive.testzip() is not None:
            raise RuntimeError('The current release failed CRC validation.')
        expected = {name: hashlib.sha256(archive.read(name)).hexdigest() for name in names if not name.endswith('/')}
    with tempfile.TemporaryDirectory(prefix='maxx-ci-') as temp:
        destination = Path(temp) / 'checked'
        installer.safe_extract_zip_bytes(plain, destination)
        metadata = installer.verify_extracted_marketplace(destination)
        actual = {p.relative_to(destination).as_posix(): installer.sha256_path(p)
                  for p in destination.rglob('*') if p.is_file()}
        if actual != expected:
            raise RuntimeError('Native extracted files differ from the authenticated release.')
        wrong = 'WRONG-TEST-CREDENTIAL-DO-NOT-USE-0123456789'
        try:
            installer.decrypt_blob(payload.read_bytes(), wrong)
        except installer.InstallError:
            pass
        else:
            raise RuntimeError('Incorrect invitation credential was accepted.')
        result = {'status': 'PASS', 'platform': platform.system(), 'architecture': platform.machine(),
                  'python': platform.python_version(), 'version': metadata['version'],
                  'payload_sha256': digest, 'zip_entries': len(names), 'backslash_entries': 0,
                  'native_extraction_hash_parity': True, 'wrong_credential_rejected': True,
                  'crypto_backend': backend, 'plugin_registration': 'NOT_RUN',
                  'runtime': 'NOT_RUN', 'optional_accounts_and_licensed_apps': 'NOT_TESTED'}
        if install:
            # macOS /var is a system symlink. Resolve our own newly-created
            # scratch directory, never relax the installer's no-link policy.
            parent = Path(temp).resolve() / 'installed'
            args = ['--invite-code', code, '--install-parent', str(parent), '--delivery', 'word']
            if setup_runtime:
                args.extend(['--setup-runtime', '--runtime-profile', 'extended'])
            captured = io.StringIO()
            with contextlib.redirect_stdout(captured), contextlib.redirect_stderr(captured):
                exit_code = installer.main(args)
            # Never print captured logs: they refer to decrypted private files.
            states = list(parent.glob('*/installation-state.json')) if parent.exists() else []
            if exit_code not in (0, 2) or len(states) != 1:
                if 'installation path must not contain symlinks' in captured.getvalue():
                    raise RuntimeError('Release test installation parent contains a symlink; use the canonical scratch directory.')
                raise RuntimeError('Actual Codex plugin installation failed; private logs were suppressed.')
            state = json.loads(states[0].read_text(encoding='utf-8'))
            if state.get('plugin_installed') is not True:
                raise RuntimeError('Installer did not confirm actual plugin registration.')
            installed = Path(state['marketplace_root'])
            for name, sha in expected.items():
                if installer.sha256_path(installed / name) != sha:
                    raise RuntimeError('Installed release is incomplete or differs from payload.')
            result.update(plugin_registration='PASS', installed_file_hash_parity=True,
                          runtime=state.get('runtime_setup'), environment_ready=state.get('environment_ready'))
            if setup_runtime and state.get('runtime_verified') is not True:
                raise RuntimeError('Plugin installed but extended numerical runtime was not verified.')
            if office_smoke:
                runtime = json.loads(Path(state['runtime_report']).read_text(encoding='utf-8'))
                result_run = subprocess.run([runtime['python'], '-I', str(root / 'ci_docx_smoke.py'),
                    str(installed / 'plugins' / installer.PLUGIN_NAME / 'skills' / 'math-modeling-championship-maxx'),
                    str(Path(temp).resolve() / 'docx-test')], capture_output=True, text=True, encoding='utf-8', timeout=240)
                if result_run.returncode != 0:
                    raise RuntimeError('Actual LibreOffice DOCX-to-PDF test failed; private logs were suppressed.')
                receipt = json.loads(result_run.stdout)
                if receipt.get('status') != 'PASS' or not state.get('environment_ready'):
                    raise RuntimeError('Word delivery environment was not ready after actual export.')
                result.update(actual_docx_pdf_export='PASS', office_engine=receipt['engine'])
            result['boundary'] = 'Real Codex registration and isolated Python setup. Desktop UI, account sign-in and licensed applications are not tested.'
        print(json.dumps(result, ensure_ascii=True, indent=2))
        return result

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--install', action='store_true')
    parser.add_argument('--setup-runtime', action='store_true')
    parser.add_argument('--office-smoke', action='store_true')
    args = parser.parse_args()
    try:
        verify(args.install, args.setup_runtime, args.office_smoke)
    except Exception as exc:
        # Do not print tracebacks or exception messages from private plugin code.
        print(json.dumps({'status': 'FAIL', 'stage': type(exc).__name__,
                          'message': str(exc) if type(exc) is RuntimeError else 'Release verification failed; sensitive details suppressed.'}))
        raise SystemExit(1)
