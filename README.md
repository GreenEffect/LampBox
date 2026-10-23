<div align="center">
  <img src="docs/LampBox_Logo.png" alt="LampBox Logo" width="200">
</div>

# 🐳 LampBox v3.0.0

Modern, cross-platform LAMP stack with Docker, for local development and production.

![PHP](https://img.shields.io/badge/PHP-8.2%20to%208.5-777BB4?logo=php)
![MySQL](https://img.shields.io/badge/MySQL-8.4%2C%209.7-4479A1?logo=mysql)
![MariaDB](https://img.shields.io/badge/MariaDB-10.11--12.3-003545?logo=mariadb)
![Apache](https://img.shields.io/badge/Apache-2.4-D22128?logo=apache)
![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey)

## ✨ Features

- 🚀 **Multiple PHP versions** (8.2, 8.3, 8.4, 8.5)
- 💾 **Multiple databases** (MySQL 8.4, 9.7, MariaDB 10.11, 11.4, 11.8, 12.3)
- 🔒 **HTTPS/SSL**: automatic behind Traefik, or on `HTTPS_PORT` once `./generate-ssl-certs.sh` has created a certificate
- 🎯 **Dual access modes**: Direct ports or shared reverse proxy (Traefik, multi-project)
- 🔧 **phpMyAdmin** included and pre-configured
- 🔐 **Production mode**: hardened PHP settings, protected phpMyAdmin, safe PHP updates and consistent database dumps
- 🌍 **Cross-platform**: Linux, macOS, Windows (Git Bash/WSL2)
- 📦 **Isolated projects**: Run multiple LAMP stacks simultaneously
- ⚡ **Auto-configuration**: Permissions and secrets handled automatically

## 📋 Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop) installed and running
- **Windows users**: [Git Bash](https://git-scm.com/downloads) or WSL2 (the scripts need bash)

### Supported Platforms

| Platform | Use | Tested |
|---|---|---|
| Linux | development and production | yes |
| macOS | development | not systematically |
| Windows (Git Bash or WSL2) | development | not systematically |

## 🚀 Quick Start (30 seconds)

```bash
# 1. Clone or extract the project
cd LampBox/

# 2. Initialize (auto-configures everything)
./init.sh

# 3. Start the stack
./lamp.sh start

# 4. Access your site
# → http://localhost:8080
# → phpMyAdmin: http://localhost:8080/lamp-mysql
```

**Default credentials:**
- MySQL User: `docker` / Password: `docker`
- MySQL Root: `root` / Password: `tiger` (command line only: root login is disabled in phpMyAdmin)

## 📖 Documentation

- **[Quick Start Guide](docs/QUICKSTART.md)** - Get started in 5 minutes
- **[Examples](docs/EXAMPLES.md)** - Real-world use cases and configurations
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[Windows Guide](docs/WINDOWS.md)** - Windows-specific instructions
- **[Migration Guide](docs/MIGRATION.md)** - Update a project created with an older LampBox
- **[Changelog](CHANGELOG.md)** - Version history

## ⚙️ Configuration

All configuration is done via the `.env` file (created by `init.sh`):

```bash
# Project name (must be unique per project)
COMPOSE_PROJECT_NAME=lamp

# PHP version (php82, php83, php84, php85)
PHPVERSION=php83

# Database (mysql84, mysql97, mariadb1011, mariadb114, mariadb118, mariadb123)
DATABASE=mysql84

# Ports (change if running multiple projects in direct port mode)
HTTP_PORT=8080
HTTPS_PORT=8443

# Database port on the host: empty = not published (safe default for
# multiple projects). Set a UNIQUE value per project only if you need a
# GUI client (TablePlus, DBeaver...): 3306, 3307, ...
MYSQL_PORT=

# Access mode
USE_REVERSE_PROXY=false  # false=ports, true=domains

# Environment (see Production Mode below)
LAMPBOX_ENV=development  # or production
```

### Switching PHP Versions

```bash
# Edit .env
PHPVERSION=php84  # or php82, php83, php85

# Rebuild (pulls the latest PHP image) and restart
./lamp.sh rebuild
```

### Applying PHP Security Releases

The PHP images follow the latest patch release of their branch (e.g.
`php:8.3-apache-bookworm`). When PHP publishes a security fix:

```bash
./lamp.sh update
```

It pulls the new base image, shows the running and new PHP versions, recreates
**only** the webserver (the database is untouched) and keeps the previous image
as `<project>-webserver:<PHPVERSION>-pre-update` for a rollback. A plain
`docker compose up -d --build` does **not** pull a newer base image.

### Switching Database

```bash
# Keep a dump of the current data
./lamp.sh dump

# Edit .env
DATABASE=mariadb1011  # or mysql84, mysql97, mariadb114, mariadb118, mariadb123

# Restart: each engine uses its own directory (data/mysql-<DATABASE>), so the
# new one starts empty and the previous data stays untouched
./lamp.sh restart
```

Then import your application databases from the dump if needed. With a custom
`MYSQL_DATA_DIR` shared by several engines, run `./lamp.sh clean-db` before
switching: `lamp.sh` refuses to start an engine on data created by another one.

## 🛠️ Management Commands

Using the `lamp.sh` helper script:

```bash
./lamp.sh start          # Start containers
./lamp.sh stop           # Stop containers
./lamp.sh restart        # Restart containers
./lamp.sh logs [-f]      # View logs (follow mode optional)
./lamp.sh status         # Show container status
./lamp.sh info           # Show connection info

./lamp.sh shell          # Access webserver shell
./lamp.sh mysql          # Access MySQL shell (root)
./lamp.sh dump           # Dump all databases to data/db-dumps/

./lamp.sh rebuild        # Rebuild images (pulls updated base images)
./lamp.sh update         # Apply a PHP security release (webserver only)
./lamp.sh clean          # Clean everything (containers + data)
./lamp.sh clean-db       # Clean database only
./lamp.sh ssl            # Generate SSL certificates
```

Or use Docker Compose directly. It only reads `docker-compose.yml`: list the
overrides you need (proxy, MySQL port, production) in `COMPOSE_FILE` in `.env`
(see `sample.env`).

```bash
docker compose up -d              # Start
docker compose down               # Stop
docker compose logs -f            # Logs
docker compose ps                 # Status
docker compose exec webserver bash   # Shell
```

## 🌐 Dual Access Modes

### Mode 1: Direct Port Access (Default)

Access via `http://localhost:8080`

HTTPS on `https://localhost:8443` (`HTTPS_PORT`) is enabled as soon as a
certificate exists in `config/ssl`:

```bash
./generate-ssl-certs.sh localhost   # self-signed (or put your own cert.pem / cert-key.pem there)
./lamp.sh restart
```

**Pros:** Simple, no configuration needed  
**Cons:** Different ports per project

### Mode 2: Domain-Based Access (Traefik reverse proxy)

Access via `https://myproject.local`.

Routing is handled by a **single, shared Traefik instance** that owns ports
80/443 for the whole machine. Each project attaches to a shared Docker network
and is routed by its domain — so you can run **many projects in parallel**
without any port conflicts.

**Setup:**

```bash
# 1. Edit .env
USE_REVERSE_PROXY=true
PROJECT_DOMAIN=myproject.local      # must be unique per project

# 2. Add to /etc/hosts (or C:\Windows\System32\drivers\etc\hosts)
127.0.0.1    myproject.local

# 3. Start the shared Traefik proxy once (creates the network + TLS cert)
./lamp.sh proxy-up

# 4. Start your project behind Traefik
./lamp.sh start
```

`./lamp.sh start` also runs `proxy-up` automatically if Traefik isn't up yet.

**Pros:** Clean URLs, HTTPS by default, unlimited parallel projects  
**Cons:** Requires hosts file modification

## 🔀 Running Multiple Projects

### In direct port mode

Each project needs unique identifiers and ports:

```bash
# Project 1
COMPOSE_PROJECT_NAME=lamp-project1
HTTP_PORT=8080
MYSQL_PORT=3306

# Project 2
COMPOSE_PROJECT_NAME=lamp-project2
HTTP_PORT=8081
MYSQL_PORT=3307
```

### In reverse proxy mode (recommended)

Give each project a unique `COMPOSE_PROJECT_NAME` and `PROJECT_DOMAIN`, then let
the shared Traefik route them. No port juggling required:

```bash
# One-time: start the shared proxy
./lamp.sh proxy-up

# Project 1 (.env: PROJECT_DOMAIN=project1.local, COMPOSE_PROJECT_NAME=project1)
cd project1 && ./lamp.sh start      # → https://project1.local

# Project 2 (.env: PROJECT_DOMAIN=project2.local, COMPOSE_PROJECT_NAME=project2)
cd project2 && ./lamp.sh start      # → https://project2.local
```

Each project keeps its own PHP version, its own database and its own
phpMyAdmin (`https://projectN.local/<COMPOSE_PROJECT_NAME>-mysql`).

## 📂 Project Structure

```
LampBox/
├── bin/                      # Dockerfiles for PHP and database versions
├── config/
│   ├── apache/              # remoteip.conf (real client IP behind Traefik)
│   ├── vhosts/              # Apache virtual hosts
│   ├── php/                 # php.ini (development), php-production.ini
│   ├── ssl/                 # SSL certificates (direct Apache HTTPS)
│   ├── phpmyadmin/          # phpMyAdmin config
│   └── initdb/              # MySQL init scripts (.sql, .sh)
├── traefik/                 # Shared Traefik reverse proxy stack
│   ├── docker-compose.yml   # Traefik service (owns ports 80/443)
│   ├── traefik.yml          # Static config (entrypoints, providers)
│   ├── dynamic.yml          # TLS default certificate config
│   ├── generate-certs.sh    # Shared *.local certificate generator
│   └── certs/               # Shared TLS certificate (generated)
├── data/
│   ├── mysql-<DATABASE>/    # MySQL data (persistent)
│   └── db-dumps/            # Dumps from ./lamp.sh dump
├── logs/
│   ├── apache2/             # Apache logs
│   └── mysql-<DATABASE>/    # MySQL logs
├── www/                      # Your web files (document root)
├── docs/                     # Documentation
├── docker-compose.yml        # Base stack (webserver + database)
├── docker-compose.proxy.yml  # Reverse proxy override (Traefik labels)
├── docker-compose.mysql-port.yml # Publishes the DB port (if MYSQL_PORT is set)
├── docker-compose.production.yml # Production settings (if LAMPBOX_ENV=production)
├── sample.env               # Environment template
├── init.sh                  # Initialization script (Linux/Mac/Git Bash/WSL2)
├── lamp.sh                  # Management helper script
├── generate-ssl-certs.sh    # SSL cert generator (direct Apache HTTPS)
└── check-system.sh          # System requirements checker
```

## 🔧 Development Tools

### Xdebug

Xdebug is included (develop mode by default, turned off with
`LAMPBOX_ENV=production`). VS Code configuration in `.vscode/launch.json`:

```json
{
  "name": "Listen for Xdebug",
  "type": "php",
  "request": "launch",
  "port": 9003,
  "pathMappings": {
    "/var/www/html": "${workspaceFolder}/www"
  }
}
```

### Database Access

**Via phpMyAdmin:**
- URL: `http://localhost:8080/lamp-mysql`
- User: `docker` / Pass: `docker` (root login is disabled)
- Access is controlled by `PHPMYADMIN_REQUIRE` in `.env` (e.g. `PHPMYADMIN_REQUIRE='ip 203.0.113.10'`, quotes included);
  denied by default in production

**Via CLI:**
```bash
./lamp.sh mysql
# or ('mysql' on MySQL images, 'mariadb' on MariaDB images)
docker compose exec database mysql -u docker -p
```

**External connection (GUI client on your host):**

Disabled by default — `MYSQL_PORT` is empty so nothing is published on the host,
which lets several projects run side by side. To enable it, set a **unique**
port in that project's `.env` and restart:

```bash
MYSQL_PORT=3306    # use 3307, 3308... for further projects
```

- Host: `localhost`
- Port: the `MYSQL_PORT` value you set
- User: `docker` / Pass: `docker`

## 🐛 Troubleshooting

### Common Issues

**"Port already in use"**
```bash
# Change ports in .env
HTTP_PORT=8081
MYSQL_PORT=3307
```

**"Permission denied" (Linux/Mac)**
```bash
# Re-run init to fix permissions
./init.sh
```

**MySQL won't start: "data directory has files"**
```bash
# Clean database and restart
./lamp.sh clean-db
./lamp.sh start
```

**phpMyAdmin: "Permissions incorrect"**
```bash
# Fix permissions
chmod 644 config/phpmyadmin/config.inc.php
docker compose restart webserver
```

**Scripts don't work: "readonly variable"**
```bash
# Variables already fixed in latest version
# If using old .env, update USER_ID/GROUP_ID variables
sed -i 's/^UID=/USER_ID=/' .env
sed -i 's/^GID=/GROUP_ID=/' .env
```

**More help:** See [Troubleshooting Guide](docs/TROUBLESHOOTING.md)

## 🖥️ Windows Users

`init.sh` and `lamp.sh` are bash scripts. Run them from:

1. **Git Bash** (recommended) - installed with Git for Windows
2. **WSL2** - Linux experience on Windows

`init.bat` was removed in 3.0.0. Plain `docker compose` commands also work
from CMD or PowerShell once `.env` exists.

See [Windows Guide](docs/WINDOWS.md) for detailed instructions.

## 🔐 Production Mode

LampBox defaults to development settings. For a site exposed on the Internet,
set in `.env`:

```bash
LAMPBOX_ENV=production
PHPMYADMIN_REQUIRE=            # empty = "all denied"
#PHPMYADMIN_REQUIRE='ip 203.0.113.10'   # or allow your IP (keep the quotes)
```

`lamp.sh` then applies `docker-compose.production.yml`:

| | development | production |
|---|---|---|
| PHP settings | `config/php/php.ini` | `config/php/php-production.ini` |
| PHP errors | displayed | logged in the Apache error log only |
| Xdebug | develop mode | off |
| `X-Powered-By` header | sent | not sent |
| phpMyAdmin | open (`all granted`) | denied (`all denied`) unless `PHPMYADMIN_REQUIRE` allows it |

In both modes phpMyAdmin refuses root logins and session upload progress is
disabled. Running `docker compose` directly instead of `lamp.sh`? Add the
override to `COMPOSE_FILE` in `.env` (see `sample.env`).

Also for production:
- Change all default passwords (quote values containing `$`: `'abc$xyz'`)
- Use proper SSL certificates (Let's Encrypt)
- Back up with `./lamp.sh dump`, never by copying `data/` while the database runs
- Apply PHP security releases with `./lamp.sh update`

Updating a project created with an older LampBox: see the
[Migration Guide](docs/MIGRATION.md).

## 🆚 What's New in v3.0.0

### Version 3.0.0 (2026-10-23)
- ✅ **Production mode** (`LAMPBOX_ENV=production`): PHP errors hidden, Xdebug off, no `X-Powered-By`, phpMyAdmin denied by default
- ✅ phpMyAdmin access configurable (`PHPMYADMIN_REQUIRE`), root login disabled, real client IP behind Traefik
- ✅ New `./lamp.sh update`: apply a PHP security release to the webserver only, with rollback image
- ✅ New `./lamp.sh dump`: consistent database dumps with rotation; passwords no longer on the command line
- ✅ `./lamp.sh rebuild` now pulls updated base images
- ✅ php82 follows `php:8.2-apache-bookworm`; PHP 8.0 and 8.1 removed (end of life)
- ✅ New [Migration Guide](docs/MIGRATION.md) for projects created with older versions
- ✅ Databases: only supported LTS versions (MySQL 8.4, 9.7; MariaDB 10.11, 11.4, 11.8, 12.3); default is now `mysql84`
- ✅ Fixed database data directory handling (`clean-db`, engine check) and engine switching (`start` builds the matching image)
- ✅ Shell scripts are executable
- ✅ `init.bat` removed: on Windows, use Git Bash or WSL2; supported platforms are now stated

### Version 2.2.0 (2026-07-15)
- ✅ Replaced the per-project Nginx reverse proxy with a single **shared Traefik** instance
- ✅ Run **multiple projects in parallel** behind one proxy — no more `port is already allocated`
- ✅ Label-based routing: each project is reached at `https://<PROJECT_DOMAIN>`
- ✅ Shared `*.local` TLS certificate and shared `lampbox_web` network
- ✅ New commands: `./lamp.sh proxy-up` / `proxy-down`

### Version 2.1.0 (2026-05-11)
- ✅ Fixed reverse proxy domain substitution and phpMyAdmin redirect handling
- ✅ Fixed SSL certificate generation under Git Bash/Windows (MSYS path conversion)
- ✅ Updated Nginx config to use modern HTTP/2 syntax
- ✅ Added compose overrides for proxy mode and optional MySQL port handling
- ✅ Added version-specific MySQL/MariaDB data directories and compatibility checks
- ✅ Updated documentation to reflect new reverse proxy startup flow

### Version 2.0.2 (2026-01-20)
- ✅ Added PHP 8.5 support
- ✅ Added MySQL 8.4 support
- ✅ Added MariaDB 10.11, 11.8, 12.1 support
- ✅ Added test scripts in `/test` directory with logging system
- ✅ Updated documentation with new versions

### Major Changes from v1.x

✅ Removed Traefik (simplified stack)  
✅ Removed Ansible (direct configuration)  
✅ Added Nginx reverse proxy (optional)  
✅ Added dual access modes (ports vs domains)  
✅ Full Windows support (Git Bash/WSL2/CMD)  
✅ Auto-generated phpMyAdmin secrets  
✅ Fixed permission handling cross-platform  
✅ Improved documentation and examples  

See [CHANGELOG.md](CHANGELOG.md) for full history.

## 📦 Docker Images Used

- **PHP**: Custom builds from `php:8.2-apache-bookworm` to `php:8.5-apache-bookworm`
- **MySQL**: `mysql:8.4`, `mysql:9.7`
- **MariaDB**: `mariadb:10.11`, `mariadb:11.4`, `mariadb:11.8`, `mariadb:12.3`
- **Traefik**: `traefik:v3.6` (shared reverse proxy)
- **phpMyAdmin**: Built into PHP images

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## 📄 License

This project is open source. Feel free to use, modify, and distribute.

## 🙏 Credits

Built with ❤️ for the PHP development community.

---

**Need help?** Check the [documentation](docs/) or open an issue!
