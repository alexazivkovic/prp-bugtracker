#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
export DOTNET_ROOT="/opt/homebrew/opt/dotnet/libexec"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
dotnet build "${ROOT}/clr/BugTrackerCLR/BugTrackerCLR.csproj" -c Release -v q --nologo
docker exec -u root "${CONTAINER_NAME}" mkdir -p /var/opt/mssql/clr
docker cp "${ROOT}/clr/BugTrackerCLR/bin/Release/BugTrackerCLR.dll" \
          "${CONTAINER_NAME}:/var/opt/mssql/clr/BugTrackerCLR.dll"
docker exec -u root "${CONTAINER_NAME}" chown -R mssql:root /var/opt/mssql/clr
