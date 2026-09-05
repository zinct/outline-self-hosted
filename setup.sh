#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
EXAMPLE_FILE="${ROOT_DIR}/.env.example"

if [[ -f "${ENV_FILE}" ]]; then
  echo ".env already exists. Delete it manually if you want to regenerate."
  exit 1
fi

if [[ ! -f "${EXAMPLE_FILE}" ]]; then
  echo ".env.example not found."
  exit 1
fi

SECRET_KEY="$(openssl rand -hex 32)"
UTILS_SECRET="$(openssl rand -hex 32)"
POSTGRES_PASSWORD="$(openssl rand -base64 24 | tr -d '=/+' | head -c 24)"
POCKETID_ENCRYPTION_KEY="$(openssl rand -base64 32)"

cp "${EXAMPLE_FILE}" "${ENV_FILE}"

if [[ "$(uname)" == "Darwin" ]]; then
  sed -i '' "s|^SECRET_KEY=.*|SECRET_KEY=${SECRET_KEY}|" "${ENV_FILE}"
  sed -i '' "s|^UTILS_SECRET=.*|UTILS_SECRET=${UTILS_SECRET}|" "${ENV_FILE}"
  sed -i '' "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${POSTGRES_PASSWORD}|" "${ENV_FILE}"
  sed -i '' "s|^DATABASE_URL=.*|DATABASE_URL=postgres://outline:${POSTGRES_PASSWORD}@postgres:5432/outline|" "${ENV_FILE}"
  sed -i '' "s|^POCKETID_ENCRYPTION_KEY=.*|POCKETID_ENCRYPTION_KEY=\"${POCKETID_ENCRYPTION_KEY}\"|" "${ENV_FILE}"
else
  sed -i "s|^SECRET_KEY=.*|SECRET_KEY=${SECRET_KEY}|" "${ENV_FILE}"
  sed -i "s|^UTILS_SECRET=.*|UTILS_SECRET=${UTILS_SECRET}|" "${ENV_FILE}"
  sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${POSTGRES_PASSWORD}|" "${ENV_FILE}"
  sed -i "s|^DATABASE_URL=.*|DATABASE_URL=postgres://outline:${POSTGRES_PASSWORD}@postgres:5432/outline|" "${ENV_FILE}"
  sed -i "s|^POCKETID_ENCRYPTION_KEY=.*|POCKETID_ENCRYPTION_KEY=\"${POCKETID_ENCRYPTION_KEY}\"|" "${ENV_FILE}"
fi

echo "Created .env with random secrets."
echo ""
echo "Next steps:"
echo "  1. docker compose up -d"
echo "  2. Set up Pocket ID admin → http://localhost:1411/setup"
echo "  3. Create an OIDC client in Pocket ID:"
echo "       Callback URL: http://localhost:3000/auth/oidc.callback"
echo "  4. Set OIDC_CLIENT_ID and OIDC_CLIENT_SECRET in .env"
echo "  5. docker compose restart outline"
echo "  6. Open http://localhost:3000"
