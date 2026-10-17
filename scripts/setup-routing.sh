#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
command -v docker >/dev/null || { echo 'Docker is required.'; exit 1; }
command -v curl >/dev/null || { echo 'Install curl first.'; exit 1; }
[[ -f .env ]] || { echo 'Run bash install.sh first.'; exit 1; }
mkdir -p routing-data
# Pin the exact downloaded image for all preprocessing stages. On later updates,
# regenerate the dataset with the same image used by the routing service.
image='ghcr.io/project-osrm/osrm-backend:latest'
if [[ ! -f routing-data/.ready ]]; then
  echo 'Preparing Myanmar road data. This can take several minutes and multiple GB of RAM.'
  if [[ ! -f routing-data/myanmar-latest.osm.pbf ]]; then
    curl --fail --location --retry 3 --output routing-data/myanmar-latest.osm.pbf.part https://download.geofabrik.de/asia/myanmar-latest.osm.pbf
    mv routing-data/myanmar-latest.osm.pbf.part routing-data/myanmar-latest.osm.pbf
  fi
  docker pull "$image"
  resolved_image="$(docker image inspect --format '{{index .RepoDigests 0}}' "$image")"
  docker run --rm -v "$PWD/routing-data:/data" "$resolved_image" osrm-extract --threads 2 -p /opt/car.lua /data/myanmar-latest.osm.pbf
  docker run --rm -v "$PWD/routing-data:/data" "$resolved_image" osrm-partition --threads 2 /data/myanmar-latest.osrm
  docker run --rm -v "$PWD/routing-data:/data" "$resolved_image" osrm-customize --threads 2 /data/myanmar-latest.osrm
  printf '%s\n' "$resolved_image" > routing-data/.image
  touch routing-data/.ready
fi
[[ -s routing-data/.image ]] || { echo 'Missing routing image marker. Check routing-data before retrying.'; exit 1; }
resolved_image="$(cat routing-data/.image)"
# This generated override retains the exact engine version used for the dataset.
printf 'services:\n  osrm:\n    image: %s\n' "$resolved_image" > routing-data/engine.yaml
files=(-f compose.yaml -f compose.routing.yaml -f routing-data/engine.yaml)
if [[ "${1:-}" == '--https' ]]; then files+=(-f compose.https.yaml); fi
docker compose "${files[@]}" up -d --build
for attempt in $(seq 1 60); do
  if docker compose "${files[@]}" exec -T taxi node -e "fetch('http://osrm:5000/nearest/v1/driving/96.158,16.774',{signal:AbortSignal.timeout(3000)}).then(async r=>{const d=await r.json();process.exit(r.ok&&d.code==='Ok'?0:1)}).catch(()=>process.exit(1))"; then
    echo 'Myanmar routing is ready. Reload the website, set Admin fare, then choose two map points.'
    exit 0
  fi
  sleep 2
done
echo 'Router did not become ready. Check: docker compose -f compose.yaml -f compose.routing.yaml logs --tail=100 osrm'
exit 1
