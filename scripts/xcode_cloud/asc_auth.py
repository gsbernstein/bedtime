"""App Store Connect API JWT helpers."""

from __future__ import annotations

import time
from dataclasses import dataclass

import jwt


@dataclass(frozen=True)
class AscCredentials:
    key_id: str
    issuer_id: str
    private_key: str


def create_asc_token(
    credentials: AscCredentials,
    *,
    expiration_seconds: int = 1200,
) -> str:
    """Create a short-lived JWT for App Store Connect API requests."""
    now = int(time.time())
    headers = {"alg": "ES256", "kid": credentials.key_id, "typ": "JWT"}
    payload = {
        "iss": credentials.issuer_id,
        "iat": now,
        "exp": now + expiration_seconds,
        "aud": "appstoreconnect-v1",
    }
    return jwt.encode(payload, credentials.private_key, algorithm="ES256", headers=headers)


def credentials_from_env() -> AscCredentials:
    """Load App Store Connect credentials from standard environment variables."""
    import os

    key_id = os.environ.get("APP_STORE_CONNECT_KEY_ID")
    issuer_id = os.environ.get("APP_STORE_CONNECT_ISSUER_ID")
    private_key = os.environ.get("APP_STORE_CONNECT_PRIVATE_KEY")

    missing = [
        name
        for name, value in (
            ("APP_STORE_CONNECT_KEY_ID", key_id),
            ("APP_STORE_CONNECT_ISSUER_ID", issuer_id),
            ("APP_STORE_CONNECT_PRIVATE_KEY", private_key),
        )
        if not value
    ]
    if missing:
        raise ValueError(f"Missing required environment variables: {', '.join(missing)}")

    return AscCredentials(
        key_id=key_id,
        issuer_id=issuer_id,
        private_key=private_key.replace("\\n", "\n"),
    )
