# Production image plan

Once the manual dev setup in [ORPG install trace](orpg-install.md) is fully verified (clean compile, `mrpg -p -v startup` succeeds, `rpg_ps` shows tasks up), replace the Kasm interactive-desktop container with a purpose-built production image.

## Why not ship `rocky8-radar-dev` as-is

- Base image (`kasmweb/rockylinux-8-desktop`) is built for interactive VNC desktop use: XFCE, KasmVNC, audio/printer/gamepad services, a profile-copy entrypoint — none of it relevant to running the ORPG as a service.
- Dependencies were installed by hand via `dnf` inside a running container (see [ORPG install trace](orpg-install.md)) — not reproducible, not in any Containerfile.
- The ORPG source tree was built directly into a bind-mounted `$HOME`, not baked into an image layer.

## Planned approach

1. **Base**: plain `rockylinux:8`, not the Kasm desktop image.
2. **Build-time deps** (confirmed required by grepping `conf/*.make`, not just the official doc's list — see [ORPG install trace](orpg-install.md#dependency-gap-vs-the-doc)):
   `gcc gcc-c++ gcc-gfortran ksh tcsh giflib-devel ncompress libtirpc-devel libnsl2-devel gtk2-devel gtk3-devel libgtop2-devel`
   — drop `gtk2-devel`/`gtk3-devel`/`libgtop2-devel`/`tcsh` from the runtime image if the GUI tools (`hci`, `cvg`) aren't needed in production; they're only needed to build/run those specific utilities.
3. **Build stage**: extract `rpg_b24_0r1_20_pub_src.tgz` + `code_config_b24_0r1_20.tgz`, run `inst_env_config`, `make_rpg`, `inst_orpg_config` exactly as traced manually — turn the interactive prompts into scripted/non-interactive answers (`inst_env_config` and `inst_orpg_config` are `ksh` scripts that just read `y`/`n` and a Public/NWS choice from stdin, both scriptable with `echo`/heredoc).
4. **Runtime stage**: multi-stage build, copy the compiled `$HOME` tree (binaries, libraries, `cfg/`) out of the build stage into a slim runtime image — don't ship the compiler toolchain or source tree in the final image.
5. **Config**: bake in a real `Client:` value for `.rssd.conf` and `comms_link.conf` for the target deployment instead of the dev default of `rpg`.
6. **Entrypoint**: run `mrpg -p -v startup` (or the ORPG's own long-running mode) as PID 1 equivalent, drop the Kasm profile-copy/VNC/audio machinery entirely.

Not started yet — this page will get an actual Containerfile once the manual trace is verified end to end.
