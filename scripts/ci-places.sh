#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
folder="$(mktemp -d)"
chmod 777 "$folder"
cp tests/router.osm "$folder/input.osm"
trap 'docker logs taxi-place-ci || true; docker rm -f taxi-place-ci || true; rm -rf "$folder"' EXIT
docker run --rm -v "$folder:/data" -v "$PWD/scripts/build-places.py:/build-places.py:ro" -v "$PWD/scripts/install-place-deps.sh:/install-place-deps.sh:ro" python:3.12 sh -c 'sh /install-place-deps.sh && python /build-places.py /data/input.osm /data/places.jsonl'
docker run -d --read-only --tmpfs /tmp:size=32m --tmpfs /app/data:size=32m --name taxi-place-ci -e ADMIN_PASSWORD=ci-only-test-password-123 kilo-taxi:test
for attempt in $(seq 1 30); do
  if docker exec taxi-place-ci node -e "fetch('http://127.0.0.1:8080/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"; then break; fi
  sleep 1
done
docker exec taxi-place-ci node --input-type=module -e "import {DatabaseSync} from 'node:sqlite';const db=new DatabaseSync('/app/data/taxi.db');db.prepare('INSERT INTO places VALUES(?,?,?,?,?,?)').run('custom-test','Custom','custom',16,96,'custom');db.close();"
docker exec -i taxi-place-ci node /app/import-places.mjs - < "$folder/places.jsonl"
docker exec taxi-place-ci node --input-type=module -e "import {DatabaseSync} from 'node:sqlite';import assert from 'node:assert/strict';const db=new DatabaseSync('/app/data/taxi.db');assert.equal(db.prepare(\"SELECT count(*) AS n FROM places WHERE source='osm'\").get().n,1);assert.equal(db.prepare(\"SELECT count(*) AS n FROM places WHERE source='custom'\").get().n,1);db.close();console.log('PASS real OSM index build/import and custom-place preservation');"
