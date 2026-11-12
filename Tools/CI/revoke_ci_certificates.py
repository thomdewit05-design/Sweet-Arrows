#!/usr/bin/env python3
"""Revokes the development certificates that earlier CI builds created.

Every TestFlight run starts on a clean Mac, so Xcode's automatic signing creates a new
"Apple Development: Created via API" certificate each time, until the account hits Apple's
maximum and signing fails. This removes only those API-created development certificates;
distribution certificates and certificates made in Xcode on a Mac are left alone.

Needs: ASC_KEY_ID, ASC_ISSUER_ID and the .p8 key at ~/private_keys/AuthKey.p8
(pip install pyjwt cryptography).
"""
import json
import os
import sys
import time
import urllib.request

import jwt

API = "https://api.appstoreconnect.apple.com/v1"
DEVELOPMENT_TYPES = {"DEVELOPMENT", "IOS_DEVELOPMENT"}


def token():
    key = open(os.path.expanduser("~/private_keys/AuthKey.p8")).read()
    now = int(time.time())
    return jwt.encode(
        {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"},
        key, algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"},
    )


def call(method, url, auth):
    request = urllib.request.Request(url, method=method, headers={"Authorization": f"Bearer {auth}"})
    with urllib.request.urlopen(request) as response:
        body = response.read()
        return json.loads(body) if body else None


def main():
    auth = token()
    url = f"{API}/certificates?limit=200&fields[certificates]=name,displayName,certificateType,expirationDate"
    certificates = []
    while url:
        page = call("GET", url, auth)
        certificates += page["data"]
        url = page.get("links", {}).get("next")
    revoked = 0
    for certificate in certificates:
        attributes = certificate["attributes"]
        names = f"{attributes.get('name', '')} {attributes.get('displayName', '')}"
        if attributes.get("certificateType") in DEVELOPMENT_TYPES and "Created via API" in names:
            call("DELETE", f"{API}/certificates/{certificate['id']}", auth)
            revoked += 1
    kept = len(certificates) - revoked
    print(f"Revoked {revoked} development certificate(s) from earlier CI builds; {kept} left untouched.")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:  # never block the build on the cleanup itself
        print(f"::warning::Certificate cleanup skipped: {error}")
        sys.exit(0)
