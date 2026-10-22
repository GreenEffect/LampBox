# Quick Start Guide - LampBox

## 🚀 Get Started in 3 Steps

### Linux / macOS / Windows (Git Bash)

### 1️⃣ Initialize
```bash
./init.sh
```

### 2️⃣ Configure (Optional)
Edit `.env` if you need custom settings:
```bash
nano .env
```

### 3️⃣ Start
```bash
docker compose up -d
```

🎉 **Done!** Access your site at http://localhost:8080

---

### Windows (Command Prompt) - Alternative

### 1️⃣ Initialize
```batch
init.bat
```

### 2️⃣ Configure (Optional)
```batch
notepad .env
```

### 3️⃣ Start
```batch
docker compose up -d
```

**Note for Windows users:** See [WINDOWS.md](WINDOWS.md) for detailed Windows guide.

---

## 📖 Common Commands

```bash
# Start the stack
./lamp.sh start

# Start the shared Traefik proxy (once, for domain access)
./lamp.sh proxy-up

# Start with reverse proxy (domain access)
./lamp.sh start --proxy

# Stop the stack
./lamp.sh stop

# View logs
./lamp.sh logs

# Open shell in container
./lamp.sh shell

# Open MySQL shell
./lamp.sh mysql

# Dump all databases to data/db-dumps/
./lamp.sh dump

# Apply a PHP security release (webserver only, database untouched)
./lamp.sh update

# Show connection info
./lamp.sh info

# Get help
./lamp.sh
```

---

## 🌐 Access Methods

### Method 1: Direct Port Access (Default)
- Website: http://localhost:8080
- phpMyAdmin: http://localhost:8080/lamp-mysql

### Method 2: Domain Access (Traefik reverse proxy)

A single shared Traefik instance owns ports 80/443 and routes every project by
its domain, so multiple projects run in parallel without port conflicts.

1. Edit `.env`:
   ```bash
   USE_REVERSE_PROXY=true
   PROJECT_DOMAIN=myproject.local   # unique per project
   ```

2. Add to `/etc/hosts`:
   ```bash
   echo "127.0.0.1 myproject.local" | sudo tee -a /etc/hosts
   ```

3. Start the shared Traefik proxy (once — creates the network + TLS cert):
   ```bash
   ./lamp.sh proxy-up
   ```

4. Start your project behind Traefik:
   ```bash
   ./lamp.sh start        # (start also runs proxy-up automatically if needed)
   ```

5. Access: https://myproject.local

---

## 🔧 Multiple Projects

### Option A — Direct ports (unique port per project)

**Setup Project 1**
```bash
cd ~/projects/project1
git clone https://github.com/GreenEffect/LampBox.git .
./init.sh
# Edit .env: HTTP_PORT=8080, COMPOSE_PROJECT_NAME=project1
./lamp.sh start
```

**Setup Project 2**
```bash
cd ~/projects/project2
git clone https://github.com/GreenEffect/LampBox.git .
./init.sh
# Edit .env: HTTP_PORT=8081, COMPOSE_PROJECT_NAME=project2
./lamp.sh start
```

### Option B — Domains via shared Traefik (recommended)

No port juggling: give each project a unique domain and let Traefik route them.

```bash
# One-time: start the shared proxy
./lamp.sh proxy-up

# Project 1 — .env: USE_REVERSE_PROXY=true, PROJECT_DOMAIN=project1.local, COMPOSE_PROJECT_NAME=project1
cd ~/projects/project1 && ./lamp.sh start     # → https://project1.local

# Project 2 — .env: USE_REVERSE_PROXY=true, PROJECT_DOMAIN=project2.local, COMPOSE_PROJECT_NAME=project2
cd ~/projects/project2 && ./lamp.sh start     # → https://project2.local
```

Both projects now run simultaneously! 🎊

---

## 📝 Configuration Cheat Sheet

### Change PHP Version
```bash
# In .env
PHPVERSION=php83  # Options: php82, php83, php84, php85
```

### Change Database
```bash
# In .env
DATABASE=mysql84  # Options: mysql84, mysql97, mariadb1011, mariadb114, mariadb118, mariadb123
```

### Change Ports
```bash
# In .env (HTTP/HTTPS ports only apply in direct port mode)
HTTP_PORT=8080
HTTPS_PORT=8443

# Database port on the host: empty by default (nothing published), which lets
# several projects coexist. Set a UNIQUE value per project only if you need a
# GUI client such as TablePlus or DBeaver.
MYSQL_PORT=3306
```

### Change Credentials
```bash
# In .env
MYSQL_ROOT_PASSWORD=mypassword
MYSQL_DATABASE=mydatabase
MYSQL_USER=myuser
MYSQL_PASSWORD=mypassword
# Values containing '$' must be single-quoted: MYSQL_PASSWORD='abc$xyz'
```

### Production Settings
```bash
# In .env: hide PHP errors, turn Xdebug off, deny phpMyAdmin
LAMPBOX_ENV=production
PHPMYADMIN_REQUIRE=        # empty = "all denied"; or e.g. "ip 203.0.113.10"
```

---

## 🐛 Troubleshooting

### Port Already in Use
```bash
# Change port in .env
HTTP_PORT=8081
```

### Permission Denied
```bash
# Run init.sh again to fix USER_ID/GROUP_ID
./init.sh
./lamp.sh rebuild
```

### Database Won't Start
```bash
# Check logs
./lamp.sh logs database

# Clean the database data (removes it!) and restart
./lamp.sh clean-db
./lamp.sh start
```

### Can't Access Site
```bash
# Check if running
./lamp.sh status

# Check which port
./lamp.sh info
```

---

## 📚 Need More Help?

Read the full README.md for detailed documentation:
```bash
cat README.md
```

Or open an issue on GitHub! 🙋‍♂️
