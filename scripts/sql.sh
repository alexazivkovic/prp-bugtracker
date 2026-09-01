#!/usr/bin/env bash
# Pokreće SQL nad BugTracker instancom.
#   ./scripts/sql.sh -q "SELECT @@VERSION"        -> jedan upit
#   ./scripts/sql.sh -f db/01_CreateDatabase.sql  -> cela skripta
#   ./scripts/sql.sh -f skripta.sql -d BugTracker -> u konkretnoj bazi
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

# -S server,port  -U korisnik  -P lozinka
# -C  = veruj sertifikatu servera (self-signed u kontejneru)
# -b  = izađi sa greškom ako SQL pukne (bitno za automatske testove)
# -I  = QUOTED_IDENTIFIER ON (obavezno za XML indekse i indeksirane poglede)
COMMON=(-S "localhost,${HOST_PORT}" -U sa -P "${SA_PASSWORD}" -C -b -I -W -w 220 -s "|" -d "${DB}")

if [[ "$MODE" == "q" ]]; then
  sqlcmd "${COMMON[@]}" -Q "$ARG"
elif [[ "$MODE" == "f" ]]; then
  sqlcmd "${COMMON[@]}" -i "$ARG"
else
  echo "Upotreba: sql.sh -q \"upit\" | -f fajl.sql [-d baza]" >&2; exit 1
fi
