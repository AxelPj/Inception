#!/bin/bash
set -euo pipefail

: "${SQL_DATABASE:?SQL_DATABASE not set}"
: "${SQL_USER:?SQL_USER not set}"

SQL_PASSWORD="$(tr -d '\n' < /run/secrets/db_password)"
SQL_ROOT_PASSWORD="$(tr -d '\n' < /run/secrets/db_root_password)"

DATADIR="/var/lib/mysql"
RUNDIR="/run/mysqld"
SOCKET="$RUNDIR/mysqld.sock"
MARKER="$DATADIR/.inception_initialized"

# Création des dossiers runtime + droits
mkdir -p "$RUNDIR"
chown -R mysql:mysql "$RUNDIR" "$DATADIR" || true

# Bootstrap des tables système si absent
if [ ! -d "$DATADIR/mysql" ]; then
  echo "[mariadb] Installing system tables..."
  mariadb-install-db --user=mysql --datadir="$DATADIR" >/dev/null
fi

# Init app (une seule fois)
if [ ! -f "$MARKER" ]; then
  echo "[mariadb] Initializing database and users..."

  mariadbd --user=mysql --skip-networking --socket="$SOCKET" &
  pid="$!"

  # Wait server ready
  for i in {1..60}; do
    if mysqladmin --socket="$SOCKET" ping --silent >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  mariadb --socket="$SOCKET" -e "CREATE DATABASE IF NOT EXISTS \`${SQL_DATABASE}\`;"
  mariadb --socket="$SOCKET" -e "CREATE USER IF NOT EXISTS \`${SQL_USER}\`@'%' IDENTIFIED BY '${SQL_PASSWORD}';"
  mariadb --socket="$SOCKET" -e "GRANT ALL PRIVILEGES ON \`${SQL_DATABASE}\`.* TO \`${SQL_USER}\`@'%';"
  mariadb --socket="$SOCKET" -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${SQL_ROOT_PASSWORD}';"
  mariadb --socket="$SOCKET" -u root -p"${SQL_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"

  touch "$MARKER"

  mysqladmin --socket="$SOCKET" -u root -p"${SQL_ROOT_PASSWORD}" shutdown
  wait "$pid" 2>/dev/null || true

  echo "[mariadb] Initialization complete."
else
  echo "[mariadb] Already initialized."
fi

# Lancement final du serveur (foreground)
exec "$@"	