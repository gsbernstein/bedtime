from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec

from scripts.xcode_cloud.asc_auth import AscCredentials, create_asc_token


def _generate_test_key() -> str:
    private_key = ec.generate_private_key(ec.SECP256R1())
    return private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    ).decode()


def test_create_asc_token_contains_expected_claims():
    credentials = AscCredentials(
        key_id="KEY123",
        issuer_id="issuer-uuid",
        private_key=_generate_test_key(),
    )

    token = create_asc_token(credentials, expiration_seconds=600)

    assert isinstance(token, str)
    assert token.count(".") == 2
