# radar-orpg-dev

WSR-88D ORPG CODE B24.0r1.20 (Public Edition) dev environment on Podman, and the trace of getting it running, towards a production image.

Full docs: `pip install -r requirements-docs.txt && mkdocs serve`, then open http://127.0.0.1:8000 — or just read the pages under `docs/` directly:

- `docs/index.md` — overview
- `docs/container-setup.md` — the Kasm/Podman container, rootless-uid-mapping fix
- `docs/orpg-install.md` — step-by-step trace of the ORPG install (deviations from the official doc, exact commands, real output)
- `docs/production-image.md` — plan for a dedicated production image

The official setup guide this follows is `v1_setup_code_b24_0r1_20.md` in this same directory.

## Local dev container

```bash
cp script.sh.example script.sh   # edit VNC_PW first
./script.sh
```
