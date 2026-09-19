from __future__ import annotations

import hashlib
import hmac
import importlib.util
import io
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest
import zipfile


MODULE_PATH = Path(__file__).with_name("install.py")
SPEC = importlib.util.spec_from_file_location("maxx_invite_install", MODULE_PATH)
assert SPEC and SPEC.loader
installer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(installer)


VALID_CODE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef0123456789"


def make_authenticated_blob(cipher: bytes, code: str = VALID_CODE, iv: bytes = b"I" * 16) -> bytes:
    prefix = installer.MAGIC + iv + cipher
    auth_key = hashlib.sha256(("auth:" + code).encode("utf-8")).digest()
    return prefix + hmac.new(auth_key, prefix, hashlib.sha256).digest()


def make_encrypted_blob(plain: bytes, code: str = VALID_CODE) -> bytes:
    try:
        from cryptography.hazmat.primitives import padding
        from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
    except ImportError as exc:  # pragma: no cover - exercised only on minimal Python installs
        raise unittest.SkipTest("cryptography is not installed") from exc
    key = hashlib.sha256(code.encode("utf-8")).digest()
    iv = bytes(range(16))
    padder = padding.PKCS7(128).padder()
    padded = padder.update(plain) + padder.finalize()
    encryptor = Cipher(algorithms.AES(key), modes.CBC(iv)).encryptor()
    cipher = encryptor.update(padded) + encryptor.finalize()
    return make_authenticated_blob(cipher, code, iv)


def zip_bytes(entries: list[tuple[zipfile.ZipInfo | str, bytes]]) -> bytes:
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for name, content in entries:
            archive.writestr(name, content)
    return output.getvalue()


def build_marketplace_fixture(root: Path, version: str = "2.4.0+codex.test") -> None:
    marketplace = {
        "name": installer.MARKETPLACE_NAME,
        "interface": {"displayName": "数模-MAXx 私有市场"},
        "plugins": [{
            "name": installer.PLUGIN_NAME,
            "source": {"source": "local", "path": f"./plugins/{installer.PLUGIN_NAME}"},
            "policy": {"installation": "AVAILABLE", "authentication": "ON_INSTALL"},
            "category": "Education",
        }],
    }
    market_path = root / ".agents" / "plugins" / "marketplace.json"
    market_path.parent.mkdir(parents=True)
    market_path.write_text(json.dumps(marketplace, ensure_ascii=False), encoding="utf-8")
    plugin_root = root / "plugins" / installer.PLUGIN_NAME
    for relative in installer.REQUIRED_PLUGIN_PATHS:
        path = plugin_root.joinpath(*relative.split("/"))
        path.parent.mkdir(parents=True, exist_ok=True)
        if relative == ".codex-plugin/plugin.json":
            path.write_text(json.dumps({"name": installer.PLUGIN_NAME, "version": version}), encoding="utf-8")
        else:
            path.write_text("fixture\n", encoding="utf-8")


class CredentialTests(unittest.TestCase):
    def test_fragment_query_and_direct_routes(self) -> None:
        self.assertEqual(installer.parse_invite_url(f"https://example.test/repo#invite={VALID_CODE}"), VALID_CODE)
        self.assertEqual(installer.parse_invite_url(f"https://example.test/repo?invite={VALID_CODE}"), VALID_CODE)
        self.assertEqual(installer.resolve_invite_code(None, VALID_CODE), VALID_CODE)

    def test_matching_query_and_fragment_are_accepted(self) -> None:
        url = f"https://example.test/repo?invite={VALID_CODE}#invite={VALID_CODE}"
        self.assertEqual(installer.parse_invite_url(url), VALID_CODE)

    def test_conflicting_duplicate_url_credentials_are_rejected(self) -> None:
        other = VALID_CODE[:-1] + "X"
        with self.assertRaisesRegex(installer.InstallError, "conflicting"):
            installer.parse_invite_url(f"https://example.test/repo?invite={VALID_CODE}#invite={other}")

    def test_explicit_code_mismatch_is_case_sensitive(self) -> None:
        with self.assertRaisesRegex(installer.InstallError, "do not match"):
            installer.resolve_invite_code(f"https://example.test/#invite={VALID_CODE}", VALID_CODE.lower())

    def test_missing_credential_is_rejected(self) -> None:
        with self.assertRaisesRegex(installer.InstallError, "Supply"):
            installer.resolve_invite_code(None, None)
        with self.assertRaises(installer.InstallError):
            installer.parse_invite_url("https://example.test/repo")


class PayloadTests(unittest.TestCase):
    def test_checksum_and_hmac_validation(self) -> None:
        cipher = b"C" * 16
        blob = make_authenticated_blob(cipher)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            payload = root / installer.PAYLOAD_NAME
            checksum = root / "SHA256.txt"
            payload.write_bytes(blob)
            expected = hashlib.sha256(blob).hexdigest()
            checksum.write_text(f"{expected}  {installer.PAYLOAD_NAME}\n", encoding="utf-8")
            self.assertEqual(installer.verify_payload_checksum(payload, checksum), expected)
            key, iv, actual_cipher = installer.authenticate_blob(blob, VALID_CODE)
            self.assertEqual(key, hashlib.sha256(VALID_CODE.encode()).digest())
            self.assertEqual(iv, b"I" * 16)
            self.assertEqual(actual_cipher, cipher)

    def test_wrong_checksum_and_wrong_code_are_rejected(self) -> None:
        blob = make_authenticated_blob(b"C" * 16)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            payload = root / installer.PAYLOAD_NAME
            checksum = root / "SHA256.txt"
            payload.write_bytes(blob)
            checksum.write_text(f"{'0' * 64}  {installer.PAYLOAD_NAME}\n", encoding="utf-8")
            with self.assertRaisesRegex(installer.InstallError, "SHA-256"):
                installer.verify_payload_checksum(payload, checksum)
        with self.assertRaisesRegex(installer.InstallError, "invalid, revoked"):
            installer.authenticate_blob(blob, VALID_CODE[:-1] + "X")

    def test_cryptography_backend_decrypts_pkcs7_payload(self) -> None:
        plain = b"PK\x03\x04synthetic invitation archive"
        blob = make_encrypted_blob(plain)
        decrypted, backend = installer.decrypt_blob(blob, VALID_CODE, "cryptography")
        self.assertEqual(decrypted, plain)
        self.assertEqual(backend, "cryptography")

    @unittest.skipUnless(os.environ.get("MAXX_TEST_INVITE_CODE"), "set MAXX_TEST_INVITE_CODE for the private release verification")
    def test_current_release_payload_positive_and_negative(self) -> None:
        code = os.environ["MAXX_TEST_INVITE_CODE"]
        payload = Path(__file__).with_name("payload") / installer.PAYLOAD_NAME
        checksum = payload.with_name("SHA256.txt")
        installer.verify_payload_checksum(payload, checksum)
        plain, _ = installer.decrypt_blob(payload.read_bytes(), code)
        with tempfile.TemporaryDirectory() as temporary:
            extracted = Path(temporary) / "marketplace"
            installer.safe_extract_zip_bytes(plain, extracted)
            package = installer.verify_extracted_marketplace(extracted)
            self.assertTrue(package["version"])
        wrong = code[:-1] + ("A" if code[-1] != "A" else "B")
        with self.assertRaisesRegex(installer.InstallError, "invalid, revoked"):
            installer.decrypt_blob(payload.read_bytes(), wrong)


class ArchiveTests(unittest.TestCase):
    def test_safe_archive_extracts_and_marketplace_validates(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            fixture = Path(temporary) / "fixture"
            build_marketplace_fixture(fixture)
            archive = io.BytesIO()
            with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as output:
                for path in fixture.rglob("*"):
                    if path.is_file():
                        output.write(path, path.relative_to(fixture).as_posix())
            extracted = Path(temporary) / "out"
            installer.safe_extract_zip_bytes(archive.getvalue(), extracted)
            package = installer.verify_extracted_marketplace(extracted)
            self.assertEqual(package["version"], "2.4.0+codex.test")

    def test_path_traversal_absolute_and_backslash_are_rejected(self) -> None:
        for name in ("../escape", "/absolute", "C:/drive"):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temporary:
                with self.assertRaises(installer.InstallError):
                    installer.safe_extract_zip_bytes(zip_bytes([(name, b"x")]), Path(temporary) / "out")
        with self.assertRaises(installer.InstallError):
            installer._safe_member_parts("folder\\file")

    def test_symlink_member_is_rejected(self) -> None:
        link = zipfile.ZipInfo("link")
        link.create_system = 3
        link.external_attr = (stat.S_IFLNK | 0o777) << 16
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaisesRegex(installer.InstallError, "Links"):
                installer.safe_extract_zip_bytes(zip_bytes([(link, b"target")]), Path(temporary) / "out")

    def test_case_colliding_members_are_rejected(self) -> None:
        archive = zip_bytes([("Folder/File.txt", b"a"), ("folder/file.TXT", b"b")])
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaisesRegex(installer.InstallError, "case-colliding"):
                installer.safe_extract_zip_bytes(archive, Path(temporary) / "out")

    def test_wrong_marketplace_source_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            build_marketplace_fixture(root)
            marketplace_path = root / ".agents" / "plugins" / "marketplace.json"
            marketplace = json.loads(marketplace_path.read_text(encoding="utf-8"))
            marketplace["plugins"][0]["source"]["path"] = "C:/sender/plugin"
            marketplace_path.write_text(json.dumps(marketplace), encoding="utf-8")
            with self.assertRaisesRegex(installer.InstallError, "expected local path"):
                installer.verify_extracted_marketplace(root)


class RegistrationTests(unittest.TestCase):
    @staticmethod
    def completed(args: list[str], code: int = 0, stdout: str = "") -> subprocess.CompletedProcess[str]:
        return subprocess.CompletedProcess(args, code, stdout, "")

    def test_registration_uses_receiver_root_and_plugin_spec(self) -> None:
        calls: list[list[str]] = []

        def runner(argv: list[str], **_: object) -> subprocess.CompletedProcess[str]:
            calls.append(argv)
            if argv[-3:] == ["marketplace", "list", "--json"]:
                return self.completed(argv, stdout='{"marketplaces": []}')
            return self.completed(argv)

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            result = installer.register_plugin(root, "/usr/local/bin/codex", runner)
        self.assertEqual(result["status"], "INSTALLED")
        self.assertIn(["/usr/local/bin/codex", "plugin", "marketplace", "add", str(root)], calls)
        self.assertIn(["/usr/local/bin/codex", "plugin", "add", installer.PLUGIN_SPEC], calls)

    def test_failed_plugin_add_rolls_back_existing_marketplace(self) -> None:
        calls: list[list[str]] = []
        with tempfile.TemporaryDirectory() as temporary:
            previous = Path(temporary) / "previous"
            previous.mkdir()
            new = Path(temporary) / "new"
            new.mkdir()

            def runner(argv: list[str], **_: object) -> subprocess.CompletedProcess[str]:
                calls.append(argv)
                if argv[-3:] == ["marketplace", "list", "--json"]:
                    return self.completed(argv, stdout=json.dumps({"marketplaces": [{"name": installer.MARKETPLACE_NAME, "root": str(previous)}]}))
                if argv == ["codex", "plugin", "add", installer.PLUGIN_SPEC] and calls.count(argv) == 1:
                    return self.completed(argv, code=1)
                return self.completed(argv)

            with self.assertRaisesRegex(installer.InstallError, "restored: True"):
                installer.register_plugin(new, "codex", runner)
            self.assertIn(["codex", "plugin", "marketplace", "add", str(previous)], calls)


class StateTests(unittest.TestCase):
    def test_written_state_has_no_invitation_secret(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "installation-state.json"
            state = {"plugin_installed": True, "payload_sha256": "a" * 64, "marketplace_root": str(Path(temporary) / "maxx")}
            installer.write_json_new(path, state)
            raw = path.read_text(encoding="utf-8")
            self.assertNotIn(VALID_CODE, raw)
            self.assertNotIn("invite=", raw)


if __name__ == "__main__":
    unittest.main()
