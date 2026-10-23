# Changelog - LampBox

### 3.0.0 - 2026-10-23
Lessons from the PHP2Shell security release (CVE-2026-109618 / CVE-2026-109619).
Major version: end-of-life PHP and database versions and `init.bat` are removed. For a site created with an older LampBox, start from a fresh 3.0 copy and move the site into it (`docs/MIGRATION.md`); updating the old project in place is not recommended

✅ **Production mode**: `LAMPBOX_ENV=production` applies `docker-compose.production.yml` and `config/php/php-production.ini` (errors logged but not displayed, Xdebug off, `expose_php` off, strict HttpOnly sessions); an invalid value stops `lamp.sh`  
✅ **phpMyAdmin**: access rule set by `PHPMYADMIN_REQUIRE` (`all granted` in development, `all denied` in production, or e.g. `PHPMYADMIN_REQUIRE='ip 203.0.113.10'`); root login disabled (`AllowRoot = false`); updated from 5.2.1 to 5.2.3  
✅ Reverse proxy mode mounts `config/apache/remoteip.conf` so Apache sees the real client IP (logs and IP rules); never applied in direct port mode  
✅ `session.upload_progress.enabled = Off` in both php.ini files (recommended by GHSA-6wmf-4rv5-p3rp even after patching); `#` comments replaced by `;`  
✅ New `./lamp.sh update` (`make update`): pulls the latest PHP image, rebuilds and recreates the webserver only, checks the PHP version and keeps a `-pre-update` copy of the image for a rollback  
✅ New `./lamp.sh dump`: consistent dump to `data/db-dumps/` with integrity check and rotation (`DB_DUMP_KEEP`); `make db-backup` uses it, `make db-restore` accepts `.sql.gz`  
✅ Database passwords are read from the container environment (`MYSQL_PWD`) instead of `-p<password>` (visible in `ps`, altered by `$`); `./lamp.sh mysql` also works with recent MariaDB images  
✅ Fixed `./lamp.sh rebuild` never picking up PHP security releases: it now builds with `--pull` (and uses the project compose files)  
✅ `bin/php82` follows `php:8.2-apache-bookworm` instead of the pinned `php:8.2.1-apache-buster`  
✅ Pinned PECL extensions for PHP 8.5 (xdebug 3.5.3, redis 6.3.0, imagick 3.8.1)  
✅ Removed end-of-life PHP 8.0 (`php8`) and 8.1 (`php81`)  
✅ Removed the `test/` scripts; fixed `dev_build_container.sh` turning `PHPVERSION=php83` into `php823`  
✅ `sample.env` documents single-quoting values that contain `$`  
✅ New `docs/MIGRATION.md`: moving a site into a fresh 3.0 copy (recommended: dump, new project, restore, `mariadb-upgrade` after a dump from an older MariaDB), and, not recommended, updating a project in place (data directory, database port, PHP versions, production mode, backups)  
✅ Shell scripts are now executable (`./init.sh`, `./lamp.sh` failed with "Permission denied" on a fresh clone)  
✅ New `.gitattributes`: files keep LF endings on a Windows clone (`core.autocrlf=true` turned `lamp.sh`, Dockerfiles and `.env` into CRLF, which bash and the containers reject)  
✅ Fixed `lamp.sh` (start check, `clean`, `clean-db`) and `init.sh` targeting `data/mysql` instead of the configured `MYSQL_DATA_DIR` (default `data/mysql-<DATABASE>`); `clean-db` now deletes through a database container (the files belong to the container's mysql user) and no longer recreates a `.gitkeep` that prevented MySQL from initializing; the engine marker is stored next to the data directory and written automatically  
✅ Images are tagged per version (`<project>-webserver:<PHPVERSION>`, `<project>-database:<DATABASE>`) and `./lamp.sh start` builds them (`up --build`, cached): after changing `DATABASE` or `PHPVERSION`, the single per-project image was reused and the old engine initialized the new data directory  
✅ Removed end-of-life MariaDB 10.3, 10.4, 10.5 and 10.6 (`mariadb103`-`mariadb106`)  
✅ Replaced MariaDB 12.1 (short-term release, end of life 2026-02) with 12.3 LTS (`mariadb123`, supported until 2029-06)  
✅ Removed `mysql8`: its `mysql:8` tag already ran MySQL 8.4 (8.0 is end of life since 2026-04); `DATABASE=mysql84` is the new default  
✅ Added MariaDB 11.4 LTS (`mariadb114`) and MySQL 9.7 LTS (`mysql97`, without `mysql_native_password`, removed in MySQL 9)  
✅ Fixed `./lamp.sh start --proxy` (and `make start-proxy`) starting Traefik without applying `docker-compose.proxy.yml` when `USE_REVERSE_PROXY=false`  
✅ `make stop` and `make info` go through `lamp.sh` (overrides, environment, phpMyAdmin rule); `init.sh` suggests `./lamp.sh start` and shows the environment  
✅ `dev_build_container.sh` rewritten: Docker Compose v2, isolated projects in `./buildtest/` (the project's data is never touched), mysqli and PDO checked from PHP instead of a missing test page, full cleanup (also under Git Bash) and a summary exit code  
✅ `lamp.sh` help shows colors instead of raw `\033` codes; the `Makefile` works without `.env` (`make init`, `make help`)  
✅ `lamp.sh` and `init.sh` report an `.env` that bash cannot load (e.g. an unquoted value with spaces) with the faulty line, instead of failing with "command not found"  
✅ `init.sh` generates a 32-character phpMyAdmin Blowfish secret, the length phpMyAdmin expects (64 characters triggered a "longer than necessary" warning; the `xxd` fallback split the key over two lines)  
✅ Removed `init.bat`: on Windows, use `init.sh` and `lamp.sh` from Git Bash or WSL2. It duplicated `init.sh` without its later changes, left the phpMyAdmin secret empty, never overwrote `.env` when asked to, and could not run `lamp.sh` (`start`, `update`, `dump`, production mode) anyway. Supported platforms are now stated: Linux (tested, development and production), macOS and Windows (development, not systematically tested)  
✅ Fixed `make clean` always answering "Clean cancelled" on Linux (its recipe used bash syntax under `/bin/sh`); it now runs `./lamp.sh clean`, which also offers to delete the database data  
✅ `lamp.sh` and `init.sh` show correct addresses for ports bound to an IP (`HTTP_PORT=127.0.0.1:8080` displayed `http://localhost:127.0.0.1:8080`); `./lamp.sh info` no longer shows `localhost:` as the host address of an unpublished database  
✅ Direct HTTPS on `HTTPS_PORT` works: the `*:443` vhost is enabled automatically once `config/ssl` holds a certificate (`./generate-ssl-certs.sh localhost`); it was commented out, so the port served plain HTTP even with a certificate. `./lamp.sh info` shows whether HTTPS is enabled  
✅ Confirmation prompts of `lamp.sh` and `init.sh` treat a closed input (cron, CI, no terminal) as "No" and say so, instead of exiting silently with an error  
✅ Documentation starts and restarts projects with `./lamp.sh` instead of `docker compose up -d`, which ignores the proxy, MySQL port and production overrides (the troubleshooting steps for `MYSQL_PORT` never published the port); direct `docker compose` usage is documented with `COMPOSE_PATH_SEPARATOR=:` and `COMPOSE_FILE` in `.env`, which work on every OS and with `lamp.sh`

### 2.2.0 - 2026-07-15
✅ Replaced the per-project Nginx reverse proxy with a single **shared Traefik** instance  
✅ Multiple projects now run in parallel behind one proxy — fixes `Bind for 0.0.0.0:80 failed: port is already allocated`  
✅ Label-based routing: each project is served at `https://<PROJECT_DOMAIN>` via the shared `lampbox_web` network  
✅ Shared `*.local` TLS certificate (`traefik/generate-certs.sh`) instead of a per-project one  
✅ New management commands: `./lamp.sh proxy-up` and `./lamp.sh proxy-down` (+ Makefile targets)  
✅ Reverse proxy override now clears the webserver host ports with `!reset` so proxied projects never bind 80/443/8080  
✅ **`MYSQL_PORT` is now empty by default**: the database is no longer published on the host, so multiple projects run in parallel out of the box. Set a unique value per project only when a GUI client needs host access  
✅ Fixed `MYSQL_PORT=` (empty) never actually disabling the database host port: the old `docker-compose.no-mysql-port.yml` used a no-op `ports: []` and `${MYSQL_PORT:-3306}` fell back to 3306, so a 2nd project always collided on 3306 and failed to start  
✅ Inverted the database port logic — the base stack no longer publishes it; the new `docker-compose.mysql-port.yml` **adds** it only when `MYSQL_PORT` is set (replaces `docker-compose.no-mysql-port.yml`)  
✅ Removed `config/nginx/` and the `NGINX_*` variables from `sample.env`  
✅ Updated documentation (README, QUICKSTART, EXAMPLES, TROUBLESHOOTING, WINDOWS)

### 2.1.0 - 2026-05-11
✅ Fixed reverse proxy domain substitution and phpMyAdmin redirect handling  
✅ Fixed SSL certificate generation under Git Bash/Windows (MSYS path conversion)  
✅ Updated Nginx config to use modern HTTP/2 syntax  
✅ Added compose overrides for proxy mode and optional MySQL port handling  
✅ Added version-specific MySQL/MariaDB data directories and compatibility checks  
✅ Updated documentation to reflect new reverse proxy startup flow

### 2.0.2 - 2026-01-20
✅ Add PHP 8.5 support  
✅ Add MySQL 8.4 support  
✅ Add MariaDB 10.11, 11.8, 12.1 support  
✅ Update documentation with new versions  
✅ Add test scripts in /test directory with logging system  
✅ Update sample.env with new version options

### 2.0.1 - 2025-11-30
✅ Delete reference to php7*  
✅ Add php 8.4 support  
✅ Update docs & references  

### 2.0.0 - 2025-11-29
✅ Cross-platform support (Linux, macOS, Windows)  
✅ Dual access mode (direct ports or reverse proxy)  
✅ Multi-project support with isolation  
✅ Automatic permission handling (USER_ID/GROUP_ID)  
✅ Complete automation scripts (init.sh, lamp.sh, etc.)  
✅ Extensive documentation (10+ guides, 3600+ lines)  
✅ MySQL troubleshooting tools  
✅ Fixed: UID/GID readonly variable issue  
✅ Fixed: MySQL data directory initialization  

### Major Changes from v1.x
✅ Removed Traefik (simplified stack)  
✅ Removed Ansible (direct configuration)  
✅ Added Nginx reverse proxy (optional)  
✅ Added dual access modes (ports vs domains)  
✅ Full Windows support (Git Bash/WSL2/CMD)  
✅ Auto-generated phpMyAdmin secrets  
✅ Fixed permission handling cross-platform  
✅ Improved documentation and examples  