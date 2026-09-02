#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"

if docker ps -a --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
  echo "Kontejner '${CONTAINER_NAME}' postoji - pokrećem ga."
  docker start "${CONTAINER_NAME}" >/dev/null
else
  echo "Kreiram kontejner '${CONTAINER_NAME}'..."
  docker run -d \
    --name "${CONTAINER_NAME}" \
    --platform linux/amd64 \
    -e "ACCEPT_EULA=Y" \
    -e "MSSQL_SA_PASSWORD=${SA_PASSWORD}" \
    -e "MSSQL_PID=Developer" \
    -e "MSSQL_AGENT_ENABLED=true" \
    -e "MSSQL_MEMORY_LIMIT_MB=2560" \
    -p "${HOST_PORT}:1433" \
    -v "${VOLUME_NAME}:/var/opt/mssql" \
    "${IMAGE_NAME}" >/dev/null
fi

echo -n "Čekam da SQL Server postane spreman"
for i in $(seq 1 90); do
  if sqlcmd -S "localhost,${HOST_PORT}" -U sa -P "${SA_PASSWORD}" -C -b \
            -Q "SELECT 1" >/dev/null 2>&1; then
    echo " - spreman!"
    sqlcmd -S "localhost,${HOST_PORT}" -U sa -P "${SA_PASSWORD}" -C -h -1 -W -Q "
      SET NOCOUNT ON;
      SELECT 'Verzija        : ' + CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(50));
      SELECT 'Edicija        : ' + CAST(SERVERPROPERTY('Edition')        AS NVARCHAR(50));
      SELECT 'Kolacija srv.  : ' + CAST(SERVERPROPERTY('Collation')      AS NVARCHAR(80));
      SELECT 'Full-Text      : ' + CASE SERVERPROPERTY('IsFullTextInstalled')
                                     WHEN 1 THEN 'INSTALIRAN' ELSE 'NEDOSTAJE' END;"
    exit 0
  fi
  echo -n "."
  sleep 2
done
echo " - NEUSPEH."
echo "Poslednjih 30 linija loga kontejnera:"
docker logs --tail 30 "${CONTAINER_NAME}"
exit 1
