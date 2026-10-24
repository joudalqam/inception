#!/bin/sh
set -eu

root_password=$(cat /run/secrets/mysql_root_password)
user_password=$(cat /run/secrets/mysql_password)

mkdir -p /var/lib/mysql /run/mysqld
chown -R mysql:mysql /var/lib/mysql /run/mysqld

# Existing databases are not reconfigured on each container restart.
# Keep a separate in-progress marker so a failed first setup can be retried.
if [ -d /var/lib/mysql/mysql ] && [ ! -f /var/lib/mysql/.initializing ]; then
    echo "mariadb: existing database found; skipping account initialization"
    exec mysqld --user=mysql --console
fi

touch /var/lib/mysql/.initializing
if [ ! -d /var/lib/mysql/mysql ]; then
    # Fresh volume: create the system tables.
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql >/dev/null
fi

sock=/run/mysqld/mysqld.sock
mysqld --user=mysql --skip-networking --socket="$sock" &
tmp_pid=$!
cleanup() {
    kill "$tmp_pid" 2>/dev/null || true
    wait "$tmp_pid" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

i=0
until timeout 2 mariadb-admin --socket="$sock" ping >/dev/null 2>&1; do
    if ! kill -0 "$tmp_pid" 2>/dev/null; then
        echo "mariadb: temporary server exited unexpectedly" >&2
        exit 1
    fi
    i=$((i + 1))
    if [ "$i" -ge 30 ]; then
        echo "mariadb: temporary server failed to start" >&2
        exit 1
    fi
    sleep 1
done

# New Debian databases authenticate the operating-system root over the socket.
# A retry after partial initialization may instead need the configured password.
if mariadb --no-defaults --protocol=SOCKET --socket="$sock" -uroot \
    -e "SELECT 1;" >/dev/null 2>&1; then
    unset MYSQL_PWD
elif MYSQL_PWD="$root_password" mariadb --no-defaults --protocol=SOCKET \
    --socket="$sock" -uroot -e "SELECT 1;" >/dev/null 2>&1; then
    export MYSQL_PWD="$root_password"
else
    echo "mariadb: cannot finish initialization: root authentication failed." >&2
    echo "Restore the root secret used to initialize this volume; do not delete the data." >&2
    exit 1
fi

# Use doubled quotes with backslash escaping disabled for this SQL session.
sql_quote() { printf '%s' "$1" | sed "s/'/''/g"; }
root_sql=$(sql_quote "$root_password")
user_sql=$(sql_quote "$MYSQL_USER")
password_sql=$(sql_quote "$user_password")
database_sql=$(printf '%s' "$MYSQL_DATABASE" | sed 's/`/``/g')

mariadb --no-defaults --protocol=SOCKET --socket="$sock" -uroot <<SQL
SET SESSION sql_mode = 'NO_BACKSLASH_ESCAPES';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${root_sql}';
CREATE DATABASE IF NOT EXISTS \`${database_sql}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${user_sql}'@'%' IDENTIFIED BY '${password_sql}';
GRANT ALL PRIVILEGES ON \`${database_sql}\`.* TO '${user_sql}'@'%';
FLUSH PRIVILEGES;
SQL

MYSQL_PWD="$root_password" mariadb-admin --no-defaults --protocol=SOCKET \
    --socket="$sock" -uroot shutdown
wait "$tmp_pid" 2>/dev/null || true
trap - EXIT HUP INT TERM
unset MYSQL_PWD
touch /var/lib/mysql/.initialized
rm -f /var/lib/mysql/.initializing

exec mysqld --user=mysql --console
