# 🔄 Migrating an Existing Project to LampBox 2.3

LampBox is copied into each project, so older projects keep the files they were
created with. This guide brings a project installed with LampBox 1.x–2.2 up to
date without losing data.

---

## ⚠️ Read First: Database Data Directory

Since 2.1.0 the default data directory is `./data/mysql-${DATABASE}`. Projects
created before that keep their data in **`./data/mysql`**.

If your `.env` has no `MYSQL_DATA_DIR`, the new `docker-compose.yml` starts the
database on an **empty** directory: nothing is deleted, but your site loses its
data until you fix the path. Before starting anything, check where the data
actually is:

```bash
docker inspect <project>-database -f '{{range .Mounts}}{{if eq .Destination "/var/lib/mysql"}}{{.Source}}{{end}}{{end}}'
```

and set the same path in `.env`:

```bash
MYSQL_DATA_DIR=./data/mysql
MYSQL_LOG_DIR=./logs/mysql
```

On the first `./lamp.sh start`, lamp.sh may ask once whether this data was
created by your `DATABASE` engine (it cannot tell from a custom directory name),
then records the answer in `data/mysql.database`.

---

## 1. Back Up

```bash
# Database dump (works with any LampBox version)
docker compose exec -T database sh -c \
  'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec "$(command -v mariadb-dump || command -v mysqldump)" \
     -uroot --all-databases --single-transaction --routines --events --triggers' \
  | gzip > backup-before-migration.sql.gz

# Configuration
cp .env .env.bak-$(date +%F)
cp docker-compose.yml docker-compose.yml.bak-$(date +%F)

# Image currently running, for a rollback
docker tag <project>-webserver <project>-webserver:pre-migration
```

Never back up `data/mysql` by copying files while the database runs: the copy
is usually inconsistent. Use dumps (see [Backups](#8-backups)).

## 2. Update the LampBox Files

Copy these from the new release into the project:

- `lamp.sh`, `Makefile`
- `docker-compose.yml`, `docker-compose.proxy.yml`,
  `docker-compose.mysql-port.yml`, `docker-compose.production.yml`
- `bin/` (Dockerfiles)
- `config/apache/`, `config/php/php-production.ini`
- `config/phpmyadmin/config.inc.php` (compare first if you customised it)

Never overwrite `.env`, `www/`, `data/`, `logs/`, or files you customised
(`config/vhosts/`, `config/php/php.ini`). If `lamp.sh` is not executable:
`chmod +x lamp.sh init.sh`.

## 3. Update `.env`

List the variables that `sample.env` has and your `.env` lacks:

```bash
diff <(grep -oE '^[A-Z_]+=' sample.env | sort) <(grep -oE '^[A-Z_]+=' .env | sort)
```

Then review:

| Variable | What to do |
|---|---|
| `MYSQL_DATA_DIR`, `MYSQL_LOG_DIR` | Point to your existing directories (see above) |
| `PHPVERSION` | `php74`, `php8` and `php81` are no longer provided: use `php82` or later (see step 4) |
| `DATABASE` | `mysql8`, `mariadb103`-`mariadb106` and `mariadb121` are no longer provided (see step 4) |
| `MYSQL_PORT` | Leave empty unless a client on the host needs the database (it is no longer published by default) |
| `LAMPBOX_ENV` | `production` for a public site (see step 6) |
| `PHPMYADMIN_REQUIRE` | Who may open phpMyAdmin, e.g. `PHPMYADMIN_REQUIRE='ip 203.0.113.10'` (quotes included) |
| Values containing `$` or spaces | Put them between single quotes: `MYSQL_PASSWORD='abc$xyz'` |

## 4. Move Off Unsupported Versions

### PHP

PHP 7.4, 8.0 and 8.1 receive no security fixes. Before switching `PHPVERSION`:

- check the PHP versions supported by your application and its dependencies
  (`composer.json` → `require.php`, CMS documentation);
- update the application first if needed;
- after the switch, watch `logs/apache2/error.log` for deprecations and errors.

### Databases

| Removed | Use instead |
|---|---|
| `mysql8` | `mysql84`: same engine, the `mysql:8` image tag already pointed to 8.4 |
| `mariadb103` to `mariadb106` | `mariadb1011` or later (10.3-10.6 are end of life) |
| `mariadb121` | `mariadb123` (12.3 LTS) |

**`mysql8` → `mysql84`** keeps the data as is. Stop the project, then rename
the default data directory and its engine marker:

```bash
./lamp.sh stop
mv data/mysql-mysql8 data/mysql-mysql84
echo mysql84 > data/mysql-mysql84.database && rm -f data/mysql-mysql8.database
# .env: DATABASE=mysql84
./lamp.sh start
```

(With an explicit `MYSQL_DATA_DIR`, keep the directory and only update its
`.database` marker.)

**Older MariaDB → `mariadb1011` or later**: with the default per-engine
directories the new version starts on an empty directory, so move the data with
a dump:

```bash
./lamp.sh dump
# .env: DATABASE=mariadb1011 (or mariadb114, mariadb118, mariadb123)
./lamp.sh restart
make db-restore FILE=data/db-dumps/<dump>.sql.gz
```

The previous data directory is left untouched: delete it once the site is
checked. Dumps from 10.3 contain older system tables: restore only your
application databases from them.

## 5. Old Compose Files: What Changed

- **Database port**: older files published `3306` on every interface. It is now
  published only when `MYSQL_PORT` is set.
- **`version:` attribute**: obsolete, removed (Compose printed a warning).
- **Restart policy**: `always` became `unless-stopped`: a container you stop by
  hand stays stopped after a Docker restart.
- **Hand-written Traefik labels**: `docker-compose.proxy.yml` targets the
  shared LampBox Traefik (`lampbox_web` network, `*.local` certificate). If you
  use your own Traefik, keep your labels and network in a separate file (e.g.
  `docker-compose.traefik.yml`) rather than in `docker-compose.yml`, and list it
  in `COMPOSE_FILE`. To use the real client IP there too, mount
  `config/apache/remoteip.conf` in that file, only if the webserver publishes
  no host port.

## 6. Production Mode

For a site exposed on the Internet:

```bash
LAMPBOX_ENV=production
PHPMYADMIN_REQUIRE=            # empty = "all denied"
#PHPMYADMIN_REQUIRE='ip 203.0.113.10'   # or allow your IP (keep the quotes)
```

This hides PHP errors from visitors (they go to the Apache error log), turns
Xdebug off, removes the `X-Powered-By` header and denies phpMyAdmin.
`lamp.sh` applies `docker-compose.production.yml` by itself. If you run
`docker compose` directly, add the files to `.env`:

```bash
COMPOSE_FILE=docker-compose.yml:docker-compose.production.yml
```

## 7. Apply

```bash
./lamp.sh update   # rebuild the webserver on the latest PHP image, database untouched
./lamp.sh start    # apply the remaining changes (e.g. database port): containers whose
                   # settings changed are recreated, data stays in MYSQL_DATA_DIR
```

Check the result:

```bash
./lamp.sh info                                         # environment, phpMyAdmin rule
docker exec <project>-webserver php -r 'echo PHP_VERSION, PHP_EOL;'
docker port <project>-database                         # empty unless MYSQL_PORT is set
curl -sI https://your-site | grep -i x-powered-by      # nothing in production
```

The new compose file tags images per version (`<project>-webserver:php83`,
`<project>-database:mysql84`). The previous `<project>-webserver` and
`<project>-database` images are no longer used: remove them once the site is
checked.

**Rollback**: restore `.env` and `docker-compose.yml` from the backups, then
`docker tag <project>-webserver:pre-migration <project>-webserver` and
`docker compose up -d --no-deps webserver`.

## 8. Backups

```bash
./lamp.sh dump                                        # data/db-dumps/<project>-<date>.sql.gz
make db-restore FILE=data/db-dumps/<dump>.sql.gz      # restore
```

`dump` is consistent while the site runs and keeps the 7 most recent dumps
(`DB_DUMP_KEEP`). Schedule it before your file backups pick up the project, for
example in root's crontab:

```bash
30 20 * * * cd /path/to/project && ./lamp.sh dump >> /var/log/lampbox-dump.log 2>&1
```

## 9. Later Security Releases

When PHP publishes a security release, the official images are rebuilt within
hours. Then, in each project:

```bash
./lamp.sh update
```

It pulls the new base image, shows the old and new PHP versions, recreates only
the webserver and prints the rollback command.
