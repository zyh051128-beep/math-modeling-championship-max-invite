#!/usr/bin/env python3
"""Cross-platform installer for the encrypted Shumo-MAXx invitation package.

Python 3.11 or newer is required.  On macOS/Linux, AES decryption uses the
system ``openssl`` command when available.  The optional ``cryptography``
package is the fallback and is also used by default on Windows.

The invitation credential is used only in memory to authenticate and decrypt
the package.  It is never written to an installation state file or command
log.
"""

from __future__ import annotations

import argparse
import hashlib
import hmac
import io
import json
import os
from pathlib import Path, PurePosixPath
import platform
import re
import shutil
import stat
import subprocess
import sys
import tempfile
from typing import Callable, Sequence
from urllib.parse import parse_qsl, urlsplit
import uuid
import zipfile


REPOSITORY_URL = "https://github.com/zyh051128-beep/math-modeling-championship-max-invite.git"
MAGIC = b"MMCMAX1"
PAYLOAD_NAME = "plugin-marketplace.aes"
MARKETPLACE_NAME = "zyh-mathmodel-private"
PLUGIN_NAME = "math-modeling-championship-max"
PLUGIN_SPEC = f"{PLUGIN_NAME}@{MARKETPLACE_NAME}"
MAX_ZIP_ENTRIES = 20_000
MAX_MEMBER_SIZE = 512 * 1024 * 1024
MAX_TOTAL_SIZE = 2 * 1024 * 1024 * 1024

REQUIRED_PLUGIN_PATHS = (
    ".codex-plugin/plugin.json",
    "skills/math-modeling-championship-maxx/SKILL.md",
    "skills/math-modeling-championship-max/SKILL.md",
    "skills/math-modeling-championship-maxx/scripts/huawei_cup_audit.py",
    "skills/math-modeling-championship-maxx/scripts/evidence_consistency_audit.py",
    "skills/math-modeling-championship-maxx/scripts/ai_content_audit.py",
    "skills/math-modeling-championship-maxx/scripts/scispace_evidence.py",
    "skills/math-modeling-championship-maxx/scripts/bootstrap_runtime.py",
    "skills/math-modeling-championship-maxx/scripts/max_doctor.py",
    "skills/math-modeling-championship-maxx/scripts/render_flowcharts.py",
    "skills/math-modeling-championship-maxx/scripts/presentation_audit.py",
    "skills/math-modeling-championship-maxx/scripts/export_word_pdf.py",
    "skills/math-modeling-championship-maxx/scripts/word_source_audit.py",
    "skills/math-modeling-championship-maxx/scripts/build_delivery_zip.py",
    "skills/math-modeling-championship-maxx/scripts/page_budget_audit.py",
    "skills/math-modeling-championship-maxx/scripts/algorithm_verification_audit.py",
    "skills/math-modeling-championship-maxx/scripts/edit_figure_spec.py",
    "skills/math-modeling-championship-maxx/references/word-delivery-contract.md",
    "skills/math-modeling-championship-maxx/references/word-delivery-manifest-template.json",
    "skills/math-modeling-championship-maxx/references/runtime-profiles.json",
    "skills/math-modeling-championship-maxx/references/external-installation.md",
    "skills/math-modeling-championship-maxx/references/flowchart-spec-example.json",
    "skills/math-modeling-championship-maxx/references/presentation-manifest-template.json",
    "skills/math-modeling-championship-maxx/references/presentation-contract.md",
    "skills/math-modeling-championship-maxx/references/presentation-workflow.md",
    "skills/math-modeling-championship/SKILL.md",
    "skills/math-modeling-championship/scripts/doctor.py",
    "skills/math-modeling-championship/scripts/state_manager.py",
)

Runner = Callable[..., subprocess.CompletedProcess]


class InstallError(RuntimeError):
    """Expected installation or verification failure."""


def require_supported_python() -> None:
    if sys.version_info < (3, 11) or platform.python_implementation() != "CPython":
        raise InstallError("A real CPython 3.11 or newer interpreter is required.")


def strict_json_bytes(raw: bytes, label: str) -> object:
    def reject_duplicate(pairs: list[tuple[str, object]]) -> dict[str, object]:
        result: dict[str, object] = {}
        for key, value in pairs:
            if key in result:
                raise InstallError(f"{label} contains a duplicate JSON key: {key}")
            result[key] = value
        return result

    try:
        return json.loads(
            raw.decode("utf-8-sig"),
            object_pairs_hook=reject_duplicate,
            parse_constant=lambda value: (_ for _ in ()).throw(
                InstallError(f"{label} contains a non-finite JSON value: {value}")
            ),
        )
    except UnicodeDecodeError as exc:
        raise InstallError(f"{label} is not valid UTF-8.") from exc
    except json.JSONDecodeError as exc:
        raise InstallError(f"{label} is not valid JSON.") from exc


def parse_invite_url(value: str) -> str:
    try:
        parsed = urlsplit(value.strip())
    except ValueError as exc:
        raise InstallError("The supplied invitation URL is not valid.") from exc
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise InstallError("The invitation URL must be a complete HTTP(S) URL.")
    values = [
        item
        for source in (parsed.query, parsed.fragment)
        for key, item in parse_qsl(source, keep_blank_values=True)
        if key == "invite"
    ]
    if not values or any(not item.strip() for item in values):
        raise InstallError("The invitation URL must contain a non-empty invite value in its query or fragment.")
    first = values[0]
    if any(not hmac.compare_digest(first.encode("utf-8"), item.encode("utf-8")) for item in values[1:]):
        raise InstallError("The invitation URL contains conflicting invite values.")
    return first


def resolve_invite_code(invite_url: str | None, invite_code: str | None) -> str:
    from_url = parse_invite_url(invite_url) if invite_url else None
    direct = invite_code.strip() if invite_code else None
    if from_url and direct and not hmac.compare_digest(from_url.encode("utf-8"), direct.encode("utf-8")):
        raise InstallError("The invitation URL and separately supplied invitation code do not match.")
    credential = from_url or direct
    if not credential:
        raise InstallError("Supply --invite-url with the complete #invite= fragment, or use --invite-code.")
    if len(credential) < 32 or len(set(credential)) < 16:
        raise InstallError("The invitation credential has an invalid format.")
    return credential


def sha256_path(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def expected_payload_hash(checksum_path: Path) -> str:
    try:
        lines = [line.strip() for line in checksum_path.read_text(encoding="utf-8-sig").splitlines() if line.strip()]
    except OSError as exc:
        raise InstallError("The invitation checksum file cannot be read.") from exc
    if len(lines) != 1:
        raise InstallError("The invitation checksum file must contain exactly one entry.")
    match = re.fullmatch(r"([0-9a-fA-F]{64})\s+\*?([^/\\\s]+)", lines[0])
    if not match or match.group(2) != PAYLOAD_NAME:
        raise InstallError("The invitation checksum entry is malformed or names the wrong payload.")
    return match.group(1).lower()


def verify_payload_checksum(payload_path: Path, checksum_path: Path) -> str:
    if not payload_path.is_file() or payload_path.is_symlink():
        raise InstallError("The encrypted invitation payload is missing or unsafe.")
    if not checksum_path.is_file() or checksum_path.is_symlink():
        raise InstallError("The invitation checksum file is missing or unsafe.")
    expected = expected_payload_hash(checksum_path)
    actual = sha256_path(payload_path)
    if not hmac.compare_digest(actual, expected):
        raise InstallError("The encrypted invitation payload does not match its published SHA-256 checksum.")
    return actual


def authenticate_blob(blob: bytes, invite_code: str) -> tuple[bytes, bytes, bytes]:
    minimum = len(MAGIC) + 16 + 16 + 32
    if len(blob) < minimum or not blob.startswith(MAGIC):
        raise InstallError("The invitation package is incomplete or uses an unsupported format.")
    iv = blob[len(MAGIC) : len(MAGIC) + 16]
    cipher = blob[len(MAGIC) + 16 : -32]
    expected_mac = blob[-32:]
    if not cipher or len(cipher) % 16:
        raise InstallError("The invitation package contains an invalid encrypted payload.")
    auth_key = hashlib.sha256(("auth:" + invite_code).encode("utf-8")).digest()
    actual_mac = hmac.new(auth_key, blob[:-32], hashlib.sha256).digest()
    if not hmac.compare_digest(actual_mac, expected_mac):
        raise InstallError("The invitation is invalid, revoked, or the package is corrupted.")
    key = hashlib.sha256(invite_code.encode("utf-8")).digest()
    return key, iv, cipher


def decrypt_with_openssl(cipher: bytes, key: bytes, iv: bytes, executable: str) -> bytes:
    try:
        completed = subprocess.run(
            [executable, "enc", "-d", "-aes-256-cbc", "-nosalt", "-K", key.hex(), "-iv", iv.hex()],
            input=cipher,
            capture_output=True,
            check=False,
            timeout=120,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise InstallError("OpenSSL could not decrypt the authenticated invitation package.") from exc
    if completed.returncode != 0:
        raise InstallError("OpenSSL rejected the authenticated invitation ciphertext.")
    return completed.stdout


def decrypt_with_cryptography(cipher: bytes, key: bytes, iv: bytes) -> bytes:
    try:
        from cryptography.hazmat.primitives import padding
        from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
    except ImportError as exc:
        raise InstallError(
            "No usable AES backend was found. Install OpenSSL, or install the Python package "
            "'cryptography' into this interpreter."
        ) from exc
    try:
        decryptor = Cipher(algorithms.AES(key), modes.CBC(iv)).decryptor()
        padded = decryptor.update(cipher) + decryptor.finalize()
        unpadder = padding.PKCS7(128).unpadder()
        return unpadder.update(padded) + unpadder.finalize()
    except ValueError as exc:
        raise InstallError("The authenticated invitation ciphertext could not be decrypted.") from exc


def decrypt_blob(blob: bytes, invite_code: str, backend: str = "auto") -> tuple[bytes, str]:
    key, iv, cipher = authenticate_blob(blob, invite_code)
    openssl = shutil.which("openssl")
    order: list[str]
    if backend == "openssl":
        order = ["openssl"]
    elif backend == "cryptography":
        order = ["cryptography"]
    elif platform.system() in {"Darwin", "Linux"}:
        order = ["openssl", "cryptography"]
    else:
        order = ["cryptography", "openssl"]
    failures: list[str] = []
    for name in order:
        try:
            if name == "openssl":
                if not openssl:
                    raise InstallError("OpenSSL is not available on PATH.")
                return decrypt_with_openssl(cipher, key, iv, openssl), name
            return decrypt_with_cryptography(cipher, key, iv), name
        except InstallError as exc:
            failures.append(str(exc))
    raise InstallError("No AES backend could decrypt the authenticated package: " + " ".join(failures))


def _safe_member_parts(name: str) -> tuple[str, ...]:
    if not name or "\x00" in name or "\\" in name or name.startswith("/") or re.match(r"^[A-Za-z]:", name):
        raise InstallError("The invitation archive contains an unsafe member path.")
    pure = PurePosixPath(name.rstrip("/"))
    if not pure.parts or any(part in {"", ".", ".."} for part in pure.parts):
        raise InstallError("The invitation archive contains a path traversal entry.")
    return pure.parts


def safe_extract_zip_bytes(archive_bytes: bytes, destination: Path) -> None:
    try:
        archive = zipfile.ZipFile(io.BytesIO(archive_bytes), "r")
    except (zipfile.BadZipFile, OSError) as exc:
        raise InstallError("The decrypted invitation is not a valid ZIP archive.") from exc
    with archive:
        infos = archive.infolist()
        if not infos or len(infos) > MAX_ZIP_ENTRIES:
            raise InstallError("The invitation archive has an invalid number of entries.")
        total = 0
        seen: set[str] = set()
        validated: list[tuple[zipfile.ZipInfo, tuple[str, ...], bool]] = []
        for info in infos:
            parts = _safe_member_parts(info.filename)
            key = "/".join(parts).casefold()
            if key in seen:
                raise InstallError("The invitation archive contains duplicate or case-colliding paths.")
            seen.add(key)
            if info.flag_bits & 0x1:
                raise InstallError("Nested encrypted files are not allowed in the invitation archive.")
            if info.compress_type not in {zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED}:
                raise InstallError("The invitation archive uses an unsupported compression method.")
            mode = (info.external_attr >> 16) & 0xFFFF
            file_type = stat.S_IFMT(mode)
            is_dir = info.is_dir()
            if file_type and file_type not in {stat.S_IFREG, stat.S_IFDIR}:
                raise InstallError("Links and special files are not allowed in the invitation archive.")
            if file_type == stat.S_IFDIR and not is_dir:
                raise InstallError("The invitation archive contains inconsistent directory metadata.")
            if file_type == stat.S_IFREG and is_dir:
                raise InstallError("The invitation archive contains inconsistent file metadata.")
            if info.file_size < 0 or info.file_size > MAX_MEMBER_SIZE:
                raise InstallError("An invitation archive member exceeds the allowed size.")
            total += info.file_size
            if total > MAX_TOTAL_SIZE:
                raise InstallError("The invitation archive exceeds the allowed expanded size.")
            validated.append((info, parts, is_dir))

        try:
            destination.mkdir(parents=True, exist_ok=False)
        except OSError as exc:
            raise InstallError("The secure extraction directory could not be created.") from exc
        root = destination.resolve()
        for info, parts, is_dir in validated:
            target = root.joinpath(*parts)
            try:
                target.relative_to(root)
            except ValueError as exc:
                raise InstallError("The invitation archive escaped its extraction directory.") from exc
            try:
                if is_dir:
                    target.mkdir(parents=True, exist_ok=True)
                    continue
                target.parent.mkdir(parents=True, exist_ok=True)
                written = 0
                with archive.open(info, "r") as source, target.open("xb") as output:
                    while True:
                        chunk = source.read(1024 * 1024)
                        if not chunk:
                            break
                        written += len(chunk)
                        if written > info.file_size or written > MAX_MEMBER_SIZE:
                            raise InstallError("An archive member expanded beyond its declared safe size.")
                        output.write(chunk)
            except (OSError, RuntimeError, zipfile.BadZipFile) as exc:
                raise InstallError("The invitation archive failed CRC or extraction validation.") from exc
            if written != info.file_size:
                raise InstallError("An invitation archive member has an inconsistent expanded size.")


def _assert_regular_file(root: Path, relative: str) -> Path:
    path = root.joinpath(*PurePosixPath(relative).parts)
    if not path.is_file() or path.is_symlink():
        raise InstallError(f"The decrypted package is incomplete or unsafe. Missing: {relative}")
    return path


def verify_extracted_marketplace(root: Path) -> dict[str, str]:
    marketplace_path = _assert_regular_file(root, ".agents/plugins/marketplace.json")
    marketplace = strict_json_bytes(marketplace_path.read_bytes(), "marketplace.json")
    if not isinstance(marketplace, dict) or marketplace.get("name") != MARKETPLACE_NAME:
        raise InstallError("The decrypted marketplace has an unexpected identity.")
    entries = marketplace.get("plugins")
    matching = [item for item in entries if isinstance(item, dict) and item.get("name") == PLUGIN_NAME] if isinstance(entries, list) else []
    if len(matching) != 1:
        raise InstallError("The decrypted marketplace does not contain exactly one MAXx plugin entry.")
    source = matching[0].get("source")
    if not isinstance(source, dict) or source.get("source") != "local" or source.get("path") != f"./plugins/{PLUGIN_NAME}":
        raise InstallError("The decrypted marketplace plugin source is not the expected local path.")

    plugin_root = root / "plugins" / PLUGIN_NAME
    for relative in REQUIRED_PLUGIN_PATHS:
        _assert_regular_file(plugin_root, relative)
    manifest_path = plugin_root / ".codex-plugin" / "plugin.json"
    manifest = strict_json_bytes(manifest_path.read_bytes(), "plugin.json")
    if not isinstance(manifest, dict) or manifest.get("name") != PLUGIN_NAME:
        raise InstallError("The decrypted plugin manifest has an unexpected identity.")
    version = manifest.get("version")
    if not isinstance(version, str) or not version.strip():
        raise InstallError("The decrypted plugin manifest has no valid version.")
    return {"version": version, "plugin_root": str(plugin_root), "manifest": str(manifest_path)}


def write_json_new(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8") as handle:
        json.dump(value, handle, ensure_ascii=False, indent=2)
        handle.write("\n")


def default_install_parent() -> Path:
    if os.name == "nt":
        return Path.home() / "codex-invited-marketplaces"
    if platform.system() == "Darwin":
        return Path.home() / "Library" / "Application Support" / "ShumoMAXx" / "invited-marketplaces"
    data_home = os.environ.get("XDG_DATA_HOME")
    return (Path(data_home) if data_home else Path.home() / ".local" / "share") / "shumo-maxx" / "invited-marketplaces"


def clone_distribution(work_root: Path) -> Path:
    git = shutil.which("git")
    if not git:
        raise InstallError("Git is required to download the invitation repository.")
    destination = work_root / "distribution"
    completed = subprocess.run(
        [git, "-c", "credential.helper=", "-c", "core.autocrlf=false", "clone", "--depth", "1", REPOSITORY_URL, str(destination)],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
        timeout=300,
    )
    if completed.returncode != 0:
        raise InstallError("Unable to clone the public invitation repository. Check GitHub connectivity.")
    return destination


def locate_distribution(script_root: Path, work_root: Path) -> tuple[Path, Path]:
    payload = script_root / "payload" / PAYLOAD_NAME
    checksum = script_root / "payload" / "SHA256.txt"
    if payload.is_file() and checksum.is_file():
        return payload, checksum
    if payload.exists() or checksum.exists():
        raise InstallError("The local invitation repository contains an incomplete payload directory.")
    downloaded = clone_distribution(work_root)
    payload = downloaded / "payload" / PAYLOAD_NAME
    checksum = downloaded / "payload" / "SHA256.txt"
    if not payload.is_file() or not checksum.is_file():
        raise InstallError("The invitation repository does not contain the encrypted package and checksum.")
    return payload, checksum


def _run_text(argv: Sequence[str], timeout: int = 300, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            list(argv), capture_output=True, text=True, encoding="utf-8", errors="replace",
            check=False, timeout=timeout, env=env,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise InstallError(f"Could not execute required program: {Path(argv[0]).name}") from exc


def _marketplace_roots(data: object) -> tuple[set[str], str | None]:
    if not isinstance(data, dict) or not isinstance(data.get("marketplaces"), list):
        raise InstallError("Codex returned an invalid marketplace listing.")
    names: set[str] = set()
    previous: str | None = None
    for item in data["marketplaces"]:
        if not isinstance(item, dict) or not isinstance(item.get("name"), str):
            raise InstallError("Codex returned an invalid marketplace entry.")
        names.add(item["name"])
        if item["name"] == MARKETPLACE_NAME and isinstance(item.get("root"), str):
            previous = item["root"]
    return names, previous


def register_plugin(install_root: Path, codex: str, runner: Runner = _run_text) -> dict[str, object]:
    for preflight in ([codex, "--version"], [codex, "plugin", "--help"]):
        completed = runner(preflight, timeout=120)
        if completed.returncode != 0:
            raise InstallError("The detected Codex CLI cannot run the required plugin commands.")
    listing = runner([codex, "plugin", "marketplace", "list", "--json"], timeout=120)
    if listing.returncode != 0:
        raise InstallError("Codex could not list existing plugin marketplaces, so safe replacement cannot continue.")
    try:
        marketplace_data = json.loads(listing.stdout)
    except json.JSONDecodeError as exc:
        raise InstallError("Codex returned an unreadable marketplace listing.") from exc
    names, previous_root = _marketplace_roots(marketplace_data)
    if MARKETPLACE_NAME in names and (not previous_root or not Path(previous_root).is_dir()):
        raise InstallError("The existing invited marketplace has no recoverable local root; safe replacement stopped.")

    new_added = False
    removed_previous = False
    try:
        if MARKETPLACE_NAME in names:
            removed = runner([codex, "plugin", "marketplace", "remove", MARKETPLACE_NAME], timeout=120)
            if removed.returncode != 0:
                raise InstallError("Unable to remove the previous invited marketplace.")
            removed_previous = True
        added = runner([codex, "plugin", "marketplace", "add", str(install_root)], timeout=120)
        if added.returncode != 0:
            raise InstallError("Unable to register the invited plugin marketplace.")
        new_added = True
        installed = runner([codex, "plugin", "add", PLUGIN_SPEC], timeout=300)
        if installed.returncode != 0:
            raise InstallError("Unable to install the MAXx plugin from the invited marketplace.")
        return {"status": "INSTALLED", "previous_marketplace_root": previous_root, "previous_marketplace_replaced": removed_previous}
    except InstallError as exc:
        restored = False
        if new_added:
            runner([codex, "plugin", "marketplace", "remove", MARKETPLACE_NAME], timeout=120)
        if previous_root and Path(previous_root).is_dir():
            restored_add = runner([codex, "plugin", "marketplace", "add", previous_root], timeout=120)
            if restored_add.returncode == 0:
                restored_plugin = runner([codex, "plugin", "add", PLUGIN_SPEC], timeout=300)
                restored = restored_plugin.returncode == 0
        raise InstallError(f"{exc} Previous marketplace restored: {restored}.") from exc


def resolve_python(candidate: str | None) -> str:
    selected = candidate or os.environ.get("MATHMODEL_PYTHON") or sys.executable
    path = Path(selected).expanduser()
    if not path.is_file():
        found = shutil.which(selected)
        if not found:
            raise InstallError("No usable Python interpreter was found for runtime setup and Doctor.")
        path = Path(found)
    probe = _run_text(
        [str(path), "-I", "-c", "import json,platform,sys;print(json.dumps({'implementation':platform.python_implementation(),'version':list(sys.version_info[:3])}))"],
        timeout=60,
    )
    if probe.returncode != 0:
        raise InstallError("The selected Python interpreter could not run an isolated probe.")
    try:
        data = json.loads(probe.stdout)
    except json.JSONDecodeError as exc:
        raise InstallError("The selected Python interpreter returned an invalid probe result.") from exc
    version = data.get("version") if isinstance(data, dict) else None
    if (
        not isinstance(data, dict)
        or data.get("implementation") != "CPython"
        or not isinstance(version, list)
        or len(version) != 3
        or any(not isinstance(item, int) for item in version)
        or tuple(version) < (3, 11, 0)
    ):
        raise InstallError("Runtime setup requires CPython 3.11 or newer.")
    return str(path.resolve())


def setup_runtime(maxx_root: Path, python: str, profile: str, report_path: Path) -> tuple[str, str]:
    script = maxx_root / "scripts" / "bootstrap_runtime.py"
    completed = _run_text([python, "-I", str(script), "--profile", profile], timeout=3600)
    try:
        report = json.loads(completed.stdout)
    except json.JSONDecodeError as exc:
        report = {"status": "NOT_READY", "execution_verified": False, "error": "Runtime setup returned no valid JSON report."}
        write_json_new(report_path, report)
        raise InstallError(report["error"]) from exc
    write_json_new(report_path, report)
    runtime_python = report.get("python") if isinstance(report, dict) else None
    if (
        completed.returncode != 0
        or not isinstance(report, dict)
        or report.get("status") != "VERIFIED"
        or report.get("execution_verified") is not True
        or not isinstance(runtime_python, str)
        or not Path(runtime_python).is_file()
    ):
        raise InstallError("Python runtime setup did not reach VERIFIED status; inspect runtime-setup.json.")
    return "VERIFIED", runtime_python


def run_doctor(maxx_root: Path, python: str, delivery: str, output_path: Path) -> tuple[dict[str, object], bool]:
    script = maxx_root / "scripts" / "max_doctor.py"
    env = dict(os.environ)
    env.update({"MATHMODEL_PYTHON": python, "PYTHONUTF8": "1"})
    completed = _run_text(
        [python, "-I", str(script), "--delivery", delivery, "--profile", "championship", "--inputs", "csv", "xlsx", "--output", str(output_path)],
        timeout=900,
        env=env,
    )
    try:
        if output_path.is_file():
            report = strict_json_bytes(output_path.read_bytes(), "MAXx Doctor report")
        else:
            report = strict_json_bytes(completed.stdout.encode("utf-8"), "MAXx Doctor report")
            write_json_new(output_path, report)
    except InstallError:
        report = {"ready": False, "blocking_failures": ["doctor:no_valid_report"]}
        if not output_path.exists():
            write_json_new(output_path, report)
    if not isinstance(report, dict):
        report = {"ready": False, "blocking_failures": ["doctor:invalid_report_type"]}
    ready = completed.returncode == 0 and report.get("ready") is True and not report.get("blocking_failures")
    return report, ready


def resolve_directory_without_links(raw: Path) -> Path:
    expanded = raw.expanduser().absolute()
    for part in (expanded, *expanded.parents):
        if part.exists() and (part.is_symlink() or (hasattr(part, "is_junction") and part.is_junction())):
            raise InstallError("The installation path must not contain symlinks or junctions.")
    return expanded.resolve()


def copy_marketplace(extracted: Path, install_parent: Path) -> Path:
    install_parent = resolve_directory_without_links(install_parent)
    if install_parent == Path(install_parent.anchor) or install_parent == Path.home().resolve():
        raise InstallError("The installation parent must be a dedicated subdirectory.")
    if install_parent.exists() and (install_parent.is_symlink() or not install_parent.is_dir()):
        raise InstallError("The installation parent is not a safe directory.")
    install_parent.mkdir(parents=True, exist_ok=True)
    install_root = install_parent / ("maxx-" + uuid.uuid4().hex)
    try:
        shutil.copytree(extracted, install_root, symlinks=False)
    except OSError as exc:
        raise InstallError("Unable to copy the verified marketplace into the receiver installation directory.") from exc
    verify_extracted_marketplace(install_root)
    return install_root


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--invite-url", help="Complete invitation URL containing an invite value in its query or #fragment.")
    parser.add_argument("--invite-code", help="Invitation code supplied separately by the sender; if both are given they must match.")
    parser.add_argument("--verify-only", action="store_true", help="Verify checksum, credential, decryption and required files without installing.")
    parser.add_argument("--setup-runtime", action="store_true", help="Create and verify the isolated MAXx Python runtime.")
    parser.add_argument("--runtime-profile", choices=("core", "extended"), default="extended")
    parser.add_argument("--delivery", choices=("word", "latex", "both"), default="both")
    parser.add_argument("--python-path", help="CPython 3.11+ executable to use for runtime setup and Doctor.")
    parser.add_argument("--install-parent", type=Path, default=default_install_parent(), help="Dedicated directory that will contain the invited marketplace.")
    parser.add_argument("--crypto-backend", choices=("auto", "openssl", "cryptography"), default="auto", help=argparse.SUPPRESS)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    try:
        require_supported_python()
        args = build_parser().parse_args(argv)
        credential = resolve_invite_code(args.invite_url, args.invite_code)
        script_root = Path(__file__).resolve().parent
        with tempfile.TemporaryDirectory(prefix="shumo-maxx-invite-") as temporary:
            work_root = Path(temporary)
            payload_path, checksum_path = locate_distribution(script_root, work_root)
            payload_sha256 = verify_payload_checksum(payload_path, checksum_path)
            archive_bytes, crypto_backend = decrypt_blob(payload_path.read_bytes(), credential, args.crypto_backend)
            # Drop the only local reference before archive processing.  The
            # credential is never passed to a subprocess or persisted.
            credential = ""
            extracted = work_root / "marketplace"
            safe_extract_zip_bytes(archive_bytes, extracted)
            package = verify_extracted_marketplace(extracted)
            if args.verify_only:
                print(json.dumps({
                    "status": "VERIFIED", "plugin": PLUGIN_NAME, "version": package["version"],
                    "payload_sha256": payload_sha256, "crypto_backend": crypto_backend,
                    "scope": "checksum, invitation authentication, decryption, safe extraction and required files",
                }, ensure_ascii=False, indent=2))
                return 0

            codex = shutil.which("codex")
            if not codex:
                raise InstallError("Codex CLI is not available on PATH. Install or locate the official Codex CLI first.")
            install_root = copy_marketplace(extracted, args.install_parent)
            try:
                registration = register_plugin(install_root, codex)
            except InstallError as exc:
                write_json_new(install_root / "registration-failure.json", {
                    "status": "FAIL", "error": str(exc), "plugin": PLUGIN_NAME,
                })
                raise

            maxx_root = install_root / "plugins" / PLUGIN_NAME / "skills" / "math-modeling-championship-maxx"
            runtime_status = "NOT_REQUESTED"
            runtime_report: str | None = None
            environment_errors: list[str] = []
            selected_python: str | None = None
            doctor_path = install_root / "maxx-install-doctor.json"
            ready = False
            try:
                selected_python = resolve_python(args.python_path)
            except InstallError as exc:
                runtime_status = "FAILED" if args.setup_runtime else "NOT_READY"
                environment_errors.append(str(exc))
                write_json_new(doctor_path, {
                    "ready": False,
                    "blocking_failures": ["doctor:no_usable_python"],
                    "error": str(exc),
                })
            if selected_python and args.setup_runtime:
                runtime_report_path = install_root / "runtime-setup.json"
                runtime_report = str(runtime_report_path)
                try:
                    runtime_status, selected_python = setup_runtime(
                        maxx_root, selected_python, args.runtime_profile, runtime_report_path
                    )
                except InstallError as exc:
                    runtime_status = "FAILED"
                    environment_errors.append(str(exc))
            if selected_python:
                try:
                    _, ready = run_doctor(maxx_root, selected_python, args.delivery, doctor_path)
                except InstallError as exc:
                    environment_errors.append(str(exc))
                    if not doctor_path.exists():
                        write_json_new(doctor_path, {
                            "ready": False,
                            "blocking_failures": ["doctor:execution_failed"],
                            "error": str(exc),
                        })
            if args.setup_runtime and runtime_status != "VERIFIED":
                ready = False
            state = {
                "plugin_installed": True,
                "version": package["version"],
                "environment_ready": ready,
                "platform": platform.platform(),
                "architecture": platform.machine(),
                "crypto_backend": crypto_backend,
                "payload_sha256": payload_sha256,
                "marketplace_root": str(install_root),
                "registration": registration,
                "delivery": args.delivery,
                "requested_runtime_profile": args.runtime_profile if args.setup_runtime else None,
                "runtime_setup": runtime_status,
                "runtime_verified": runtime_status == "VERIFIED",
                "runtime_report": runtime_report,
                "doctor_report": str(doctor_path),
                "environment_errors": environment_errors,
                "installation_guide": str(maxx_root / "references" / "external-installation.md"),
                "external_account_connections_verified": False,
                "all_optional_applications_executed": False,
            }
            write_json_new(install_root / "installation-state.json", state)
            print(json.dumps(state, ensure_ascii=False, indent=2))
            print("Create a new Codex task after restarting Codex to load the updated plugin.")
            return 0 if ready else 2
    except InstallError as exc:
        print(f"Installation failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
