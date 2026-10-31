# ORPG CODE B24 on Podman

Trace of getting the WSR-88D **Open RPG (ORPG)**, **CODE B24.0r1.20 (Public Edition)**, compiled and running inside a Podman container, and the production image built from that trace.

Third-party inputs — **not included in this repo and not redistributed by it** (gitignored; obtain them from the CODE distribution):

- `v1_setup_code_b24_0r1_20.md` — official Volume 1 setup guide, converted to Markdown, kept locally at the project root.
- `rpg_b24_0r1_20_pub_src.tgz` / `code_config_b24_0r1_20.tgz` — the actual ORPG Public Edition source and CODE customization archives.

## Why this exists

The official install doc assumes a bare-metal Intel PC running a full Red Hat Enterprise 8 **Workstation** install, with development tools and GUI libraries already present, and a C-shell (`csh`) account. None of that matches a minimal Kasm desktop container running as a non-root, rootless-podman user. This repo tracks every deviation made to get the same result in that environment, and those deviations are now baked into a repeatable Containerfile (see [Production image](production-image.md)).

## Status

- **Dev container** (`rocky8-radar-dev`, Kasm desktop): ORPG compiled and ONLINE; `hci`/`cvg` GUI verified. See [ORPG install trace](orpg-install.md) and [Container setup](container-setup.md).
- **Production image** (`prod/Containerfile`): builds unattended, starts to OPERATE/ONLINE as the container's main process, shuts down cleanly on `docker stop`. Built locally per architecture and pushed to a private GHCR package (it contains ORPG binaries); arm64 runtime validation still **pending**. See [Production image](production-image.md).
