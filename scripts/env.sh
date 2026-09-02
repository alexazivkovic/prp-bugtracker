#!/usr/bin/env bash

export PATH="/opt/homebrew/bin:$PATH"

CONTAINER_NAME="bugtracker-sql"
IMAGE_NAME="bugtracker/mssql:2022-fts"
BASE_IMAGE="mcr.microsoft.com/mssql/server:2022-latest"
VOLUME_NAME="bugtracker-data"
HOST_PORT=1433
SA_PASSWORD='Prp#BugTracker2026!'
DB_NAME="BugTracker"

export CONTAINER_NAME IMAGE_NAME BASE_IMAGE VOLUME_NAME HOST_PORT SA_PASSWORD DB_NAME
