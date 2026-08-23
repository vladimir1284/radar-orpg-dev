# Production image plan

Once the manual dev setup in [ORPG install trace](orpg-install.md) is fully verified (clean compile, `mrpg -p -v startup` succeeds, `rpg_ps` shows tasks up), replace the Kasm interactive-desktop container with a purpose-built production image.

## Why not ship `rocky8-radar-dev` as-is

- Base image (`kasmweb/rockylinux-8-desktop`) is built for interactive VNC desktop use: XFCE, KasmVNC, audio/printer/gamepad services, a profile-copy entrypoint — none of it relevant to running the ORPG as a service.
- Dependencies were installed by hand via `dnf` inside a running container (see [ORPG install trace](orpg-install.md)) — not reproducible, not in any Containerfile.
- The ORPG source tree was built directly into a bind-mounted `$HOME`, not baked into an image layer.

## Planned approach

1. **Base**: plain `rockylinux:8`, not the Kasm desktop image.
2. **Build-time deps** — full list, confirmed by actually compiling (see [ORPG install trace](orpg-install.md)), not just grepping makefiles: the makefile grep found `gtk2/3-devel`, `libgtop2-devel`, `libtirpc-devel`, `libnsl2-devel`; the real build additionally needed `motif-devel`, `ncurses-devel`, `libxml2-devel`, `libcurl-devel`, `pam-devel`, `gd-devel`, `cracklib-devel` for GUI/utility tools the makefile grep didn't surface (headers included directly, not via `pkg-config`):

   ```
   gcc gcc-c++ gcc-gfortran ksh tcsh giflib-devel ncompress \
     libtirpc-devel libnsl2-devel gtk2-devel gtk3-devel libgtop2-devel \
     motif-devel ncurses-devel libxml2-devel libcurl-devel pam-devel \
     gd-devel cracklib-devel
   ```

   Drop `gtk2-devel`/`gtk3-devel`/`libgtop2-devel`/`motif-devel`/`tcsh` from the runtime image if the GUI tools (`hci`, `cvg`) aren't needed in production; they're only needed to build/run those specific utilities. `validate_a2`'s makefile calls `pkg-config --cflags glib-2.0 libxml-2.0` as one combined call — if either `.pc` file is missing, `pkg-config` fails the whole call silently, dropping cflags for **both** libraries, not just the missing one. Worth remembering when debugging a "missing header for a library that's clearly installed" case.

   If the GUI tools ship in production, also add the X11 core bitmap fonts Motif needs at runtime (not build time) — a minimal Rocky8 image has none of these installed: `xorg-x11-fonts-100dpi xorg-x11-fonts-75dpi xorg-x11-fonts-ISO8859-1-100dpi xorg-x11-fonts-ISO8859-1-75dpi xorg-x11-fonts-misc xorg-x11-fonts-Type1`. Without them `hci`/`cvg` fail with `X Error ... BadName` on font load. See [ORPG install trace](orpg-install.md#gui-hci-cvg--missing-x11-core-fonts).
3. **Build stage**: extract `rpg_b24_0r1_20_pub_src.tgz` + `code_config_b24_0r1_20.tgz`, run `inst_env_config`, `make_rpg`, `inst_orpg_config` exactly as traced manually — turn the interactive prompts into scripted/non-interactive answers (`inst_env_config` and `inst_orpg_config` are `ksh` scripts that just read `y`/`n` and a Public/NWS choice from stdin, both scriptable with `echo`/heredoc).
4. **Runtime stage**: multi-stage build, copy the compiled `$HOME` tree (binaries, libraries, `cfg/`) out of the build stage into a slim runtime image — don't ship the compiler toolchain or source tree in the final image.
5. **Config**: bake in a real `Client:` value for `.rssd.conf` and `comms_link.conf` for the target deployment instead of the dev default of `rpg`.
6. **Entrypoint**: run `mrpg -p -v startup` (or the ORPG's own long-running mode) as PID 1 equivalent, drop the Kasm profile-copy/VNC/audio machinery entirely.

Not started yet — this page will get an actual Containerfile once the manual trace is verified end to end.
