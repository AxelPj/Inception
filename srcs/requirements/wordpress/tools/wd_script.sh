#!/bin/bash

cd /var/www/html

SQL_PASSWORD="$(cat /run/secrets/db_password)"
SQL_ROOT_PASSWORD="$(cat /run/secrets/db_root_password)"

# wait mariadb to start with a little test to know if db respond
echo "Waiting mariadb..."
until mariadb -h mariadb -u $SQL_USER -p$SQL_PASSWORD -e "SELECT 1;" &> /dev/null; do
    sleep 1
done
echo "mariadb ready !"

# check installation
if [ ! -f ./wp-config.php ]; then
    echo "Wordpress not found. Installing..."

    wp core download --allow-root

    # link to db created in mariadb script
    wp config create \
        --dbname=$SQL_DATABASE \
	--dbuser=$SQL_USER \
	--dbpass=$SQL_PASSWORD \
	--dbhost=mariadb:3306 --allow-root

    # installation
    wp core install \
	--url=https://$DOMAIN_NAME\
	--title=$SITE_TITLE \
	--admin_user=$ADMIN_USER \
	--admin_password=$ADMIN_PASSWORD \
	--admin_email=$ADMIN_EMAIL --allow-root

    # create the 2sd user (1st: admin)
    wp user create \
	$USER2_LOGIN \
	$USER2_EMAIL \
	--role=author \
	--user_pass=$USER2_PASSWORD --allow-root

    echo "Worpress installed successfully !"
else
    echo "Wordpress is already installed"
fi

# return on dockerfile to run the CMD
exec "$@"