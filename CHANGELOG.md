# Changelog - Docker LAMP Stack

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