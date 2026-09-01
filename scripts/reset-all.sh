#!/usr/bin/env bash
# Gradi celu bazu od nule. --bez-clr preskace izgradnju .NET sklopa.
set -euo pipefail
source "$(dirname "$0")/env.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SQL="${ROOT}/scripts/sql.sh"
BEZ_CLR="${1:-}"

# redosled je bitan:
#  - Full-Text indeksi moraju postojati PRE spec funkcija (CONTAINSTABLE se
#    proverava u trenutku kreiranja funkcije)
#  - CLR agregat mora postojati PRE spec.vw_SAZETAK_PROJEKATA
REDOSLED=(
  "01_baza_i_seme.sql"            # zahtev 1  - baza, seme, logini, uloge
  "02_tabele.sql"                 # zahtev 2  - tabele, ogranicenja, indeksi
  "03_impl_interno.sql"           # zahtev 2  - interni pogled, log, triger
  "04_demo_podaci.sql"            # zahtev 1  - demo podaci + verifikacija
  "05_fulltext.sql"               # zahtevi 6,7 - katalog i FT indeksi
  "__CLR__"                       # zahtev 8  - CLR sklop i agregat
  "07_upravljanje_greskama.sql"   # zahtev 3  - upr_ procedure + TRY/CATCH
  "08_pregledi.sql"               # zahtev 4  - pogledi i api omotaci
  "09_istorija_statusa.sql"       # zahtev 13 - OUTPUT klauzula
  "10_pretraga.sql"               # zahtevi 6,7 - CONTAINS / FREETEXT
  "11_izvestaji_xml.sql"          # zahtevi 9,10 - FLWOR i ose
  "12_pretraga_komentara.sql"     # zahtev 11 - CONTAINS + nodes()
  "13_matrica_gresaka.sql"        # zahtev 12 - PIVOT
  "14_dozvole.sql"                # zahtev 5  - GRANT/DENY, izolacija
)

for s in "${REDOSLED[@]}"; do
  if [[ "$s" == "__CLR__" ]]; then
    if [[ "$BEZ_CLR" == "--bez-clr" ]]; then echo "==> [preskoceno] CLR"; continue; fi
    echo "==> CLR sklop"
    "${ROOT}/scripts/build-clr-only.sh" >/dev/null
    "${SQL}" -f "${ROOT}/db/06_clr_uda.sql" >/dev/null
    continue
  fi
  echo "==> ${s}"
  "${SQL}" -f "${ROOT}/db/${s}" >/dev/null
done

echo
"${SQL}" -d BugTracker -q "
SET NOCOUNT ON;
SELECT 'Projekti' AS Tabela, COUNT(*) AS Redova FROM impl.tblProjekat
UNION ALL SELECT 'Greske', COUNT(*) FROM impl.tblGreska
UNION ALL SELECT 'Komentari', COUNT(*) FROM impl.tblKomentar;
SELECT SCHEMA_NAME(schema_id) AS Sema, COUNT(*) AS Objekata
FROM sys.objects WHERE type IN ('U','V','P','FN','IF','TF','AF','TR','SN')
  AND SCHEMA_NAME(schema_id) IN ('impl','spec','api_dev','api_qa')
GROUP BY SCHEMA_NAME(schema_id) ORDER BY Sema;"
