#!/usr/bin/env bash
# Pokrece aplikaciju programera.
set -euo pipefail
source "$(dirname "$0")/env.sh"
export DOTNET_ROOT="/opt/homebrew/opt/dotnet/libexec"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
dotnet run --project "${ROOT}/apps/ApplicationDEV/ApplicationDEV.csproj" -c Release
