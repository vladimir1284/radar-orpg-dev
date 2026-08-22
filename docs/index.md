# ORPG CODE B24 on Podman

Trace of getting the WSR-88D **Open RPG (ORPG)**, **CODE B24.0r1.20 (Public Edition)**, compiled and running inside a Podman container, and the plan to turn that into a proper production image.

Source docs (not included in this repo — see [Container setup](container-setup.md) for where they live on disk):

- `v1_setup_code_b24_0r1_20.md` — official Volume 1 setup guide, converted to Markdown, at the project root.
- `rpg_b24_0r1_20_pub_src.tgz` / `code_config_b24_0r1_20.tgz` — the actual ORPG Public Edition source and CODE customization archives.

## Why this exists

The official install doc assumes a bare-metal Intel PC running a full Red Hat Enterprise 8 **Workstation** install, with development tools and GUI libraries already present, and a C-shell (`csh`) account. None of that matches a minimal Kasm desktop container running as a non-root, rootless-podman user. This repo tracks every deviation made to get the same result in that environment, so it can be turned into a repeatable Containerfile later (see [Production image plan](production-image.md)).

## Status

See [ORPG install trace](orpg-install.md) for the current state of each step.
