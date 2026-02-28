#!/bin/bash

set -e

SQL_PASSWORD="$(tr -d '\n' < /run/secrets/db_password)"
SQL_ROOT_PASSWORD="$(tr -d '\n' < /run/secrets/db_root_password)"

if [ ! -d "/var/lib/mysql/mysql" ]; then
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql > /dev/null
fi

if [ ! -d "/var/lib/mysql/$SQL_DATABASE" ]; then
    mariadbd --user=mysql &    # ← fix ici

    until mysqladmin ping --silent; do
        sleep 1
    done

    mariadb -e "CREATE DATABASE IF NOT EXISTS \`${SQL_DATABASE}\`;"
    mariadb -e "CREATE USER IF NOT EXISTS \`${SQL_USER}\`@'%' IDENTIFIED BY '${SQL_PASSWORD}';"
    mariadb -e "GRANT ALL PRIVILEGES ON \`${SQL_DATABASE}\`.* TO \`${SQL_USER}\`@'%';"
    mariadb -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${SQL_ROOT_PASSWORD}';"
    mariadb -u root -p"${SQL_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"
    mysqladmin -u root -p"${SQL_ROOT_PASSWORD}" shutdown
    echo "DB Created !"
else
    echo "DB Already exist"
fi

exec "$@"