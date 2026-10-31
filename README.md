# radar-orpg-dev

WSR-88D ORPG CODE B24.0r1.20 (Public Edition) dev environment on Podman, the trace of getting it running, and the production image built from it (amd64 + arm64, private GHCR package).

Full docs: `pip install -r requirements-docs.txt && mkdocs serve`, then open http://127.0.0.1:8000 — or just read the pages under `docs/` directly:

- `docs/index.md` — overview
- `docs/container-setup.md` — the Kasm/Podman container, rootless-uid-mapping fix
- `docs/orpg-install.md` — step-by-step trace of the ORPG install (deviations from the official doc, exact commands, real output)
- `docs/production-image.md` — the production image: build, run, clean shutdown, arm64, publishing

This repo holds only our own notes, scripts and Containerfile. The ORPG/CODE source, binaries and the official setup guide (`v1_setup_code_b24_0r1_20.md`) are third-party material: obtain them from the CODE distribution and keep them local (they're gitignored).

## Local dev container

```bash
cp script.sh.example script.sh   # edit VNC_PW first
./script.sh
```

## Production image

```bash
docker login ghcr.io   # private package
docker run -d --name orpg-prod --hostname orpg-prod --stop-timeout 30 ghcr.io/vladimir1284/orpg:b24
```

Built locally from `prod/Containerfile`: `docker build -f prod/Containerfile -t orpg-prod:b24 .` (needs the CODE source zip in the repo root, which is never committed). The image contains ORPG binaries, so it's only pushed to a private package.
