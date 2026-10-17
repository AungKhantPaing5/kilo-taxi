#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
command -v docker >/dev/null || { echo 'Install Docker Engine and Docker Compose plugin first: https://docs.docker.com/engine/install/ubuntu/'; exit 1; }
docker compose version >/dev/null
if [[ ! -f .env ]]; then
  umask 077
  password="$(openssl rand -hex 18)"
  printf 'ADMIN_USERNAME=admin\nADMIN_PASSWORD=%s\nBIND_ADDRESS=127.0.0.1\nHTTP_PORT=8080\nPUBLIC_URL=http://localhost:8080\nGOOGLE_MAPS_API_KEY=\n' "$password" > .env
  echo 'Created .env. Initial login username: admin'
  echo 'Read ADMIN_PASSWORD in .env. Keep this file private.'
fi
docker compose config --quiet
docker compose up -d --build
echo 'Kilo Taxi is running on http://localhost:8080 (loopback only).'
echo 'For VPS: configure HTTPS reverse proxy and set PUBLIC_URL in .env. See README.md.'

if [[ "${1:-}" == '--routing' ]]; then
  bash scripts/setup-routing.sh
else
  echo 'For billing-free automatic road-distance calculation, run: bash scripts/setup-routing.sh'
fi
