# Windows Setup Guide - Docker LAMP Stack v2.0.2

## 🪟 Guide Spécifique Windows

Ce guide vous aide à configurer et utiliser Docker LAMP Stack v2.0.2 sur Windows.

---

## 📋 Prérequis Windows

### 1. Docker Desktop pour Windows

**Installation:**
1. Télécharger depuis: https://www.docker.com/products/docker-desktop
2. Installer Docker Desktop
3. Redémarrer Windows si demandé
4. Lancer Docker Desktop (vérifier qu'il tourne dans la barre des tâches)

**Configuration Docker Desktop:**
- Ouvrir Docker Desktop → Settings
- General → **Cocher** "Use the WSL 2 based engine" (recommandé)
- Resources → File Sharing → S'assurer que votre lecteur est partagé

### 2. Options pour Exécuter les Scripts

Vous avez **3 options** pour exécuter les scripts bash :

#### Option A: Git Bash (Recommandé)
- **Installation:** https://git-scm.com/download/win
- **Usage:** Clic droit dans le dossier → "Git Bash Here"
- **Avantages:** Supporte tous les scripts bash, facile

#### Option B: WSL2 (Pour Utilisateurs Avancés)
- **Installation:** `wsl --install` (PowerShell en admin)
- **Distribution:** Ubuntu recommandé
- **Avantages:** Environnement Linux complet

#### Option C: Scripts Natifs Windows (.bat)
- **Pas d'installation** requise
- **Limitation:** Seulement pour init.bat
- **Usage:** Double-clic sur `init.bat`

---

## 🚀 Installation Rapide (Windows)

### Méthode 1: Avec Git Bash (Recommandé)

```bash
# 1. Extraire l'archive (clic droit → Extraire)
# 2. Ouvrir Git Bash dans le dossier (clic droit → Git Bash Here)

# 3. Initialiser
bash init.sh

# 4. Démarrer
docker compose up -d

# 5. Accès
# http://localhost:8080
```

### Méthode 2: Sans Git Bash (Scripts Natifs)

```batch
REM 1. Extraire l'archive
REM 2. Double-clic sur init.bat

REM 3. Ouvrir Command Prompt dans le dossier
REM (Shift + Clic droit → "Ouvrir dans le terminal")

REM 4. Démarrer
docker compose up -d

REM 5. Accès
REM http://localhost:8080
```

---

## 🔧 Gestion du Stack (Windows)

### Avec Git Bash

```bash
# Démarrer
docker compose up -d

# Arrêter
docker compose down

# Voir les logs
docker compose logs -f

# Shell dans le conteneur
docker compose exec webserver bash

# MySQL shell
docker compose exec database mysql -u root -p
```

### Avec Command Prompt / PowerShell

```batch
REM Démarrer
docker compose up -d

REM Arrêter
docker compose down

REM Voir les logs
docker compose logs -f

REM Shell dans le conteneur
docker exec -it lamp-webserver bash

REM MySQL shell
docker exec -it lamp-database mysql -u root -p
```

---

## 📁 Accès aux Fichiers (Windows)

### Éditeurs Recommandés

1. **VS Code** (Recommandé)
   - Télécharger: https://code.visualstudio.com/
   - Ouvrir le dossier du projet dans VS Code
   - Éditer directement les fichiers dans `www/`

2. **Notepad++**
   - Télécharger: https://notepad-plus-plus.org/
   - Bon pour éditer rapidement `.env`, configs

3. **Notepad** (intégré Windows)
   - Pour modifications simples

### Emplacement des Fichiers

```
C:\Users\VotreNom\docker-lamp\
├── www\              ← Votre code PHP ici
├── config\           ← Configurations
├── data\mysql\       ← Base de données (ne pas modifier)
└── logs\             ← Logs Apache/MySQL
```

**Important:** Docker Desktop gère automatiquement les permissions. Vous pouvez éditer directement tous les fichiers sans problèmes de permissions !

---

## 🌐 Configuration Hosts File (Windows)

Pour utiliser des domaines locaux (ex: `monprojet.local`):

### 1. Ouvrir le Fichier Hosts

**Méthode A: Via Notepad (Admin)**
```batch
REM 1. Clic droit sur "Notepad" → "Exécuter en tant qu'administrateur"
REM 2. Fichier → Ouvrir
REM 3. Naviguer vers: C:\Windows\System32\drivers\etc\
REM 4. Afficher "Tous les fichiers" (pas seulement .txt)
REM 5. Ouvrir "hosts"
```

**Méthode B: Via PowerShell (Admin)**
```powershell
# Ouvrir PowerShell en tant qu'administrateur
notepad C:\Windows\System32\drivers\etc\hosts
```

### 2. Ajouter Vos Domaines

À la fin du fichier, ajouter:
```
127.0.0.1    monprojet.local
127.0.0.1    autreprojet.local
```

### 3. Sauvegarder et Fermer

### 4. Flush DNS (Optionnel)

```batch
ipconfig /flushdns
```

---

## 🔒 SSL/HTTPS (Windows)

### Avec Git Bash

```bash
# Générer certificats SSL
bash generate-ssl-certs.sh

# Ou avec OpenSSL directement
cd config/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout cert-key.pem -out cert.pem \
  -subj "/C=FR/ST=State/L=City/O=Organization/CN=monprojet.local"
```

### Certificats de Confiance (mkcert)

**Installation mkcert sur Windows:**
```batch
REM Avec Chocolatey
choco install mkcert

REM Ou télécharger depuis:
REM https://github.com/FiloSottile/mkcert/releases
```

**Utilisation:**
```batch
REM Installer le CA local
mkcert -install

REM Générer certificats
cd config\nginx\ssl
mkcert monprojet.local localhost 127.0.0.1

REM Renommer les fichiers
ren monprojet.local+2.pem cert.pem
ren monprojet.local+2-key.pem cert-key.pem
```

---

## 🐛 Troubleshooting Windows

### Docker Desktop ne démarre pas

**Solutions:**
1. Vérifier que la virtualisation est activée dans le BIOS
2. Activer Hyper-V:
   ```batch
   dism.exe /online /enable-feature /featurename:Microsoft-Hyper-V-All /all /norestart
   dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
   ```
3. Installer WSL2:
   ```batch
   wsl --install
   ```
4. Redémarrer Windows

### Port déjà utilisé

**Vérifier quel process utilise le port:**
```batch
netstat -ano | findstr :8080
```

**Tuer le process:**
```batch
taskkill /PID [numéro_pid] /F
```

**Ou changer le port dans .env:**
```
HTTP_PORT=8081
```

### "Docker daemon is not running"

**Solutions:**
1. Lancer Docker Desktop depuis le menu Démarrer
2. Attendre que Docker soit complètement démarré (icône dans barre des tâches)
3. Vérifier dans Docker Desktop → Settings que tout est OK

### Fichiers non modifiables

**Sur Windows, pas de problème de permissions !**
- Docker Desktop gère automatiquement
- Vous pouvez éditer directement avec n'importe quel éditeur

Si problème:
1. S'assurer que Docker Desktop est en mode "WSL 2"
2. Redémarrer Docker Desktop

### Scripts bash ne fonctionnent pas

**Solutions:**
1. Installer Git Bash (voir Prérequis)
2. Utiliser `bash script.sh` au lieu de `./script.sh`
3. Ou utiliser WSL2

### Performances lentes

**Optimisations:**
1. Docker Desktop → Settings → Resources
   - Augmenter CPU (4 cores recommandé)
   - Augmenter Memory (4GB minimum, 8GB recommandé)
2. Utiliser WSL2 au lieu de Hyper-V
3. Placer le projet sur le même lecteur que Docker
4. Exclure le dossier du projet de l'antivirus

---

## 💡 Conseils Windows

### 1. Utiliser WSL2

WSL2 offre de **meilleures performances** que Hyper-V:
```batch
# Installer WSL2
wsl --install

# Définir WSL2 par défaut
wsl --set-default-version 2

# Dans Docker Desktop
Settings → General → Use WSL 2 based engine
```

### 2. Terminal Windows moderne

Installer **Windows Terminal** depuis le Microsoft Store:
- Supporte Git Bash, PowerShell, WSL
- Onglets multiples
- Interface moderne

### 3. VS Code avec Docker

Installer les extensions VS Code:
- **Docker** (Microsoft)
- **Remote - Containers** (Microsoft)
- **PHP Intelephense** (pour PHP)

### 4. Chemins de fichiers

Sur Windows, utilisez:
- `\` pour les chemins Windows natifs
- `/` dans les chemins Docker (containers)

Exemple dans .env:
```bash
# Windows natif (rarement nécessaire)
DOCUMENT_ROOT=.\www

# Docker (déjà correct)
APACHE_DOCUMENT_ROOT=/var/www/html
```

---

## 🎓 Commandes Utiles Windows

### Docker Desktop

```batch
REM Redémarrer Docker
REM Clic droit sur l'icône Docker → Restart

REM Nettoyer Docker
docker system prune -a

REM Voir les conteneurs
docker ps -a

REM Voir les images
docker images

REM Voir l'utilisation disque
docker system df
```

### Système

```batch
REM Trouver votre IP locale
ipconfig | findstr IPv4

REM Tester la connexion
ping localhost

REM Flush DNS
ipconfig /flushdns

REM Voir les ports ouverts
netstat -an | findstr LISTENING
```

---

## 📞 Support Windows

### Ressources

- Docker Desktop pour Windows: https://docs.docker.com/desktop/windows/
- WSL2: https://docs.microsoft.com/en-us/windows/wsl/
- Git Bash: https://git-scm.com/download/win

### Communauté

- Forum Docker: https://forums.docker.com/
- Stack Overflow: https://stackoverflow.com/questions/tagged/docker
- GitHub Issues du projet

---

## ✅ Checklist Démarrage Windows

- [ ] Docker Desktop installé et en cours d'exécution
- [ ] Git Bash installé (ou WSL2)
- [ ] Archive extraite dans un dossier accessible
- [ ] `.env` configuré (via init.bat ou init.sh)
- [ ] Docker compose lancé (`docker compose up -d`)
- [ ] Site accessible (`http://localhost:8080`)
- [ ] phpMyAdmin accessible (`http://localhost:8080/lamp-mysql`)

---

**Vous êtes prêt ! Bon développement sur Windows ! 🪟🚀**
