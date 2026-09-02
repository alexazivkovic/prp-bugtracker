#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/env.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "${ROOT}/tests/izlaz"

for f in "${ROOT}"/tests/T*.sql; do
  ime="$(basename "$f" .sql)"
  printf "%-32s" "$ime"
  case "$ime" in
    T05_izolacija_DEV)
      sqlcmd -S "localhost,${HOST_PORT}" -U AppLoginDEV -P 'Prp#Dev2026!' -C -W -w 220 -s "|" \
             -d BugTracker -i "$f" > "${ROOT}/tests/izlaz/${ime}.txt" 2>&1 ;;
    T05_izolacija_QA)
      sqlcmd -S "localhost,${HOST_PORT}" -U AppLoginQA -P 'Prp#Qa2026!' -C -W -w 220 -s "|" \
             -d BugTracker -i "$f" > "${ROOT}/tests/izlaz/${ime}.txt" 2>&1 ;;
    *)
      "${ROOT}/scripts/sql.sh" -f "$f" > "${ROOT}/tests/izlaz/${ime}.txt" 2>&1 ;;
  esac
  if grep -qE "^Msg [0-9]+, Level 1[1-9]|PROSLO - " "${ROOT}/tests/izlaz/${ime}.txt"; then
    echo "PROVERI"
  else
    echo "OK"
  fi
done
echo
echo "Izlazi: tests/izlaz/"
