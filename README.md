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

## Quick start

```bash
cp .env.example .env
# generate a real password:
openssl rand -base64 24
# paste it into .env as OPENCODE_SERVER_PASSWORD

mkdir -p workspace   # put the code you want opencode to work on in here
docker compose up -d --build
```

By default the UI is bound to `127.0.0.1:4096` on the host only. Pick one of
the three access modes below before you actually try to reach it from your
phone.

## First-time setup: connect an AI provider

opencode needs credentials for whichever model provider you use (Anthropic,
OpenAI, a Claude subscription, etc.). Run this once, interactively:

```bash
docker exec -it opencode-mobile opencode auth login
```

This is a normal opencode login flow (API key or device-code OAuth) — if it
prints a URL, you can open that URL on any device, it doesn't have to be the
same machine. Credentials are written to the `opencode-config` volume, so
they persist across container restarts/rebuilds.

## Accessing it from your phone — three modes

**1. Same Wi-Fi / LAN only (simplest)**
Set `BIND_ADDRESS=0.0.0.0` in `.env`, restart (`docker compose up -d`), then
browse to `http://<host-lan-ip>:4096` from your phone while on the same
network. Nothing leaves your network, but anyone else on that Wi-Fi can also
reach it if they get the URL — the basic-auth password is what protects it.

**2. Tailscale (recommended)**
Keeps the container off the public internet entirely while still being
reachable from your phone anywhere:

```bash
docker compose -f docker-compose.yml -f docker-compose.tailscale.yml up -d
```

Set `TS_AUTHKEY` in `.env` first (get one from the
[Tailscale admin console](https://login.tailscale.com/admin/settings/keys)).
Then, with the Tailscale app installed on your phone, browse to
`http://opencode:4096` (MagicDNS) or the tailnet IP shown in the console.

**3. Public internet via reverse proxy**
Only if you want it reachable with no VPN app on your phone. Requires a
domain pointed at the host and ports 80/443 open:

```bash
# set DOMAIN=yourdomain.example in .env first
docker compose -f docker-compose.yml -f docker-compose.public.yml up -d
```

Caddy automatically provisions TLS for `DOMAIN` and proxies to opencode,
which still enforces HTTP Basic Auth behind the encrypted connection. Use a
strong, unique password in this mode — opencode's agent can execute shell
commands in `/workspace`, so treat exposed access like SSH access.

## Persistence

- `./workspace` — the code/files opencode operates on (bind-mounted, so it's
  just a normal directory on the host)
- `opencode-config` / `opencode-data` (named volumes) — provider credentials,
  settings, and session history

Delete the named volumes (`docker compose down -v`) to fully reset auth and
session state.

## Notes

- The container runs as a non-root `opencode` user.
- `OPENCODE_SERVER_PASSWORD` enables HTTP Basic Auth on the server; without
  it the API/UI is unauthenticated, which is only acceptable behind
  Tailscale or another trusted network boundary you already control.
- To use a different opencode version, edit the `npm install -g
  opencode-ai@latest` line in the `Dockerfile` to pin a version, then
  `docker compose build`.
