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

## `inst_env_config` breaks the Kasm desktop on restart

After the ORPG install, the container ran fine until its first restart, then exited within seconds:

```
Can't exec "/bin/../builder/startup/deb/select-de.sh": No such file or directory at /bin/vncserver line 828.
Failed to execute /bin/../builder/startup/deb/select-de.sh --select-de manual
```

Chain of causes:

1. `inst_env_config` ([install step 3](orpg-install.md#3-inst_env_config)) replaces `$HOME/.bashrc`. Kasm's original only did `source $STARTUPDIR/generate_container_user`; it survives as `.bashrc.OLD`. The ORPG one does `. ~/.bash_profile`, whose `PATH` starts with `/bin`.
2. Kasm's `/dockerstartup/vnc_startup.sh` sources `$HOME/.bashrc` before launching `vncserver`, so `vncserver` now resolves as `/bin/vncserver` instead of `/usr/bin/vncserver` (on Rocky, `/bin` is a symlink to `/usr/bin`: same file, different `$0`).
3. KasmVNC's `vncserver` (Perl) picks the location of `select-de.sh` from `$0`: if it starts with `/usr` it uses the installed `/usr/lib/kasmvncserver/select-de.sh`, otherwise it assumes a source checkout and looks in `$(dirname $0)/../builder/startup/deb/`, which doesn't exist.

Because `$HOME` is the bind mount, the change lives on the host side and survives recreating the container. Fix, appended to `data/.bashrc`:

```bash
# Kasm: restore the container's own startup hook, replaced by inst_env_config.
source $STARTUPDIR/generate_container_user
# Kasm's vncserver locates select-de.sh only when invoked from /usr/...; .bash_profile puts /bin first.
PATH=/usr/bin:$PATH
```

Putting `/usr/bin` first is a no-op for ORPG (same directory as `/bin`); `ORPGDIR` and `mrpg` still resolve. **Re-running `inst_env_config` overwrites `.bashrc` again** — re-append these lines afterwards.

## What survives, what doesn't

- `$HOME=/home/kasm-user` is bind-mounted to `./data` — survives container stop/start/recreate.
- Anything installed with `dnf` (compilers, dev libraries, `ksh`, `tcsh`, ...) lives in the container's writable layer — **lost if the container is ever removed and recreated**, only survives stop/start. The dev container is still set up by hand; the [Production image](production-image.md) is the reproducible build.
