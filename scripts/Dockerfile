# Zvanicna Microsoft slika ne sadrzi Full-Text Search, na Linuxu je to poseban
# paket mssql-server-fts. Bez njega ne rade zahtevi 6, 7 i 11, pa pravim
# sopstvenu sliku koja ga dodaje.
FROM mcr.microsoft.com/mssql/server:2022-latest

# Instalacija paketa zahteva root; posle se vraćamo na 'mssql' korisnika.
USER root

# packages.microsoft.com/ubuntu/22.04/prod (već prisutan u imageu) sadrži alate,
# ali ne i server pakete - zato dodajemo mssql-server-2022 repozitorijum.
# signed-by= pokazuje na GPG ključ koji je već u imageu.
RUN echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/microsoft-prod.gpg] \
https://packages.microsoft.com/ubuntu/22.04/mssql-server-2022 jammy main" \
      > /etc/apt/sources.list.d/mssql-server-2022.list \
 && apt-get update \
 && ACCEPT_EULA=Y apt-get install -y --no-install-recommends mssql-server-fts \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

USER mssql
