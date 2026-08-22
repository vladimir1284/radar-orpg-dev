# Container setup

## Creation

The dev container is created with (see `script.sh.example` in the repo root — the real `script.sh` has a live VNC password and is gitignored, copy the example and edit it):

```bash
podman run -d \
  --name rocky8-radar-dev \
  -p 6901:6901 \
  --shm-size=2g \
  -e VNC_PW=CHANGE_ME \
  -v ./data:/home/kasm-user \
  kasmweb/rockylinux-8-desktop:1.15.0
```

Image: `kasmweb/rockylinux-8-desktop:1.15.0` — Rocky Linux 8.9, a Kasm interactive-desktop image (KasmVNC + XFCE), **not** a purpose-built ORPG build image. It's being used here as a convenient Rocky 8 sandbox with a GUI (useful for `hci`/`cvg` later), everything ORPG-specific is bolted on manually.

VNC web access: `https://<host>:6901`, user `kasm_user` (password from `VNC_PW`), view-only user `kasm_viewer` / `vncviewonlypassword` (image default).

## uid mapping gotcha (rootless podman)

This is rootless podman. Inside the container, `kasm-user` is uid 1000. Rootless podman's default subuid map puts container uid 1000 at **host uid 100999** (subuid range starts at host 100000; container uid *N* → host `100000 + N - 1`).

The bind-mounted `./data` dir was created owned by the host user's real uid (1000), which does **not** match 100999 — so the container's entrypoint (which copies a default profile into `$HOME` on every start) failed with `Permission denied` on every file and the container exited immediately (`exit=1`).

Fix — remap ownership from *inside* the user namespace, not a literal host chown:

```bash
podman unshare chown -R 1000:1000 ./data
podman start rocky8-radar-dev
```

`podman unshare chown 1000:1000` here means "uid 1000 as seen from inside the container's namespace", which `podman unshare` translates to host uid 100999 automatically.

**Consequence for anything written later:** any file created on the host side of the bind mount by a non-podman-unshare process will again be owned by the wrong uid from the container's point of view. When adding files to `./data` from the host directly, either write them from inside the container (`podman exec`) or re-run the `podman unshare chown` afterwards.

## What survives, what doesn't

- `$HOME=/home/kasm-user` is bind-mounted to `./data` — survives container stop/start/recreate.
- Anything installed with `dnf` (compilers, dev libraries, `ksh`, `tcsh`, ...) lives in the container's writable layer — **lost if the container is ever removed and recreated**, only survives stop/start. There is no Containerfile yet baking these in; see [Production image plan](production-image.md).
