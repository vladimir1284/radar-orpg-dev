# ORPG install trace

Following `v1_setup_code_b24_0r1_20.md` (Volume 1, Document 1), Public Edition, adapted for the container described in [Container setup](container-setup.md). Steps are logged here as they're actually run — this page reflects real command output, not the plan.

## Source files

Both present on the host (same content in two locations, use either):

- `.../Podman/data/input/CODERPG Build 24.020260715033855/`
- `.../CODE/24/CODERPG Build 24.020260715033855/`

Key files: `rpg_b24_0r1_20_pub_src.tgz` (extracts flat into `$HOME`: `conf/`, `src/`, `make_rpg`, `install_rpg`, ...), `code_config_b24_0r1_20.tgz` (extracts to `$HOME/code_config_b24_0r1_20/{env,orpg}`).

## Dependency gap vs. the doc

The doc's own package list (`giflib-devel`, `ncompress`, plus `tcl-devel`/`tk-devel`/`gsl`/`gsl-devel` for the **NWS-only** MIGFA algorithm) assumes a full RHEL8 "Workstation" install where a C/C++/Fortran toolchain and GUI dev libraries are already present. The Kasm desktop container has neither. Confirmed by grepping the actual makefiles under `conf/` for `pkg-config`/`-l` flags (not guessed):

```
$ grep -rhoE "pkg-config --[a-z]+ [a-zA-Z0-9._+-]+" conf/ | sort -u
pkg-config --cflags gtk+-2.0
pkg-config --cflags gtk+-3.0
pkg-config --cflags libgtop-2.0
pkg-config --cflags libnsl
pkg-config --cflags libtirpc
```

`inst_env_config` and `inst_orpg_config` are `#!/usr/bin/ksh` — `ksh` is a hard requirement, not optional (the doc never mentions it because a full Workstation install includes it).

Full package list installed (all confirmed available in the container's repos: baseos/appstream/powertools/epel):

```
gcc gcc-c++ gcc-gfortran ksh tcsh giflib-devel ncompress \
  libtirpc-devel libnsl2-devel gtk2-devel gtk3-devel libgtop2-devel
```

(`pkg-config` itself was already present in the base image.)

## Step log

### 1. Install compile dependencies (root)

```bash
podman exec --user root rocky8-radar-dev bash -c \
  'dnf install -y gcc gcc-c++ gcc-gfortran ksh tcsh giflib-devel ncompress libtirpc-devel libnsl2-devel gtk2-devel gtk3-devel libgtop2-devel'
```

Status: **in progress**.

### 2. Extract source archives

Pending.

### 3. `inst_env_config`

Pending.

### 4. Quick test compile (`test_make_cpc100`)

Pending.

### 5. Full build (`make_rpg`)

Pending — takes ~15 minutes per the doc.

### 6. `inst_orpg_config` (Public edition)

Pending.

### 7. Fix `.rssd.conf` `Client:`

The doc's default `.rssd.conf` ships with `Client: rpg`, relying on a `rpg` hostname alias in `/etc/hosts` that doesn't exist in this container. Needs to be set to the container's actual hostname/IP. Pending — value not yet determined.

### 8. Start and verify (`mrpg`, `rpg_ps`)

Pending.
