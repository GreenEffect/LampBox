# 🔧 Troubleshooting Guide

Common issues and solutions for Docker LAMP Stack v2.0.2.

## 📑 Table of Contents

- [MySQL Issues](#%EF%B8%8F-mysql-issues)
- [phpMyAdmin Issues](#-phpmyadmin-issues)
- [Permission Issues](#-permission-issues)
- [Port Issues](#-port-issues)
- [Script Issues](#-script-issues)
- [Network Issues](#-network-issues)
- [Performance Issues](#-performance-issues)

---

## 🗄️ MySQL Issues

### MySQL Container Won't Start: "Data Directory Has Files"

**Error:**
```
[ERROR] [MY-010457] --initialize specified but the data directory has files in it. Aborting.
[ERROR] [MY-013236] The designated data directory /var/lib/mysql/ is unusable.
```

**Cause:** The `data/mysql/` directory contains residual files preventing MySQL initialization.

**Solution 1: Quick Fix (Recommended)**
```bash
# Clean database and restart
./lamp.sh clean-db
docker compose up -d
```

**Solution 2: Manual Cleanup**
```bash
# Stop containers
docker compose down

# Clean MySQL data directory
rm -rf data/mysql/*

# Restart
docker compose up -d
```

**Solution 3: With Backup**
```bash
# Backup existing data first
docker compose exec database mysqldump -u root -p --all-databases > backup.sql

# Clean and restart
./lamp.sh clean-db
docker compose up -d

# Restore if needed
docker compose exec -T database mysql -u root -p < backup.sql
```

**Prevention:**
- Always use `./lamp.sh clean-db` when switching database versions
- Don't manually modify files in `data/mysql/`
- Use `docker compose down` (not `docker compose down -v`) to preserve data

### MySQL Container Exits Immediately

**Diagnosis:**
```bash
# Check logs
./lamp.sh logs database

# Or
docker compose logs database
```

**Common Causes:**

1. **Port already in use**
   ```bash
   # Change MySQL port in .env
   MYSQL_PORT=3307
   
   # Restart
   docker compose down
   docker compose up -d
   ```

2. **Corrupted data directory**
   ```bash
   # Clean and restart
   ./lamp.sh clean-db
   docker compose up -d
   ```

3. **Insufficient memory**
   ```bash
   # Increase Docker Desktop memory
   # Settings → Resources → Memory → 4GB+
   ```

### Can't Connect to MySQL

**From phpMyAdmin:**
```bash
# Check credentials in .env
cat .env | grep MYSQL

# Verify database is running
docker compose ps database

# Check logs
./lamp.sh logs database
```

**From External Client:**
```bash
# Ensure MYSQL_PORT is set in .env
MYSQL_PORT=3306

# Test connection
mysql -h 127.0.0.1 -P 3306 -u docker -p
```

**From PHP Application:**
```php
// Correct host (container name, not localhost!)
$host = 'lamp-database';
$user = 'docker';
$pass = 'docker';
$db   = 'docker';

$dsn = "mysql:host=$host;dbname=$db";

$pdo = new PDO($dsn, $user, $pass);
```

---

## 🔐 phpMyAdmin Issues

### "Permissions on Configuration File Incorrect"

**Error:**
```
phpMyAdmin - Erreur
Permissions sur le fichier de configuration incorrectes,
il ne doit pas être en écriture pour tout le monde !
```

**Solution:**
```bash
# Fix permissions (Linux/Mac)
chmod 644 config/phpmyadmin/config.inc.php

# Restart webserver
docker compose restart webserver
```

**Note:** On Windows, this issue is automatically handled. If it persists, the configuration file has a directive to disable this check.

### Can't Access phpMyAdmin

**Check URL format:**
```bash
# Correct format
http://localhost:8080/{PROJECT_NAME}-mysql

# Default
http://localhost:8080/lamp-mysql
```

**Verify project name:**
```bash
# Check your project name in .env
grep COMPOSE_PROJECT_NAME .env

# URL should be
http://localhost:{HTTP_PORT}/{COMPOSE_PROJECT_NAME}-mysql
```

**Check webserver is running:**
```bash
docker compose ps webserver
./lamp.sh logs webserver
```

### phpMyAdmin Login Fails

**Check credentials:**
```bash
# From .env file
cat .env | grep MYSQL_

# Try with these credentials
# User: docker
# Password: docker

# OR

# User: root
# Password: tiger (or MYSQL_ROOT_PASSWORD value)
```

**Reset MySQL password:**
```bash
# Access MySQL shell
./lamp.sh mysql

# Reset password
ALTER USER 'docker'@'%' IDENTIFIED BY 'newpassword';
FLUSH PRIVILEGES;

# Update .env with new password
```

---

## 🔒 Permission Issues

### "Permission Denied" on Linux/macOS

**Issue:** Can't create or edit files in `www/` directory.

**Solution:**
```bash
# Re-run initialization to fix permissions
./init.sh

# Or manually set your user
nano .env

# Set to your user ID
USER_ID=1000    # Get with: id -u
GROUP_ID=1000   # Get with: id -g

# Restart containers
docker compose down
docker compose up -d
```

**Find your UID/GID:**
```bash
id -u  # Shows your user ID
id -g  # Shows your group ID
```

### Files Created by Docker Have Wrong Owner

**This is normal!** Docker containers run as `www-data` (or the USER_ID you specify).

**Solution:**
```bash
# Option 1: Configure correct USER_ID in .env
USER_ID=$(id -u)
GROUP_ID=$(id -g)

# Option 2: Change ownership after container creates files
sudo chown -R $USER:$USER www/

# Option 3: Use the same UID as your host user (recommended)
# The init.sh script does this automatically
```

### Can't Execute Scripts on Windows

**Issue:** `./init.sh: Permission denied`

**Solutions:**

1. **Use Git Bash (recommended)**
   ```bash
   bash init.sh
   bash lamp.sh start
   ```

2. **Make scripts executable**
   ```bash
   chmod +x *.sh
   ./init.sh
   ```

3. **Use Windows CMD**
   ```cmd
   init.bat
   docker compose up -d
   ```

---

## 🔌 Port Issues

### "Port Already in Use"

**Error:**
```
Error response from daemon: Ports are not available: 
exposing port TCP 0.0.0.0:8080 -> 0.0.0.0:0: listen tcp 0.0.0.0:8080: bind: address already in use
```

**Find what's using the port:**

**Linux/Mac:**
```bash
# Check what's using port 8080
sudo lsof -i :8080

# Or
sudo netstat -tlnp | grep 8080
```

**Windows:**
```cmd
netstat -ano | findstr :8080
```

**Solution 1: Change ports in .env**
```bash
# Edit .env
HTTP_PORT=8081
HTTPS_PORT=8444
MYSQL_PORT=3307

# Restart
docker compose down
docker compose up -d
```

**Solution 2: Stop conflicting service**
```bash
# Example: Stop Apache if running on host
sudo systemctl stop apache2

# Or: Stop MySQL if running on host
sudo systemctl stop mysql
```

### Running Multiple Projects Simultaneously

Each project needs unique ports:

```bash
# Project 1 (.env)
COMPOSE_PROJECT_NAME=lamp-project1
HTTP_PORT=8080
HTTPS_PORT=8443
MYSQL_PORT=3306

# Project 2 (.env)
COMPOSE_PROJECT_NAME=lamp-project2
HTTP_PORT=8081
HTTPS_PORT=8444
MYSQL_PORT=3307
```

Or use reverse proxy mode with different domains.

---

## 📜 Script Issues

### "UID: readonly variable" Error

**Error:**
```bash
$ ./lamp.sh logs
.env: line 19: UID: readonly variable
```

**Cause:** Old `.env` files use `UID` and `GID` which are reserved in bash.

**Solution:**
```bash
# Quick fix - rename variables in .env
sed -i 's/^UID=/USER_ID=/' .env
sed -i 's/^GID=/GROUP_ID=/' .env

# Or regenerate .env
rm .env
./init.sh
```

**Prevention:** Always use `./init.sh` to create `.env` file.

### Scripts Don't Run on Windows

**Issue:** Double-clicking `.sh` files doesn't work.

**Solutions:**

1. **Use Git Bash (recommended)**
   - Right-click → "Git Bash Here"
   - Run: `./init.sh`

2. **Use WSL2**
   - Open Ubuntu terminal
   - Navigate to project: `cd /mnt/c/path/to/Docker-LAMP`
   - Run: `./init.sh`

3. **Use Windows CMD**
   - Use `init.bat` instead of `init.sh`
   - Use Docker commands directly: `docker compose up -d`

### lamp.sh Commands Don't Work

**Check script is executable:**
```bash
chmod +x lamp.sh
./lamp.sh start
```

**Use bash explicitly:**
```bash
bash lamp.sh start
```

**Alternative: Use Docker Compose directly:**
```bash
docker compose up -d        # Instead of: ./lamp.sh start
docker compose down         # Instead of: ./lamp.sh stop
docker compose logs -f      # Instead of: ./lamp.sh logs
```

---

## 🌐 Network Issues

### Can't Reach Containers from Host

**Check containers are running:**
```bash
docker compose ps

# Should show all containers as "Up"
```

**Check ports are exposed:**
```bash
docker compose ps

# Should show port mappings like:
# 0.0.0.0:8080->80/tcp
```

**Firewall blocking?**
```bash
# Linux: Check firewall
sudo ufw status

# Windows: Check Windows Defender Firewall
# Allow Docker Desktop through firewall
```

### Containers Can't Reach Internet

**Check Docker DNS:**
```bash
# Test from inside container
docker compose exec webserver ping google.com

# If fails, check Docker DNS settings
# Docker Desktop → Settings → Docker Engine
```

**Add DNS servers to docker-compose.yml:**
```yaml
services:
  webserver:
    dns:
      - 8.8.8.8
      - 8.8.4.4
```

### Domain Not Resolving (Reverse Proxy Mode)

**Check hosts file:**

**Linux/Mac:**
```bash
cat /etc/hosts

# Should contain:
127.0.0.1    myproject.local
```

**Windows:**
```cmd
notepad C:\Windows\System32\drivers\etc\hosts

# Should contain:
127.0.0.1    myproject.local
```

**Flush DNS cache:**

**Linux:**
```bash
sudo systemd-resolve --flush-caches
```

**Mac:**
```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

**Windows:**
```cmd
ipconfig /flushdns
```

---

## ⚡ Performance Issues

### Containers Are Slow

**Increase Docker resources:**
- Docker Desktop → Settings → Resources
- Memory: 4GB minimum, 8GB recommended
- CPU: 2 cores minimum, 4+ recommended
- Swap: 1GB minimum

**Check Docker logs:**
```bash
# Look for memory or CPU warnings
docker compose logs
```

### MySQL Queries Are Slow

**Check MySQL configuration:**
```bash
# Edit config/php/php.ini or add my.cnf
# Increase buffer sizes for development
```

**Optimize for development:**
```sql
-- Disable slow query log in development
SET GLOBAL slow_query_log = 'OFF';

-- Increase buffer pool size (if you have RAM)
-- Add to MySQL config file
innodb_buffer_pool_size = 256M
```

### File Changes Not Reflecting (Volume Mount Issues)

**Force rebuild:**
```bash
docker compose down
docker compose up -d --build
```

**Check volume mounts:**
```bash
docker compose config

# Verify volumes are correctly mapped
```

**Windows specific: Enable file sharing**
- Docker Desktop → Settings → Resources → File Sharing
- Add your project directory

---

## 🔍 Diagnostic Commands

### Check Everything

```bash
# System check
./check-system.sh

# Container status
docker compose ps

# View all logs
docker compose logs

# View specific service logs
./lamp.sh logs webserver
./lamp.sh logs database

# Resource usage
docker stats

# Inspect network
docker network inspect lamp-network
```

### Get Container Details

```bash
# Webserver info
docker compose exec webserver php -v
docker compose exec webserver apache2 -v

# Database info
docker compose exec database mysql --version

# Environment variables
docker compose exec webserver env
```

### Test Connectivity

```bash
# Test webserver from host
curl http://localhost:8080

# Test database connection
docker compose exec webserver mysql -h lamp-database -u docker -p

# Test from PHP
docker compose exec webserver php -r "echo mysqli_connect('lamp-database', 'docker', 'docker', 'docker') ? 'OK' : 'FAIL';"
```

---

## 🆘 Getting Help

If you can't find a solution here:

1. **Check logs:**
   ```bash
   ./lamp.sh logs
   ```

2. **Verify configuration:**
   ```bash
   cat .env
   docker compose config
   ```

3. **Search existing issues** on GitHub

4. **Create a new issue** with:
   - Your OS and version
   - Docker version: `docker --version`
   - Docker Compose version: `docker compose version`
   - Error messages and logs
   - Steps to reproduce

---

## 📚 Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [PHP Documentation](https://www.php.net/docs.php)
- [MySQL Documentation](https://dev.mysql.com/doc/)
- [Apache Documentation](https://httpd.apache.org/docs/)

---

**Still stuck?** Open an issue on GitHub with full details!
