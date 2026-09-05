# Outline Self-Hosted

[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)](https://docs.docker.com/compose/)
[![Outline](https://img.shields.io/badge/Outline-Wiki-0366d6)](https://www.getoutline.com/)
[![Pocket ID](https://img.shields.io/badge/Auth-Pocket%20ID-6366f1)](https://pocket-id.org/)

Production-ready **Docker Compose** stack to self-host [Outline](https://www.getoutline.com/) — a fast, collaborative team wiki and knowledge base — with lightweight **OIDC authentication** via [Pocket ID](https://pocket-id.org/) (passkey/WebAuthn login).

## Stack

| Service | Image | Purpose |
|---------|-------|---------|
| **Outline** | [`outlinewiki/outline`](https://hub.docker.com/r/outlinewiki/outline) | Wiki & knowledge base |
| **Pocket ID** | [`pocketid/pocket-id`](https://hub.docker.com/r/pocketid/pocket-id) | OIDC auth (passkeys) |
| **PostgreSQL** | `postgres:16-alpine` | Primary database |
| **Redis** | `redis:7-alpine` | Cache & real-time |

## Why Pocket ID?

Outline requires an external auth provider (no native email/password). Pocket ID is ideal for self-hosting:

| | Pocket ID | Keycloak | Authentik |
|---|-----------|----------|-----------|
| Image size | ~33 MB | ~500 MB+ | ~1 GB+ |
| Database | SQLite (built-in) | PostgreSQL + Redis | PostgreSQL + Redis |
| Typical RAM | ~50–100 MB | ~512 MB–1 GB | ~1 GB+ |
| Setup | Minimal | Complex | Moderate |

Official [Outline + Pocket ID integration docs](https://pocket-id.org/docs/client-examples/outline).

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) & Docker Compose v2
- Modern browser with passkey support (Chrome, Safari, Firefox, Edge)

## Quick Start

```bash
# 1. Generate .env with random secrets
chmod +x setup.sh
./setup.sh

# 2. Start all services
docker compose up -d

# 3. Create Pocket ID admin (one-time)
#    Open http://localhost:1411/setup and register with a passkey

# 4. Create an OIDC client in Pocket ID admin
#    - Name: Outline
#    - Callback URL: http://localhost:3000/auth/oidc.callback
#    - Copy Client ID & Client Secret

# 5. Add credentials to .env
#    OIDC_CLIENT_ID=...
#    OIDC_CLIENT_SECRET=...

# 6. Restart Outline
docker compose restart outline
```

Open http://localhost:3000 and sign in with **Pocket ID**.

## Configuration

| Variable | Description |
|----------|-------------|
| `URL` | Public URL of Outline |
| `POCKETID_APP_URL` | Public URL of Pocket ID (browser-facing) |
| `POCKETID_INTERNAL_APP_URL` | Internal Pocket ID URL (container-to-container) |
| `OIDC_CLIENT_ID` / `OIDC_CLIENT_SECRET` | From Pocket ID admin panel |
| `FORCE_HTTPS` | Set `true` in production behind HTTPS reverse proxy |

See [`.env.example`](.env.example) for all options.

## Production Deployment

Update `.env` with your domain before deploying:

```env
URL=https://wiki.example.com
POCKETID_APP_URL=https://auth.example.com
POCKETID_TRUST_PROXY=true
FORCE_HTTPS=true

OIDC_AUTH_URI=https://auth.example.com/authorize
OIDC_LOGOUT_URI=https://auth.example.com/api/oidc/end-session
OIDC_TOKEN_URI=http://pocket-id:1411/api/oidc/token
OIDC_USERINFO_URI=http://pocket-id:1411/api/oidc/userinfo
```

**Passkey requirements on VPS:**
- `POCKETID_APP_URL` must be **exactly** the URL you open in the browser (`https://auth.example.com` — no trailing slash, no port)
- **HTTPS is mandatory** for passkeys on real domains (HTTP only works on `localhost`)
- `POCKETID_TRUST_PROXY=true` when behind Nginx, Traefik, or Cloudflare
- Reverse proxy must forward `X-Forwarded-Proto`, `X-Forwarded-Host`, and `Host`

Nginx example for Pocket ID:

```nginx
server {
    listen 443 ssl;
    server_name auth.example.com;

    location / {
        proxy_pass http://127.0.0.1:1411;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
    }
}
```

Nginx example for Outline:

```nginx
server {
    listen 443 ssl;
    server_name wiki.example.com;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
    }
}
```

Pocket ID callback URL: `https://wiki.example.com/auth/oidc.callback`

On your server:

```bash
git clone https://github.com/zinct/outline-self-hosted.git
cd outline-self-hosted
./setup.sh          # or: cp .env.example .env
# edit .env with production domain & secrets
docker compose up -d
```

Point your reverse proxy (Nginx, Traefik, etc.) to ports **3000** (Outline) and **1411** (Pocket ID) for TLS termination.

## Useful Commands

```bash
docker compose up -d                              # Start
docker compose down                               # Stop
docker compose logs -f outline                    # Outline logs
docker compose logs -f pocket-id                    # Pocket ID logs
docker compose pull && docker compose up -d         # Update images
docker compose exec postgres pg_dump -U outline outline > backup.sql
```

## Troubleshooting

### Pocket ID: `Passkeys are not configured correctly for this domain`

This means the WebAuthn domain does not match `POCKETID_APP_URL`. Common causes on VPS:

| Problem | Fix |
|---------|-----|
| Still using `http://localhost:1411` in `.env` | Set `POCKETID_APP_URL=https://auth.yourdomain.com` |
| Accessing via HTTP on a real domain | Use HTTPS — passkeys require a secure context |
| `TRUST_PROXY=false` behind reverse proxy | Set `POCKETID_TRUST_PROXY=true` |
| Trailing slash in URL | Use `https://auth.example.com` not `https://auth.example.com/` |
| `www` vs bare domain mismatch | Match exactly what you type in the browser |
| Reverse proxy missing headers | Add `X-Forwarded-Proto` and `X-Forwarded-Host` (see Nginx example above) |

After fixing `.env`:

```bash
docker compose up -d pocket-id
```

Verify Pocket ID sees the correct domain — in browser DevTools → Network → any WebAuthn request, check `"rp": { "id": "auth.example.com" }` (not `localhost`).

If you previously set up Pocket ID with the wrong `APP_URL`, you may need to reset and re-register passkeys:

```bash
docker compose stop pocket-id
docker compose rm -f pocket-id
docker volume rm outline-self-hosted_pocket-id-data
docker compose up -d pocket-id
# then visit https://auth.yourdomain.com/setup again
```

### Pocket ID: `failed to decrypt private key`

This happens when `POCKETID_ENCRYPTION_KEY` is changed after the data volume was created. Reset Pocket ID data:

```bash
docker compose stop pocket-id outline
docker compose rm -f pocket-id
docker volume rm outline-self-hosted_pocket-id-data   # or: outline_pocket-id-data
docker compose up -d
```

**Never change `POCKETID_ENCRYPTION_KEY` after the first successful start.** Back it up securely.

### Pocket ID: `MAXMIND_LICENSE_KEY is empty`

Safe to ignore for local setups. Optional: get a free [MaxMind GeoLite2 license](https://www.maxmind.com/en/geolite2/signup) and pass `MAXMIND_LICENSE_KEY` to the `pocket-id` service.

## References

- [Outline Docker Hub](https://hub.docker.com/r/outlinewiki/outline)
- [Outline hosting docs](https://docs.getoutline.com/s/hosting)
- [Pocket ID + Outline guide](https://pocket-id.org/docs/client-examples/outline)
- [Pocket ID docs](https://pocket-id.org/docs)

## License

This deployment configuration is provided as-is under the [MIT License](LICENSE).

Outline itself is [BSL 1.1 licensed](https://github.com/outline/outline/blob/main/LICENSE).
