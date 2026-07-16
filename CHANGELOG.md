# Changelog - LampBox

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