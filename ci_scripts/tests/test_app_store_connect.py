#!/usr/bin/env python3

from __future__ import annotations

import base64
import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from typing import Any


MODULE_PATH = Path(__file__).parents[1] / "app_store_connect.py"
SPEC = importlib.util.spec_from_file_location("app_store_connect", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
asc = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(asc)


def decode_token_part(value: str) -> dict[str, Any]:
    value += "=" * (-len(value) % 4)
    return json.loads(base64.urlsafe_b64decode(value))


class FakeClient(asc.AppStoreConnectClient):
    def __init__(self, responses: list[Any]) -> None:
        super().__init__("token")
        self.responses = responses
        self.requests: list[tuple[str, str, dict[str, Any] | None]] = []

    def _request_json(
        self,
        method: str,
        path: str,
        body: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        self.requests.append((method, path, body))
        response = self.responses.pop(0)
        if isinstance(response, Exception):
            raise response
        return response


class TokenTests(unittest.TestCase):
    def test_invalid_private_key_base64_has_clear_error(self) -> None:
        with self.assertRaisesRegex(
            asc.AppStoreConnectError, "ASC_PRIVATE_KEY_BASE64 is not valid base64"
        ):
            asc.create_token("KEY123", "issuer-123", "not-base64!", now=1_000)

    def test_token_contains_apple_claims_and_raw_es256_signature(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            key_path = Path(directory) / "AuthKey_TEST.p8"
            subprocess.run(
                [
                    "/usr/bin/openssl",
                    "ecparam",
                    "-name",
                    "prime256v1",
                    "-genkey",
                    "-noout",
                    "-out",
                    str(key_path),
                ],
                check=True,
                capture_output=True,
            )
            encoded_key = base64.b64encode(key_path.read_bytes()).decode("ascii")

        token = asc.create_token("KEY123", "issuer-123", encoded_key, now=1_000)
        header, payload, signature = token.split(".")
        self.assertEqual(decode_token_part(header)["kid"], "KEY123")
        self.assertEqual(decode_token_part(payload)["iss"], "issuer-123")
        self.assertEqual(decode_token_part(payload)["aud"], "appstoreconnect-v1")
        self.assertEqual(decode_token_part(payload)["exp"], 1_600)
        signature += "=" * (-len(signature) % 4)
        self.assertEqual(len(base64.urlsafe_b64decode(signature)), 64)


class ClientTests(unittest.TestCase):
    def test_find_app_id_uses_bundle_filter(self) -> None:
        client = FakeClient([{"data": [{"id": "12345"}]}])
        self.assertEqual(client.find_app_id("com.example.App"), "12345")
        self.assertIn("filter%5BbundleId%5D=com.example.App", client.requests[0][1])

    def test_existing_version_is_idempotent(self) -> None:
        existing = {
            "id": "version-id",
            "attributes": {"platform": "IOS", "versionString": "1.1.1"},
        }
        client = FakeClient([{"data": [existing]}])
        version, created = client.ensure_version("app-id", "1.1.1", "IOS")
        self.assertEqual(version, existing)
        self.assertFalse(created)
        self.assertEqual(len(client.requests), 1)

    def test_missing_version_is_created(self) -> None:
        created_version = {
            "id": "new-version-id",
            "attributes": {"platform": "IOS", "versionString": "1.1.1"},
        }
        client = FakeClient([{"data": []}, {"data": created_version}])
        version, created = client.ensure_version("app-id", "1.1.1", "IOS")
        self.assertEqual(version, created_version)
        self.assertTrue(created)
        method, path, body = client.requests[1]
        self.assertEqual((method, path), ("POST", "/appStoreVersions"))
        self.assertEqual(body["data"]["attributes"]["versionString"], "1.1.1")
        self.assertEqual(body["data"]["relationships"]["app"]["data"]["id"], "app-id")

    def test_conflict_is_treated_as_concurrent_creation(self) -> None:
        existing = {
            "id": "version-id",
            "attributes": {"platform": "IOS", "versionString": "1.1.1"},
        }
        conflict = asc.AppStoreConnectError("conflict", status=409)
        client = FakeClient([{"data": []}, conflict, {"data": [existing]}])
        version, created = client.ensure_version("app-id", "1.1.1", "IOS")
        self.assertEqual(version, existing)
        self.assertFalse(created)


class ValidationTests(unittest.TestCase):
    def test_version_pattern(self) -> None:
        for valid in ("1", "1.1", "1.1.1"):
            self.assertIsNotNone(asc.VERSION_PATTERN.fullmatch(valid))
        for invalid in ("", "1.1.1.1", "v1.1", "1.1-beta"):
            self.assertIsNone(asc.VERSION_PATTERN.fullmatch(invalid))


if __name__ == "__main__":
    unittest.main()
