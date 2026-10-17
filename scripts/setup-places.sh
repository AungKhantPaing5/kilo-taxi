#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
[[ -f .env ]] || { echo 'Run install.sh first'; exit 1; }
command -v curl >/dev/null || { echo 'Install curl first'; exit 1; }
mkdir -p routing-data
if [[ ! -f routing-data/myanmar-latest.osm.pbf ]]; then
  curl --fail --location --retry 3 -o routing-data/myanmar-latest.osm.pbf.part https://download.geofabrik.de/asia/myanmar-latest.osm.pbf
  mv routing-data/myanmar-latest.osm.pbf.part routing-data/myanmar-latest.osm.pbf
fi
docker compose up -d --build taxi
for attempt in $(seq 1 30); do
  if docker compose exec -T taxi node -e "fetch('http://127.0.0.1:8080/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"; then break; fi
  sleep 1
done
echo 'Building local Myanmar place index. Several minutes and GB of RAM may be needed.'
docker run --rm -v "$PWD/routing-data:/data" -v "$PWD/scripts/build-places.py:/build-places.py:ro" python:3.12-slim sh -c 'pip install --no-cache-dir "osmium>=4,<5" && python /build-places.py /data/myanmar-latest.osm.pbf /data/places.jsonl'
docker compose cp routing-data/places.jsonl taxi:/tmp/places.jsonl
docker compose exec -T taxi node /app/import-places.mjs /tmp/places.jsonl
docker compose exec -T taxi node -e "require('node:fs').unlinkSync('/tmp/places.jsonl')"
echo 'Place search is ready. Reload the website and type a place name.'
