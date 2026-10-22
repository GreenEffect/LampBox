#!/bin/bash

# Builds one PHP version against every supported database and checks that
# PHP connects to each of them with mysqli and PDO.
#
# Each combination runs as a separate Compose project whose .env, data and
# logs live in ./buildtest/<project>/ and are deleted afterwards: the data of
# the current project is never touched. HTTP ports are bound to 127.0.0.1.
#
# Usage: ./dev_build_container.sh -b php83
# WSL2: keep the project on the Linux filesystem, not on a Windows mount.

dbarr=(mariadb1011 mariadb114 mariadb118 mariadb123 mysql84 mysql97)
phparr=(php82 php83 php84 php85)

usage() {
    echo "Usage: $0 -b <php version>"
    echo "       builds the PHP version against: ${dbarr[*]}"
    echo "       valid PHP versions: ${phparr[*]}"
}

checkdep() {
    echo "### checking dependencies"
    command -v docker >/dev/null || { echo 'Executable not found: docker'; exit 1; }
    docker compose version >/dev/null 2>&1 || { echo 'Docker Compose v2 ("docker compose") not found'; exit 1; }
}

# Compose command for the current combination
dc() {
    docker compose --env-file "$envfile" -p "$project" "$@"
}

buildenvfile() {
    mkdir -p "$dir/data" "$dir/logs/apache2" "$dir/logs/mysql"
    sed -e "s/^COMPOSE_PROJECT_NAME=.*/COMPOSE_PROJECT_NAME=$project/" \
        -e "s/^PHPVERSION=.*/PHPVERSION=$buildtarget/" \
        -e "s/^DATABASE=.*/DATABASE=$version/" \
        -e "s/^USER_ID=.*/USER_ID=$(id -u)/" \
        -e "s/^GROUP_ID=.*/GROUP_ID=$(id -g)/" \
        -e "s/^HTTP_PORT=.*/HTTP_PORT=127.0.0.1:${BUILDTEST_HTTP_PORT:-18080}/" \
        -e "s/^HTTPS_PORT=.*/HTTPS_PORT=127.0.0.1:${BUILDTEST_HTTPS_PORT:-18443}/" \
        -e "s|^MYSQL_DATA_DIR=.*|MYSQL_DATA_DIR=$dir/data|" \
        -e "s|^MYSQL_LOG_DIR=.*|MYSQL_LOG_DIR=$dir/logs/mysql|" \
        -e "s|^APACHE_LOG_DIR=.*|APACHE_LOG_DIR=$dir/logs/apache2|" \
        sample.env > "$envfile"
}

# Wait up to 3 minutes for the database, then connect from PHP
check_db() {
    local out i
    for i in $(seq 1 90); do
        if out=$(dc exec -T webserver php -r '
                $h = getenv("MYSQL_HOST"); $d = getenv("MYSQL_DATABASE");
                $u = getenv("MYSQL_USER"); $p = getenv("MYSQL_PASSWORD");
                mysqli_report(MYSQLI_REPORT_OFF);
                $m = @new mysqli($h, $u, $p, $d);
                if ($m->connect_errno) { echo "mysqli: ", $m->connect_error; exit(1); }
                try { $pdo = new PDO("mysql:host=$h;dbname=$d", $u, $p); }
                catch (PDOException $e) { echo "PDO: ", $e->getMessage(); exit(1); }
                echo "mysqli + PDO OK, server ", $pdo->query("SELECT VERSION()")->fetchColumn();' 2>&1); then
            echo "### $out"
            return 0
        fi
        sleep 2
    done
    echo "### ERROR: $out"
    return 1
}

# Remove the files, containers, network and images of the combination.
# The data and MySQL logs belong to the container's mysql user, so they are
# deleted from a throwaway container; the .env must stay until 'down' ran.
cleanup() {
    echo "### cleaning up $project"
    dc run --rm --no-deps -T --entrypoint sh -v "$PWD/$dir:/combination" database \
        -c 'rm -rf /combination/data /combination/logs' >/dev/null 2>&1
    dc down --rmi all >/dev/null 2>&1
    rm -rf "$dir" 2>/dev/null
    [ -d "$dir" ] && echo "### WARNING: could not remove $dir"
}

buildtarget=""
while getopts ":b:" opt; do
    case "$opt" in
        b) buildtarget=$OPTARG ;;
        *) usage; exit 1 ;;
    esac
done

if [[ ! " ${phparr[*]} " == *" $buildtarget "* ]]; then
    usage
    exit 1
fi

checkdep
mkdir -p ./buildtest
failed=()

for version in "${dbarr[@]}"; do
    project="buildtest-$buildtarget-$version"
    dir="./buildtest/$project"
    envfile="$dir/.env"

    echo "### building $buildtarget + $version"
    buildenvfile
    if dc up -d --build && check_db; then
        echo -e "\n OK - $buildtarget + $version\n"
    else
        echo -e "\n ### FAILED - $buildtarget + $version\n"
        dc logs --tail 20
        failed+=("$version")
    fi
    cleanup
done

if [ ${#failed[@]} -gt 0 ]; then
    echo "### $buildtarget failed with: ${failed[*]}"
    exit 1
fi
echo "### $buildtarget works with: ${dbarr[*]}"
