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

## How the image gets built

`.github/workflows/publish.yml` builds this Dockerfile and pushes it to
`ghcr.io/emenblade/opencode-mobile` on every push to `main`, on a daily
schedule (to pick up new `opencode-ai` releases even when nothing here
changes), and on manual trigger from the Actions tab. Unraid then just pulls
`:latest` — no build step, no Node/npm toolchain needed on the NAS at all.

**One-time manual step required:** GitHub Container Registry publishes new
packages as *private* by default, even from a public repo, and there's no
way to flip that from the workflow itself (it needs a package-admin action,
not just `packages: write`). After the workflow runs once:

1. Go to your GitHub profile → **Packages** → `opencode-mobile`.
2. **Package settings** → **Danger Zone** → **Change visibility** → Public.
3. While there, under "Manage Actions access" / repo connection, link it to
   `emenblade/unraidopencode` so it shows up on the repo page too.

Without this, Unraid's pull will fail with a 403/denied error since it has
no registry credentials configured. (Alternative if you'd rather keep it
private: add a GHCR login under Unraid's Docker settings using a PAT with
`read:packages` — but public is simpler for a non-sensitive image like
this.)

To test the workflow before merging this branch to `main`, trigger it
manually: **Actions tab → Build and publish image → Run workflow**.

## Deploying on Unraid (docker compose)

1. Put this project somewhere on your array, e.g.:
   ```
   /mnt/user/appdata/opencode-mobile/
   ```
   (Copy the repo there, or `git clone` it if Unraid has git available — an
   SCP/rsync from your regular machine works too. You only strictly need
   `docker-compose.yml` and `.env` since the image is pulled, not built, but
   keeping the whole repo is simpler to manage.)

2. SSH into Unraid and from that directory:
   ```bash
   cp .env.example .env
   openssl rand -base64 24        # generate a real password
   # edit .env: set OPENCODE_SERVER_PASSWORD, and APPDATA_PATH/WORKSPACE_PATH
   # e.g. APPDATA_PATH=/mnt/user/appdata/opencode-mobile
   #      WORKSPACE_PATH=/mnt/user/projects   (wherever your code actually lives)

   docker compose pull
   docker compose up -d
   ```
   Unraid 6.12+ ships the `docker compose` CLI plugin by default. If you'd
   rather manage this from the GUI instead of SSH, install **Docker Compose
   Manager** (by ich777) from Community Applications and paste these compose
   files in there instead.

### Alternative: native Unraid Docker template (no compose)

`unraid-template.xml` lets you add this as a regular container from the
Docker tab's "Add Container" screen instead of using compose, pulling
straight from `ghcr.io/emenblade/opencode-mobile:latest`:

```bash
cp unraid-template.xml /boot/config/plugins/dockerMan/templates-user/opencode-mobile.xml
```

Go to **Docker → Add Container**, pick `opencode-mobile` from the template
dropdown, and fill in the Server Password field (everything else has sane
Unraid-style defaults: `/mnt/user/projects` for the workspace,
`/mnt/user/appdata/opencode-mobile` for persisted state, port 4096). Apply,
then run `opencode auth login` via `docker exec` as below.

For fully hands-off updates, install **Auto Update Applications** (by
Squid) from Community Applications and enable it for this container —
Unraid will then periodically check GHCR for a new digest, pull it, and
restart the container on its own, in step with the daily CI rebuild.

3. **Do not port-forward 4096 on your router.** The whole point of the
   WireGuard setup is that this stays LAN-only and reachable only once
   you're on the VPN.

## First-time setup: connect an AI provider

opencode needs credentials for whichever model provider you use (Anthropic,
OpenAI, a Claude subscription, etc.). Run this once, interactively:

```bash
docker exec -it -u opencode opencode-mobile opencode auth login
```

The `-u opencode` matters: the container itself starts as root (so the
entrypoint can fix bind-mount ownership on first run — see Notes below),
so a plain `docker exec` without `-u` would default to root and leave
files it creates owned by the wrong user.

This is a normal opencode login flow (API key or device-code OAuth) — if it
prints a URL, you can open that URL on any device, it doesn't have to be the
same machine. Credentials land under `$APPDATA_PATH`, so they persist across
container restarts/updates and get swept up in appdata backups.

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
- `$APPDATA_PATH` — opencode's whole home directory: provider credentials,
  settings, and session history all live under here, however opencode
  chooses to lay them out internally. Defaults to `./appdata` next to the
  compose file; on Unraid, set this to somewhere under `/mnt/user/appdata/`
  so the CA Backup/Restore plugin picks it up.

## Notes

- The actual opencode process runs as a non-root `opencode` user. The
  container's entrypoint starts as root just long enough to `chown -R` the
  entire `$APPDATA_PATH` and `/workspace` mounts (Docker/Unraid auto-create
  missing bind-mount host directories — and their parent directories — as
  root, which would otherwise block a non-root process from writing into
  them), then drops privileges before running anything else. This is
  automatic — no manual `chown` needed on the host side. `$APPDATA_PATH` is
  mounted as opencode's whole home directory rather than individual
  subpaths, specifically so this covers whatever internal directories
  opencode creates (config, data, state, cache, ...) without having to
  enumerate them one at a time.
- `OPENCODE_SERVER_PASSWORD` enables HTTP Basic Auth on the server. Keep it
  set even though WireGuard already gates access — it's cheap defense in
  depth against anything else on your LAN.
- opencode's agent can execute shell commands against whatever is mounted at
  `/workspace`, so treat access to this container like SSH access to that
  data.
- Every image is also tagged with its commit, e.g.
  `ghcr.io/emenblade/opencode-mobile:sha-<commit>`. To pin instead of
  tracking `latest`, use one of those tags in `docker-compose.yml` (or the
  template's Repository field) and disable auto-update for this container.
