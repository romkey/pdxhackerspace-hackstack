#!/usr/bin/env python
"""Entrypoint: render the runtime Olah config from .env settings, then start Olah.

With --workers > 1 Olah's worker processes read only the config file, never the
command line, so the host-specific settings (mirror URL, cache path, ...) have
to be in the file. This overlays them from the environment onto the policy in
/app/configs.toml and writes the result to /tmp/configs.toml.
"""
import os
import toml

SRC = "/app/configs.toml"
DST = "/tmp/configs.toml"

netloc = os.environ["OLAH_MIRROR_NETLOC"]

config = toml.load(SRC)
basic = config.setdefault("basic", {})
basic.update(
    {
        "host": "0.0.0.0",
        "port": 8090,
        "repos-path": "/data/repos",
        "mirror-scheme": os.environ.get("OLAH_MIRROR_SCHEME", "https"),
        "mirror-netloc": netloc,
        # Olah serves LFS files itself, so they use the same address
        "mirror-lfs-netloc": netloc,
        "cache-size-limit": os.environ.get("OLAH_CACHE_SIZE_LIMIT", ""),
    }
)

with open(DST, "w") as f:
    toml.dump(config, f)

workers = os.environ.get("OLAH_WORKERS", "1")
os.execvp(
    "olah-cli",
    ["olah-cli", "--config", DST, "--workers", workers, "--log-path", "/logs"],
)
