#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"

DB="master"; MODE=""; ARG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -q) MODE="q"; ARG="$2"; shift 2 ;;
    -f) MODE="f"; ARG="$2"; shift 2 ;;
    -d) DB="$2"; shift 2 ;;
    *) echo "Nepoznat argument: $1" >&2; exit 1 ;;
  esac
done

COMMON=(-S "localhost,${HOST_PORT}" -U sa -P "${SA_PASSWORD}" -C -b -I -W -w 220 -s "|" -d "${DB}")

if [[ "$MODE" == "q" ]]; then
  sqlcmd "${COMMON[@]}" -Q "$ARG"
elif [[ "$MODE" == "f" ]]; then
  sqlcmd "${COMMON[@]}" -i "$ARG"
else
  echo "Upotreba: sql.sh -q \"upit\" | -f fajl.sql [-d baza]" >&2; exit 1
fi
