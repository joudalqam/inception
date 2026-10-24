#!/bin/sh
set -eu
umask 077
mkdir -p secrets
for name in db_root_password db_password credentials wp_user_password; do
    file="secrets/$name.txt"
    if [ ! -e "$file" ]; then
        openssl rand -hex 32 > "$file"
    elif [ ! -s "$file" ]; then
        echo "Secret file $file is empty; fill it before starting." >&2
        exit 1
    fi
    chmod 600 "$file"
done
