# opencode-mobile

A small, single-purpose container that runs [opencode](https://opencode.ai)
(an open-source AI coding agent CLI) with its built-in web UI, so you can
drive it from a phone browser instead of a terminal.

It works because opencode ships its own touch-friendly web interface —
`opencode serve` runs a headless HTTP server that hosts that UI and the
underlying API; there's no separate terminal-in-browser wrapper (ttyd,
gotty, etc.) needed.

Base image is `node:22-bookworm-slim` (~200MB) rather than Alpine — opencode's
prebuilt binaries have known issues on musl libc, so slim-Debian is the more
reliable "lightweight" choice. No build toolchain, no desktop app, nothing
beyond opencode itself and the few CLI tools it shells out to (git, ripgrep).

This setup assumes you're deploying to **Unraid** and reaching it by
**WireGuard VPN into your home network** — so there's no Tailscale sidecar or
public-facing reverse proxy here. Once you're on the VPN, your phone can just
reach the Unraid box directly like any other LAN device.

## Deploying on Unraid

1. Put this project somewhere on your array, e.g.:
   ```
   /mnt/user/appdata/opencode-mobile/
   ```
   (Copy the repo there, or `git clone` it if Unraid has git available — an
   SCP/rsync from your regular machine works too.)

2. SSH into Unraid and from that directory:
   ```bash
   cp .env.example .env
   openssl rand -base64 24        # generate a real password
   # edit .env: set OPENCODE_SERVER_PASSWORD, and APPDATA_PATH/WORKSPACE_PATH
   # e.g. APPDATA_PATH=/mnt/user/appdata/opencode-mobile/data
   #      WORKSPACE_PATH=/mnt/user/projects   (wherever your code actually lives)

   docker compose up -d --build
   ```
   Unraid 6.12+ ships the `docker compose` CLI plugin by default. If you'd
   rather manage this from the GUI instead of SSH, install **Docker Compose
   Manager** (by ich777) from Community Applications and paste these compose
   files in there instead.

3. **Do not port-forward 4096 on your router.** The whole point of the
   WireGuard setup is that this stays LAN-only and reachable only once
   you're on the VPN.

## First-time setup: connect an AI provider

opencode needs credentials for whichever model provider you use (Anthropic,
OpenAI, a Claude subscription, etc.). Run this once, interactively:

```bash
docker exec -it opencode-mobile opencode auth login
```

This is a normal opencode login flow (API key or device-code OAuth) — if it
prints a URL, you can open that URL on any device, it doesn't have to be the
same machine. Credentials land under `$APPDATA_PATH/config`, so they persist
across container restarts/rebuilds and get swept up in appdata backups.

## Using it from your phone

1. Connect to your home network over WireGuard as usual.
2. Find your Unraid box's LAN IP (shown at the top of the Unraid web UI, or
   under Settings → Network Settings).
3. Browse to `http://<unraid-ip>:4096` and log in with the Basic Auth
   credentials from `.env`.

## Persistence

- `$WORKSPACE_PATH` — the code/files opencode operates on. Point this at a
  real share (e.g. `/mnt/user/projects`) rather than leaving the container's
  own throwaway default.
- `$APPDATA_PATH/config` and `$APPDATA_PATH/data` — provider credentials,
  settings, and session history. Defaults to `./appdata` next to the compose
  file; on Unraid, set this to somewhere under `/mnt/user/appdata/` so the
  CA Backup/Restore plugin picks it up.

## Notes

- The container runs as a non-root `opencode` user.
- `OPENCODE_SERVER_PASSWORD` enables HTTP Basic Auth on the server. Keep it
  set even though WireGuard already gates access — it's cheap defense in
  depth against anything else on your LAN.
- opencode's agent can execute shell commands against whatever is mounted at
  `/workspace`, so treat access to this container like SSH access to that
  data.
- To pin a specific opencode version instead of always tracking latest, edit
  the `npm install -g opencode-ai@latest` line in the `Dockerfile`, then
  `docker compose build`.
