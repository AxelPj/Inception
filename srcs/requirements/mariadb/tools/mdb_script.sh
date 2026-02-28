#!/bin/bash

# secrets (sinon SQL_PASSWORD/SQL_ROOT_PASSWORD sont vides)
SQL_PASSWORD="$(tr -d '\n' < /run/secrets/db_password)"
SQL_ROOT_PASSWORD="$(tr -d '\n' < /run/secrets/db_root_password)"

# dossier socket/pid demandé par ton 50-server.cnf
mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld /var/lib/mysql

# tables système (sinon mysql.db/mysql.plugin manquent)
if [ ! -d "/var/lib/mysql/mysql" ]; then
	mariadb-install-db --user=mysql --datadir=/var/lib/mysql > /dev/null
fi

if [ ! -d "/var/lib/mysql/$SQL_DATABASE" ]; then
	service mariadb start

	# wait mariadb start
	until mysqladmin ping; do
		sleep 1
	done

	# configure the DB with SQL instructions
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

# start mariadb
exec "$@"