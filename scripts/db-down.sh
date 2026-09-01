#!/usr/bin/env bash
# Zaustavlja i uklanja kontejner. Podaci ostaju u volumenu.
set -euo pipefail
source "$(dirname "$0")/env.sh"
docker rm -f "${CONTAINER_NAME}" 2>/dev/null && echo "Kontejner uklonjen." || echo "Kontejner ne postoji."
echo "Volumen '${VOLUME_NAME}' je sačuvan. Za potpuno brisanje: docker volume rm ${VOLUME_NAME}"
