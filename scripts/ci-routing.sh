#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
folder="$(mktemp -d)"
cp tests/router.osm "$folder/test.osm"
chmod 777 "$folder"
image=ghcr.io/project-osrm/osrm-backend:latest
docker pull "$image"
image="$(docker image inspect --format '{{index .RepoDigests 0}}' "$image")"
docker run --rm -v "$folder:/data" "$image" osrm-extract --threads 2 -p /opt/car.lua /data/test.osm
docker run --rm -v "$folder:/data" "$image" osrm-partition --threads 2 /data/test.osrm
docker run --rm -v "$folder:/data" "$image" osrm-customize --threads 2 /data/test.osrm
docker network create taxi-route-ci
trap 'docker logs osrm-ci; docker logs taxi-route-ci; docker rm -f osrm-ci taxi-route-ci; docker network rm taxi-route-ci; rm -rf "$folder"' EXIT
docker run -d --name osrm-ci --network taxi-route-ci -v "$folder:/data:ro" "$image" osrm-routed --algorithm mld --threads 2 /data/test.osrm
docker run -d --name taxi-route-ci --network taxi-route-ci -p 127.0.0.1:18081:8080 -e ADMIN_PASSWORD=ci-only-test-password-123 -e PUBLIC_URL=http://localhost:18081 -e OSRM_URL=http://osrm-ci:5000 kilo-taxi:test
for attempt in $(seq 1 30); do
  if curl --fail --silent http://localhost:18081/healthz; then break; fi
  sleep 1
done
node --input-type=module <<'JS'
import assert from 'node:assert/strict';
const base='http://localhost:18081';let cookie;
async function api(path,method='GET',body){const r=await fetch(base+'/api/taxi/'+path,{method,headers:{origin:base,'Content-Type':'application/json',...(cookie?{cookie}:{})},...(body?{body:JSON.stringify(body)}:{})});const data=await r.json();if(!r.ok)throw Error(JSON.stringify(data));cookie=r.headers.get('set-cookie')?.split(';')[0]||cookie;return data}
await api('login','POST',{username:'admin',password:'ci-only-test-password-123'});
await api('rates','PUT',{rate:1200,base:0,waitRate:0,round:1});
let quote;
for(let attempt=0;attempt<15;attempt++){try{quote=await api('route','POST',{start:[16.77,96.15],end:[16.79,96.16]});break}catch(e){if(attempt===14)throw e;await new Promise(r=>setTimeout(r,1000))}}
assert(quote.km>2&&quote.km<10,'Road distance within synthetic fixture bounds');
const result=await api('trips','POST',{id:crypto.randomUUID(),source:'osrm',quoteId:quote.quoteId,origin:'Synthetic A',destination:'Synthetic B',km:0.001,minutes:null,wait:0,extra:0});
assert.equal(result.total,Math.ceil(quote.km*1200));
console.log('PASS real OSRM: '+quote.km+' km × 1200 = '+result.total+' MMK; client km ignored.');
JS
