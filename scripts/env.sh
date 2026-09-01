#!/usr/bin/env bash
# Zajednička konfiguracija okruženja za BugTracker projekat.
# Uključuje se (source) iz svih ostalih skripti.

export PATH="/opt/homebrew/bin:$PATH"

CONTAINER_NAME="bugtracker-sql"       # ime Docker kontejnera
IMAGE_NAME="bugtracker/mssql:2022-fts" # naša slika (SQL Server + Full-Text Search)
BASE_IMAGE="mcr.microsoft.com/mssql/server:2022-latest"
VOLUME_NAME="bugtracker-data"         # imenovani volumen - podaci preživljavaju restart
HOST_PORT=1433                        # port na Mac-u
SA_PASSWORD='Prp#BugTracker2026!'     # lozinka sistemskog administratora (razvojna)
DB_NAME="BugTracker"

export CONTAINER_NAME IMAGE_NAME BASE_IMAGE VOLUME_NAME HOST_PORT SA_PASSWORD DB_NAME
