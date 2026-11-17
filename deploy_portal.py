#!/usr/bin/env python3
"""
HUNOR Webportál (https://hun01usar.hu) Élesítő Szkript (macOS / Linux / Windows)
Használat Mac-en:
  python3 deploy_portal.py
"""
import hashlib
import json
import os
import ssl
import sys
import time
import urllib.request
from pathlib import Path

SITE_ID = "e3cb84ef-0c83-4ac4-9f2e-472f14a76369"
ROOT_DIR = Path(__file__).resolve().parent
PORTAL_DIR = ROOT_DIR / "portal"
TOKEN_FILE = ROOT_DIR / ".netlify-token"


def get_token() -> str:
    token = os.environ.get("NETLIFY_AUTH_TOKEN", "").strip()
    if not token and TOKEN_FILE.exists():
        token = TOKEN_FILE.read_text(encoding="utf-8").strip()
    if not token:
        print("HIBA: Hiányzik a Netlify token!")
        print("Hozd létre a '.netlify-token' fájlt a projekt gyökerében, vagy állítsd be a NETLIFY_AUTH_TOKEN környezeti változót.")
        sys.exit(1)
    return token


def api_request(url: str, method: str, token: str, data: bytes = None, content_type: str = "application/json"):
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {token}")
    if data is not None:
        req.add_header("Content-Type", content_type)
    ctx = ssl._create_unverified_context()
    with urllib.request.urlopen(req, context=ctx) as resp:
        return json.loads(resp.read().decode("utf-8"))


def main():
    if not PORTAL_DIR.exists():
        print(f"HIBA: Nem található a portal mappa: {PORTAL_DIR}")
        sys.exit(1)

    token = get_token()
    sha_map = {}
    file_objects = {}

    for path in PORTAL_DIR.rglob("*"):
        if path.is_file():
            rel = "/" + path.relative_to(PORTAL_DIR).as_posix()
            sha1 = hashlib.sha1(path.read_bytes()).hexdigest().lower()
            sha_map[rel] = sha1
            file_objects[sha1] = path

    print(f"Fájlok száma a portal/ mappában: {len(sha_map)}")

    body = json.dumps({"files": sha_map}).encode("utf-8")
    deploy = api_request(
        f"https://api.netlify.com/api/v1/sites/{SITE_ID}/deploys",
        "POST",
        token,
        data=body,
    )

    deploy_id = deploy["id"]
    required = deploy.get("required", [])
    print(f"Deploy létrehozva: {deploy_id} (Feltöltendő módosult fájlok: {len(required)} db)")

    for sha in required:
        fpath = file_objects[sha]
        raw_bytes = fpath.read_bytes()
        api_request(
            f"https://api.netlify.com/api/v1/deploys/{deploy_id}/files/{sha}",
            "PUT",
            token,
            data=raw_bytes,
            content_type="application/octet-stream",
        )
        print(f"  ✓ Feltöltve: {fpath.relative_to(PORTAL_DIR)}")

    for _ in range(15):
        time.sleep(2)
        check = api_request(
            f"https://api.netlify.com/api/v1/sites/{SITE_ID}/deploys/{deploy_id}",
            "GET",
            token,
        )
        state = check.get("state")
        print(f"Állapot: {state}")
        if state == "ready":
            break

    pub = api_request(
        f"https://api.netlify.com/api/v1/sites/{SITE_ID}/deploys/{deploy_id}/restore",
        "POST",
        token,
        data=b"{}",
    )
    print(f"🎉 Sikeresen élesítve a https://hun01usar.hu oldalon! (Deploy ID: {pub.get('id')})")


if __name__ == "__main__":
    main()
