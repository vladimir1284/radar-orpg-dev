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

Status: **done**. All 12 confirmed via `rpm -q`.

### 2. Extract source archives

```bash
podman exec rocky8-radar-dev bash -c '
cd $HOME
tar xzf "input/CODERPG Build 24.020260715033855/rpg_b24_0r1_20_pub_src.tgz"
tar xzf "input/CODERPG Build 24.020260715033855/code_config_b24_0r1_20.tgz"
'
```

Status: **done**. Created `$HOME/{conf,src,make_rpg,install_rpg,...}` and `$HOME/code_config_b24_0r1_20/{env,orpg}`.

### 3. `inst_env_config`

```bash
podman exec rocky8-radar-dev bash -c 'cd $HOME/code_config_b24_0r1_20/env && echo y | ./inst_env_config'
```

Status: **done**. Replaced 9 config files (`make_rpg`, `test_make_cpc100`, `.cshrc`, `build_env_cshrc`, `orpg_env_cshrc`, `.bashrc`, `.bash_profile`, `build_env_profile`, `orpg_env_profile`) and 9 makefiles under `src/`.

Key env vars from `orpg_env_profile`/`build_env_profile` (both sourced by `.bash_profile`, which is why every build/run command below uses `bash -lc`):

- `ORPGDIR=$HOME/data`, `CFG_DIR=$HOME/cfg`, `RMTPORT=50000` (single instance, no change needed)
- `ARCH=lnux_x86`, `level=$HOME`, `MAKETOP=$HOME`, `LOCALTOP=$HOME`
- `PATH` gets `$HOME/bin`, `$HOME/bin/lnux_x86`, `$HOME/tools/bin`, etc. prepended

### 4. Quick test compile (`test_make_cpc100`)

```bash
podman exec rocky8-radar-dev bash -lc 'cd $HOME && ./test_make_cpc100 $HOME > test_compile.log 2>&1; echo EXIT=$?'
```

Status: **done**. `EXIT=0`, 978-line log, zero `Error` matches, ends with `libinfr.a` built and installed cleanly.

### 5. Full build (`make_rpg`)

```bash
podman exec rocky8-radar-dev bash -lc 'cd $HOME && ./make_rpg $HOME > make_rpg.log 2>&1; echo EXIT=$?'
```

Status: **done**, after 3 passes. `make_rpg`'s own exit code was `0` even on the first pass with build errors inside — it doesn't propagate sub-make failures, so **grep the log for `Error`/`fatal error`, don't trust the exit code.**

First pass: 356 `*** [...] Error` lines, all root-caused to missing dev headers for optional GUI/utility tools (the core algorithm/task tree — `mrpg`, `rpg_ps`, `play_a2`, the `cpc1xx` tasks — built and installed clean on the first pass):

| Missing header | Tool affected | Package |
|---|---|---|
| `Xm/Xm.h` | `hci` (operator GUI), `cvg`/`edit_cvgplt`/`map_cvg` (CODEView Graphics) | `motif-devel` |
| `curses.h` | `diom_config` | `ncurses-devel` |
| `libxml/parser.h` | `gdc_read_data` | `libxml2-devel` |
| `curl/curl.h` | `read_is` | `libcurl-devel` |
| `security/pam_appl.h` | `restore_adapt` | `pam-devel` |
| `glib.h` (via `pkg-config glib-2.0 libxml-2.0`) | `validate_a2` | fixed by installing `libxml2-devel` — `glib2-devel` was already present (pulled in by `gtk2/3-devel`), but `validate_a2`'s makefile calls `pkg-config --cflags glib-2.0 libxml-2.0` in one shot; with `libxml-2.0.pc` missing, `pkg-config` failed the whole call and silently dropped the glib cflags too |

```bash
podman exec --user root rocky8-radar-dev bash -c \
  'dnf install -y motif-devel ncurses-devel libxml2-devel libcurl-devel pam-devel'
```

Second pass (incremental — `make` only rebuilds what previously failed, not a full 15-min rebuild): down to 12 error lines, two new root causes:

| Missing header | Tool affected | Package |
|---|---|---|
| `gd.h` | `gif_output` (CVG) | `gd-devel` |
| `crack.h` | `rpg_admin_user_gui*` (password strength check) | `cracklib-devel` |

```bash
podman exec --user root rocky8-radar-dev bash -c 'dnf install -y gd-devel cracklib-devel'
```

Third pass: **0 errors, 0 fatal errors.** Confirmed binaries present: `$HOME/bin/lnux_x86/{mrpg,rpg_ps,hci}`, `$HOME/tools/bin/lnux_x86/{cvg,play_a2}`.

Full additional package list beyond the [dependency gap](#dependency-gap-vs-the-doc) list, discovered only by actually compiling:
`motif-devel ncurses-devel libxml2-devel libcurl-devel pam-devel gd-devel cracklib-devel`

One harmless line at the very end of every pass: `SUBDIRECTORY orda DOES NOT EXIST!` — the `orda` (RDA-related) source subdirectory isn't part of this distribution; not an error, nothing under `src/` references it as required.

### 6. `inst_orpg_config` (Public edition)

```bash
podman exec rocky8-radar-dev bash -c 'cd $HOME/code_config_b24_0r1_20/orpg && printf "y\nP\n" | ./inst_orpg_config'
```

Status: **done**. Installed `cfg/comms_link.conf`, `.rssd.conf`, `tools/bin/rm_orpg_data`, `cfg/version_rpg`, `cfg/task_tables.{public,nws}_code` (Public chosen → copied to `cfg/task_tables`), site adaptation set to **KMLB** (Melbourne, FL — the sample site), default NWS blockage file, and 3 sample Archive II files for KMLB into `$HOME/ar2data`.

### 7. Fix `.rssd.conf` `Client:`

Podman auto-adds a hosts alias for the container name — `/etc/hosts` already had `10.0.2.100 f727d7728315 rocky8-radar-dev` before any manual edit. So instead of hardcoding the (potentially-changing) IP, pointed `Client:` at the stable container-name alias:

```bash
podman exec rocky8-radar-dev bash -c "sed -i 's/^Client: rpg/Client: rocky8-radar-dev/' \$HOME/.rssd.conf"
```

Status: **done**.

### 8. Start and verify (`mrpg`, `rpg_ps`)

```bash
podman exec rocky8-radar-dev bash -lc 'cd $HOME && mrpg -p -v startup'
```

Status: **done**.
```
RPG State: OPERATE
RPG Operability Status: ONLINE
RPG System Startup Completed
```

`rpg_ps` confirms **109 processes** running (algorithm tasks, product generators, `hci_agent`, `control_rda`, etc.).

## Result

The ORPG (Public Edition, CODE B24.0r1.20) is compiled and running end to end inside `rocky8-radar-dev`. Not yet done (optional, not required for "running"): ingest test data (`play_a2 -d $HOME/ar2data`), clean shutdown (`mrpg shutdown && mrpg cleanup`). See [Production image plan](production-image.md) for turning this manual trace into a real Containerfile.

## GUI (`hci`, `cvg`) — missing X11 core fonts

Launching `hci` from the VNC desktop failed with:

```
Warning: Cannot convert string "-*-courier-bold-r-*-*-*-100-100-100-*-*-iso8859-1" to type FontStruct
X Error of failed request:  BadName (named color or font does not exist)
```

Motif apps (`hci`, `cvg`) need the classic X11 core bitmap fonts, which a minimal Rocky8/Kasm image doesn't ship at all (`rpm -qa | grep xorg-x11-fonts` was empty). Fix:

```bash
podman exec --user root rocky8-radar-dev bash -c \
  'dnf install -y xorg-x11-fonts-100dpi xorg-x11-fonts-75dpi xorg-x11-fonts-ISO8859-1-100dpi xorg-x11-fonts-ISO8859-1-75dpi xorg-x11-fonts-misc xorg-x11-fonts-Type1'
DISPLAY=:1 xset fp rehash
```

No X server restart needed — the running KasmVNC `Xvnc` picks up the new `/etc/X11/fontpath.d` catalogue entries after `xset fp rehash`. Verified with a screenshot (`xwd -root | convert - png:-`, needs `xorg-x11-apps` + `ImageMagick`, also not present by default): `hci`'s RPG Control/Status panel renders cleanly, KMLB site, `Wideband Line has FAILED` / `RDA <-> RPG COMMUNICATIONS LINK BROKEN` alarms shown — expected, matches the doc's note that a Wideband Link Failure warning is normal without a real RDA connection.

Add to the production-image dependency list if GUI tools are needed there: `xorg-x11-fonts-100dpi xorg-x11-fonts-75dpi xorg-x11-fonts-ISO8859-1-100dpi xorg-x11-fonts-ISO8859-1-75dpi xorg-x11-fonts-misc xorg-x11-fonts-Type1`.

### 7. Fix `.rssd.conf` `Client:`

The doc's default `.rssd.conf` ships with `Client: rpg`, relying on a `rpg` hostname alias in `/etc/hosts` that doesn't exist in this container. Needs to be set to the container's actual hostname/IP. Pending — value not yet determined.

### 8. Start and verify (`mrpg`, `rpg_ps`)

Pending.
