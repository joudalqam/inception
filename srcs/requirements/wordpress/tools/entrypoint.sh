#!/bin/sh
set -eu

password=$(cat /run/secrets/mysql_password)
admin_password=$(cat /run/secrets/wp_admin_password)
user_password=$(cat /run/secrets/wp_user_password)
: "${DOMAIN_NAME:?DOMAIN_NAME is required}"
: "${WP_USER:=author}"
: "${WP_USER_EMAIL:=author@${DOMAIN_NAME}}"

case "$DOMAIN_NAME" in
    *[!a-zA-Z0-9.-]*|'') echo "DOMAIN_NAME must be a hostname, without a URL scheme." >&2; exit 1 ;;
esac
if [ "$WP_ADMIN_USER" = "$WP_USER" ]; then
    echo "The WordPress administrator and author must have different usernames." >&2
    exit 1
fi
case "$(printf '%s' "$WP_ADMIN_USER" | tr '[:upper:]' '[:lower:]')" in
    *admin*) echo "The administrator username must not contain admin." >&2; exit 1 ;;
esac

# Query with the application account: ping alone does not verify authentication.
i=0
until MYSQL_PWD="$password" timeout 3 mariadb --protocol=TCP -h mariadb \
    --connect-timeout=2 -u"${MYSQL_USER}" "${MYSQL_DATABASE}" \
    -e 'SELECT 1;' >/dev/null 2>&1; do
    i=$((i + 1))
    if [ "$i" -ge 60 ]; then
        echo "wordpress: database unavailable after 60 readiness attempts" >&2
        exit 1
    fi
    sleep 1
done

cd /var/www/html
if [ ! -f wp-includes/version.php ] || [ ! -f index.php ]; then
    cp -a /usr/src/wordpress/. .
fi

if [ ! -s wp-config.php ]; then
    # WP-CLI quotes PHP values correctly, including passwords with punctuation.
    wp config create --dbname="$MYSQL_DATABASE" --dbuser="$MYSQL_USER" \
        --dbpass="$password" --dbhost=mariadb:3306 --skip-check --allow-root
fi
chown -R www-data:www-data /var/www/html
chmod 640 wp-config.php

if ! wp core is-installed --allow-root >/dev/null 2>&1; then
    wp core install \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${admin_password}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email \
        --allow-root
fi

# Repair saved URLs on existing installations as well as new ones.
wp option update home "https://${DOMAIN_NAME}" --allow-root
wp option update siteurl "https://${DOMAIN_NAME}" --allow-root
if ! wp user get "$WP_USER" --field=ID --allow-root >/dev/null 2>&1; then
    wp user create "$WP_USER" "$WP_USER_EMAIL" --user_pass="$user_password" \
        --role=author --allow-root
fi

exec "$@"
