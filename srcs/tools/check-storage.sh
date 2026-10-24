#!/bin/sh
set -eu
expected_root=${1:?Expected Docker data directory is required}
actual_root=$(docker info --format '{{.DockerRootDir}}')
if [ "${actual_root%/}" != "${expected_root%/}" ]; then
    echo "Docker data-root must be $expected_root (currently $actual_root). See DEV_DOC.md." >&2
    exit 1
fi
volumes=$(docker volume ls --format '{{.Name}}')
for volume in inception_mariadb_data inception_wordpress_data; do
    if printf '%s\n' "$volumes" | grep -Fxq "$volume"; then
        options=$(docker volume inspect --format '{{json .Options}}' "$volume")
        if [ "$options" != null ] && [ "$options" != '{}' ]; then
            echo "$volume still has driver options. Follow DEV_DOC.md to migrate it." >&2
            exit 1
        fi
    fi
done
