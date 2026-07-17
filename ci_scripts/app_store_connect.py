#!/usr/bin/env python3
"""Create the App Store version matching a successful Xcode Cloud archive."""

from __future__ import annotations

import argparse
import base64
import binascii
import json
import os
import re
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


API_BASE_URL = "https://api.appstoreconnect.apple.com/v1"
VERSION_PATTERN = re.compile(r"^[0-9]+(?:\.[0-9]+){0,2}$")


class AppStoreConnectError(RuntimeError):
    def __init__(self, message: str, status: int | None = None) -> None:
        super().__init__(message)
        self.status = status


def _base64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _der_length(data: bytes, offset: int) -> tuple[int, int]:
    first = data[offset]
    offset += 1
    if first < 0x80:
        return first, offset

    byte_count = first & 0x7F
    if byte_count == 0 or byte_count > 4:
        raise AppStoreConnectError("Invalid ECDSA signature length")
    end = offset + byte_count
    if end > len(data):
        raise AppStoreConnectError("Truncated ECDSA signature length")
    return int.from_bytes(data[offset:end], "big"), end


def _der_signature_to_jose(signature: bytes, component_size: int = 32) -> bytes:
    """Convert OpenSSL's ASN.1 DER ECDSA signature to JWT's R || S form."""
    if not signature or signature[0] != 0x30:
        raise AppStoreConnectError("Invalid ECDSA signature sequence")

    sequence_length, offset = _der_length(signature, 1)
    if offset + sequence_length != len(signature):
        raise AppStoreConnectError("Invalid ECDSA signature sequence length")

    components: list[bytes] = []
    for _ in range(2):
        if offset >= len(signature) or signature[offset] != 0x02:
            raise AppStoreConnectError("Invalid ECDSA signature integer")
        integer_length, offset = _der_length(signature, offset + 1)
        integer = signature[offset : offset + integer_length]
        offset += integer_length
        integer = integer.lstrip(b"\x00")
        if len(integer) > component_size:
            raise AppStoreConnectError("ECDSA signature integer is too large")
        components.append(integer.rjust(component_size, b"\x00"))

    if offset != len(signature):
        raise AppStoreConnectError("Unexpected trailing ECDSA signature data")
    return b"".join(components)


def create_token(
    key_id: str,
    issuer_id: str,
    private_key_base64: str,
    now: int | None = None,
) -> str:
    issued_at = int(time.time()) if now is None else now
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    payload = {
        "iss": issuer_id,
        "iat": issued_at,
        "exp": issued_at + 600,
        "aud": "appstoreconnect-v1",
    }
    signing_input = (
        f"{_base64url(json.dumps(header, separators=(',', ':')).encode())}."
        f"{_base64url(json.dumps(payload, separators=(',', ':')).encode())}"
    )

    try:
        private_key = base64.b64decode(private_key_base64, validate=True)
    except (ValueError, binascii.Error) as error:
        raise AppStoreConnectError(
            "ASC_PRIVATE_KEY_BASE64 is not valid base64"
        ) from error

    key_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile("wb", prefix="asc-key-", delete=False) as key_file:
            key_file.write(private_key)
            key_path = Path(key_file.name)
        key_path.chmod(0o600)

        result = subprocess.run(
            [
                "/usr/bin/openssl",
                "dgst",
                "-sha256",
                "-sign",
                str(key_path),
            ],
            input=signing_input.encode("ascii"),
            capture_output=True,
            check=False,
        )
        if result.returncode != 0:
            detail = result.stderr.decode("utf-8", errors="replace").strip()
            raise AppStoreConnectError(f"Could not sign App Store Connect token: {detail}")
    finally:
        if key_path is not None:
            key_path.unlink(missing_ok=True)

    signature = _base64url(_der_signature_to_jose(result.stdout))
    return f"{signing_input}.{signature}"


class AppStoreConnectClient:
    def __init__(self, token: str) -> None:
        self.token = token

    def _request_json(
        self,
        method: str,
        path: str,
        body: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        encoded_body = None
        headers = {
            "Authorization": f"Bearer {self.token}",
            "Accept": "application/json",
        }
        if body is not None:
            encoded_body = json.dumps(body, separators=(",", ":")).encode("utf-8")
            headers["Content-Type"] = "application/json"

        request = urllib.request.Request(
            f"{API_BASE_URL}{path}",
            data=encoded_body,
            headers=headers,
            method=method,
        )
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                payload = response.read()
        except urllib.error.HTTPError as error:
            payload = error.read().decode("utf-8", errors="replace")
            detail = payload
            try:
                parsed = json.loads(payload)
                messages = [
                    item.get("detail") or item.get("title")
                    for item in parsed.get("errors", [])
                ]
                detail = "; ".join(message for message in messages if message) or payload
            except json.JSONDecodeError:
                pass
            raise AppStoreConnectError(
                f"App Store Connect API returned HTTP {error.code}: {detail}",
                status=error.code,
            ) from error
        except urllib.error.URLError as error:
            raise AppStoreConnectError(
                f"Could not reach App Store Connect API: {error.reason}"
            ) from error

        if not payload:
            return {}
        return json.loads(payload)

    def find_app_id(self, bundle_id: str) -> str:
        query = urllib.parse.urlencode({"filter[bundleId]": bundle_id, "limit": 2})
        response = self._request_json("GET", f"/apps?{query}")
        apps = response.get("data", [])
        if len(apps) != 1:
            raise AppStoreConnectError(
                f"Expected one App Store app for bundle ID {bundle_id}; found {len(apps)}"
            )
        return apps[0]["id"]

    def find_version(
        self, app_id: str, version: str, platform: str
    ) -> dict[str, Any] | None:
        query = urllib.parse.urlencode(
            {
                "filter[versionString]": version,
                "filter[platform]": platform,
                "limit": 2,
            }
        )
        response = self._request_json(
            "GET",
            f"/apps/{urllib.parse.quote(app_id)}/appStoreVersions?{query}",
        )
        for item in response.get("data", []):
            attributes = item.get("attributes", {})
            if (
                attributes.get("versionString") == version
                and attributes.get("platform") == platform
            ):
                return item
        return None

    def ensure_version(
        self,
        app_id: str,
        version: str,
        platform: str,
    ) -> tuple[dict[str, Any], bool]:
        existing = self.find_version(app_id, version, platform)
        if existing is not None:
            return existing, False

        body = {
            "data": {
                "type": "appStoreVersions",
                "attributes": {
                    "platform": platform,
                    "versionString": version,
                    "releaseType": "MANUAL",
                    "usesIdfa": False,
                },
                "relationships": {
                    "app": {"data": {"type": "apps", "id": app_id}}
                },
            }
        }
        try:
            response = self._request_json("POST", "/appStoreVersions", body)
            return response["data"], True
        except AppStoreConnectError as error:
            # Two concurrent archive actions may both pass the first lookup.
            if error.status == 409:
                existing = self.find_version(app_id, version, platform)
                if existing is not None:
                    return existing, False
            raise


def _required_environment(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise AppStoreConnectError(f"Missing required environment variable: {name}")
    return value


def ensure_version_command(arguments: argparse.Namespace) -> None:
    if not VERSION_PATTERN.fullmatch(arguments.version):
        raise AppStoreConnectError(
            f"Invalid App Store version '{arguments.version}'; expected 1, 1.1, or 1.1.1"
        )

    token = create_token(
        _required_environment("ASC_KEY_ID"),
        _required_environment("ASC_ISSUER_ID"),
        _required_environment("ASC_PRIVATE_KEY_BASE64"),
    )
    client = AppStoreConnectClient(token)
    app_id = arguments.app_id or client.find_app_id(arguments.bundle_id)
    version, created = client.ensure_version(app_id, arguments.version, arguments.platform)
    action = "Created" if created else "Found existing"
    print(
        f"{action} App Store version {arguments.version} "
        f"for {arguments.platform} (id: {version['id']})"
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    ensure_parser = subparsers.add_parser("ensure-version")
    ensure_parser.add_argument("--version", required=True)
    ensure_parser.add_argument("--bundle-id", required=True)
    ensure_parser.add_argument("--app-id")
    ensure_parser.add_argument(
        "--platform",
        default="IOS",
        choices=("IOS", "MAC_OS", "TV_OS", "VISION_OS"),
    )
    ensure_parser.set_defaults(handler=ensure_version_command)
    return parser


def main() -> int:
    try:
        arguments = build_parser().parse_args()
        arguments.handler(arguments)
    except AppStoreConnectError as error:
        print(f"error: {error}", file=os.sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
