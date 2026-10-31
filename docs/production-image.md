# Production image

The manual trace in [ORPG install trace](orpg-install.md) is now a reproducible multi-stage image: `prod/Containerfile` + `prod/entrypoint.sh`. It builds the ORPG from the CODE source zip with no manual step, starts it to **RPG State: OPERATE / ONLINE** as the container's main process, and shuts it down cleanly on `docker stop`.

Built locally for `linux/amd64` and `linux/arm64` and pushed to a **private** GHCR package (see [Publishing](#publishing-local-build-private-ghcr)). Verified end to end on amd64 only; [arm64](#arm64-armv82) is pending validation.

## Why not ship `rocky8-radar-dev` as-is

- Base image (`kasmweb/rockylinux-8-desktop`) is built for interactive VNC desktop use: XFCE, KasmVNC, audio/printer/gamepad services, a profile-copy entrypoint — none of it relevant to running the ORPG as a service.
- Dependencies were installed by hand via `dnf` inside a running container — not reproducible.
- The ORPG source tree was built directly into a bind-mounted `$HOME`, not baked into an image layer.

## Build

The build context is the repo root, which must contain the `CODERPG Build ... .zip` (gitignored; `.dockerignore` lets only the zip and `prod/entrypoint.sh` into the context):

```bash
docker build -f prod/Containerfile -t orpg-prod:b24 .
```

### Build stage (`rockylinux:8`)

Same steps as the manual trace, made non-interactive:

1. Toolchain + every `-devel` package the real build needed (the makefile grep alone misses half of them — see [Dependency gap](orpg-install.md#dependency-gap-vs-the-doc) and [Full build](orpg-install.md#5-full-build-make_rpg)):

    ```
    gcc gcc-c++ gcc-gfortran ksh tcsh giflib-devel ncompress \
      libtirpc-devel libnsl2-devel gtk2-devel gtk3-devel libgtop2-devel \
      motif-devel ncurses-devel libxml2-devel libcurl-devel pam-devel \
      gd-devel cracklib-devel
    ```

2. Unzip, extract `rpg_b24_0r1_20_pub_src.tgz` + `code_config_b24_0r1_20.tgz` into `/home/orpg` (user `orpg`, uid 1000).
3. `echo y | ./inst_env_config`. From here on every `RUN` uses `SHELL ["/bin/bash", "-lc"]` so `.bash_profile` provides `ORPGDIR`, `ARCH`, `PATH`, ...
4. On aarch64 only: add `-fsigned-char` to the C/C++ flags (see [arm64](#arm64-armv82)).
5. `./make_rpg $HOME`. **`make_rpg` exits 0 even when sub-makes fail**, so the step greps its log for `*** [...] Error` / `fatal error` and fails the build itself.
6. `printf 'y\nP\n' | ./inst_orpg_config` — Public edition, KMLB sample site.
7. Delete `src/`, the zip, the extracted archives and the build log.

### Runtime stage (`rockylinux:8`)

Only the runtime libraries (no compilers, no `-devel`), plus the compiled `/home/orpg` copied from the build stage. The GUI libraries (`motif gtk2 gtk3 libgtop2`) are still included so `hci`/`cvg` binaries can load. The X11 core fonts they need to actually render ([GUI fonts](orpg-install.md#gui-hci-cvg--missing-x11-core-fonts)) are **not** — this image is headless.

Result: **437 MB** (amd64): 131 MB of runtime packages + 108 MB of compiled ORPG tree on top of the Rocky 8 base.

## Run

```bash
docker login ghcr.io             # the package is private
docker run -d --name orpg-prod --hostname orpg-prod --stop-timeout 30 ghcr.io/vladimir1284/orpg:b24
docker logs -f orpg-prod      # ends with "RPG startup completed"
```

- `--hostname` should be pinned: `entrypoint.sh` writes `$(hostname)` into `.rssd.conf`'s `Client:` on every start, which is how the [manual `Client:` fix](orpg-install.md#7-fix-rssdconf-client) is automated.
- `--stop-timeout 30`: see [Shutdown](#shutdown).
- No volumes or ports. `mrpg -p startup` cleans every data store on start, so the container is stateless by design: removing and recreating it loses nothing.

### Startup

`entrypoint.sh` sources `.bash_profile`, runs `mrpg -p -v startup`, prints its log, then waits. Verified on amd64:

```
RPG State: OPERATE
RPG Operability Status: ONLINE
RPG System Startup Completed
```

Startup takes about 10 s. `rpg_ps` lists **107 tasks**; 114 processes in the container overall.

### Shutdown

`mrpg shutdown` only **sends** the command to the `mrpg` daemon and returns immediately. The operational tasks take about 7 s to actually exit afterwards. The first version of `entrypoint.sh` called `exit 0` right after the command, so PID 1 ended and Docker killed every task mid-shutdown — `docker stop` "succeeded" in 1 s with exit code 0, hiding it.

The entrypoint now waits (up to 25 s) until only the infrastructure daemons remain. `rssd`, `mrpg`, `owr_server` and `nds` stay up by design after an ORPG shutdown, so they are excluded from the wait. Docker's default stop timeout is 10 s, close to the ~7 s the shutdown needs, hence `--stop-timeout 30`.

Verified: `docker stop` → about 5 s → exit code 0 → `docker start` → ONLINE again.

## arm64 (ARMv8.2)

Status: **pending validation** — prepared, not yet built or run on arm64.

What's in place, from reading the source (not from a build):

- No x86-specific code: no inline assembly, no `-m32`/`-march`. `lnux_x86` is only the name of the `ARCH` directory and `conf/make.lnux_x86`; its flags are plain `gcc`/`gfortran`.
- `LINUX_OS=$(uname -i)` (from `orpg_env_profile`) only distinguishes `x86_32` from everything else, so aarch64 takes the `RPG_OS64` path, same as x86_64.
- The code assumes `LITTLE_ENDIAN_MACHINE`; Linux on aarch64 is little-endian.
- **`char` signedness** is the main expected risk: unsigned by default on aarch64, signed on x86. The Containerfile adds `-fsigned-char` to the C/C++ flags on aarch64 only, keeping x86 semantics without touching the source.
- No `-march`, so gcc targets baseline ARMv8-A, which runs on any ARMv8.2 CPU (Graviton2, Ampere Altra, Cortex-A76/Raspberry Pi 5, ...).
- Every package in both stages exists for aarch64 in Rocky 8 + EPEL; `rockylinux:8` is multi-arch. Expected, not verified by a build.

Possible failures still unknown until a real build: legacy code that treats `va_list` as a pointer (a struct on aarch64, compile error) and Fortran/C interop assumptions. A local QEMU build was started and cancelled; emulated, it was still installing packages after 10 minutes.

### To validate (on a native arm64 machine)

```bash
uname -m                                   # aarch64
docker build -f prod/Containerfile -t orpg-prod:b24-arm64 .   # repo root with the CODE zip
docker run -d --name orpg-prod --hostname orpg-prod --stop-timeout 30 orpg-prod:b24-arm64
docker logs -f orpg-prod                   # expect OPERATE / ONLINE / "RPG startup completed"
docker exec orpg-prod bash -lc 'rpg_ps | grep -c "^ \+[A-Za-z_0-9]\+ \+[0-9]\+ "'   # amd64: 107
time docker stop orpg-prod                 # expect a few seconds
docker inspect orpg-prod --format '{{.State.ExitCode}}'   # expect 0
```

Also worth checking that no task died after startup (the task count above matching amd64), since a signedness or alignment bug is more likely to crash a task at runtime than to break the build. If it passes, publish it as the arm64 half of the tag: see [Publishing](#publishing-local-build-private-ghcr).

## Publishing: local build, private GHCR

The image contains the compiled ORPG plus its config files and scripts, so it's ORPG redistribution: **the GHCR package stays private**. This repo is public and only holds our own work (notes, `prod/`), so there's no CI here: a public workflow would need the CODE zip, and its build cache and logs would live in a public repo. Each architecture is built natively on its own machine and pushed by hand.

Needs a token with `write:packages` (`gh auth refresh -s write:packages,read:packages`, then `gh auth token | docker login ghcr.io -u <user> --password-stdin`). Repo root must contain the CODE zip.

```bash
# on the amd64 machine
docker build -f prod/Containerfile -t ghcr.io/vladimir1284/orpg:b24-amd64 .
docker push ghcr.io/vladimir1284/orpg:b24-amd64

# on the arm64 machine, after the validation above passes
docker build -f prod/Containerfile -t ghcr.io/vladimir1284/orpg:b24-arm64 .
docker push ghcr.io/vladimir1284/orpg:b24-arm64

# on either: one multi-arch tag, docker pull picks the architecture
docker buildx imagetools create -t ghcr.io/vladimir1284/orpg:b24 \
  ghcr.io/vladimir1284/orpg:b24-amd64 ghcr.io/vladimir1284/orpg:b24-arm64
```

A new package pushed this way is private by default. Check it under **Your profile → Packages → orpg → Package settings**: visibility *Private*, and don't link it to this repo. A linked package can take its permissions from the repo.
