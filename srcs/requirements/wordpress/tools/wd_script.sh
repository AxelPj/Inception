#!/bin/bash
set -e

cd /var/www/html

SQL_PASSWORD="$(cat /run/secrets/db_password)"
WP_PASSWORD="$(cat /run/secrets/wd_password)"

echo "Waiting mariadb..."
until mariadb -h mariadb -u "$SQL_USER" -p"$SQL_PASSWORD" -e "SELECT 1;" &>/dev/null; do
  sleep 1
done
echo "mariadb ready !"

if ! wp core is-installed --allow-root 2>/dev/null; then
  echo "WordPress not installed. Installing..."

  if [ ! -f ./wp-load.php ]; then
    wp core download --allow-root
  else
    echo "WordPress files already present, skip download."
  fi

  if [ ! -f ./wp-config.php ]; then
    wp config create \
      --dbname="$SQL_DATABASE" \
      --dbuser="$SQL_USER" \
      --dbpass="$SQL_PASSWORD" \
      --dbhost="mariadb:3306" --allow-root
  fi

  wp core install \
    --url="https://$DOMAIN_NAME" \
    --title="$WP_TITLE" \
    --admin_user="$WP_ADMIN_USER" \
    --admin_password="$WP_PASSWORD" \
    --admin_email="$WP_ADMIN_EMAIL" --allow-root

  wp user create \
    "$WP_USER" \
    "$WP_USER_EMAIL" \
    --role=author \
    --user_pass="$WP_PASSWORD" --allow-root || true

  echo "WordPress installed successfully!"
else
  echo "WordPress is already installed"
fi

exec /usr/sbin/php-fpm8.2 -F