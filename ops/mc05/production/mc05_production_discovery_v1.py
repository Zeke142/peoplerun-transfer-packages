#!/usr/bin/env python3
"""Resolve one immutable production MC05 invocation from GitHub Releases."""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.parse
import urllib.request


API_URL = "https://api.github.com/repos/Zeke142/peoplerun-transfer-packages/releases/latest"
ALLOWED_HOSTS = {"api.github.com", "github.com", "release-assets.githubusercontent.com"}
IDENTIFIER = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")


class DiscoveryStop(Exception):
    pass


def get_json(url: str) -> object:
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != "https" or parsed.hostname not in ALLOWED_HOSTS:
        raise DiscoveryStop("STOP_INVALID_DISCOVERY_URL")
    request = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json", "User-Agent": "PeopleRun-MC05"})
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.load(response)


def resolve() -> dict:
    release = get_json(API_URL)
    if not isinstance(release, dict) or release.get("draft") is True or release.get("prerelease") is True:
        raise DiscoveryStop("STOP_NO_PRODUCTION_RELEASE")
    tag = release.get("tag_name")
    if not isinstance(tag, str) or not IDENTIFIER.fullmatch(tag):
        raise DiscoveryStop("STOP_INVALID_RELEASE_IDENTITY")
    assets = release.get("assets")
    if not isinstance(assets, list):
        raise DiscoveryStop("STOP_INVALID_RELEASE_ASSETS")
    matches = [asset for asset in assets if isinstance(asset, dict) and asset.get("name") == "invocation.json"]
    if len(matches) != 1:
        raise DiscoveryStop("STOP_INVOCATION_ASSET_NOT_UNIQUE")
    url = matches[0].get("browser_download_url")
    if not isinstance(url, str):
        raise DiscoveryStop("STOP_INVOCATION_URL_MISSING")
    invocation = get_json(url)
    required = {"schema", "operation_id", "envelope_url", "expected_envelope_sha256", "expected_envelope_size_bytes"}
    if not isinstance(invocation, dict) or not required.issubset(invocation):
        raise DiscoveryStop("STOP_INVALID_INVOCATION")
    if invocation["schema"] != "peoplerun.mc05.shortcut_input.v2":
        raise DiscoveryStop("STOP_INVOCATION_SCHEMA")
    if invocation["operation_id"] != tag or not IDENTIFIER.fullmatch(str(invocation["operation_id"])):
        raise DiscoveryStop("STOP_INVOCATION_RELEASE_MISMATCH")
    return invocation


def main() -> int:
    try:
        print(json.dumps(resolve(), sort_keys=True, separators=(",", ":")))
        return 0
    except (DiscoveryStop, OSError, ValueError, json.JSONDecodeError) as exc:
        print(json.dumps({"status": "STOP", "code": str(exc) or type(exc).__name__}, sort_keys=True, separators=(",", ":")))
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
