#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
umask 077
mkdir -p backups
stamp="$(date -u +%Y%m%d-%H%M%S)"
remote="/tmp/taxi-${stamp}.db"
docker compose exec -T taxi node --input-type=module -e "import {DatabaseSync} from 'node:sqlite'; const db=new DatabaseSync('/app/data/taxi.db'); db.exec(\"VACUUM INTO '${remote}'\"); db.close();"
docker compose cp "taxi:${remote}" "backups/taxi-${stamp}.db"
chmod 600 "backups/taxi-${stamp}.db"
docker compose exec -T taxi node -e "require('node:fs').unlinkSync('${remote}')"
echo "Backup saved: backups/taxi-${stamp}.db"
