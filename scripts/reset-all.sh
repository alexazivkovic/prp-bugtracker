#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SQL="${ROOT}/scripts/sql.sh"
BEZ_CLR="${1:-}"

REDOSLED=(
  "01_baza_i_seme.sql"
  "02_tabele.sql"
  "03_impl_interno.sql"
  "04_demo_podaci.sql"
  "05_fulltext.sql"
  "__CLR__"
  "07_upravljanje_greskama.sql"
  "08_pregledi.sql"
  "09_istorija_statusa.sql"
  "10_pretraga.sql"
  "11_izvestaji_xml.sql"
  "12_pretraga_komentara.sql"
  "13_matrica_gresaka.sql"
  "14_dozvole.sql"
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
