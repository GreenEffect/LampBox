# Scripts de Test - LampBox

Ce répertoire contient des scripts pour tester différentes configurations PHP et base de données de LampBox.

## 📋 Prérequis

### Environnement requis

Les scripts sont écrits en **bash** (`.sh`) et nécessitent un environnement compatible :

#### ✅ Linux / macOS
- Terminal natif (bash inclus par défaut)
- Aucune installation supplémentaire requise

#### ✅ Windows
Vous devez utiliser l'un des outils suivants :

1. **Git Bash** (Recommandé)
   - Télécharger : https://git-scm.com/downloads
   - Installation : Suivre l'assistant d'installation
   - Utilisation : Clic droit dans le dossier → "Git Bash Here"
   - Avantages : Facile à installer, support complet des scripts bash

2. **WSL2** (Windows Subsystem for Linux)
   - Installation : `wsl --install` (PowerShell en administrateur)
   - Distribution : Ubuntu recommandé
   - Avantages : Environnement Linux complet

3. **Autres outils compatibles**
   - Cygwin
   - MSYS2
   - Tout autre environnement bash compatible

#### ❌ Non compatible
- Windows CMD (Command Prompt)
- Windows PowerShell (sans WSL)
- Double-clic direct sur les fichiers `.sh`

## 🚀 Utilisation

### Test d'une combinaison spécifique

#### Mode 1 : Arguments séparés (Recommandé)

```bash
cd test/
./test-config.sh php85 mariadb121 9000 9300
```

**Arguments :**
1. **Version PHP** : `php8`, `php81`, `php82`, `php83`, `php84`, `php85`
2. **Version DB** : `mysql8`, `mysql84`, `mariadb103`, `mariadb104`, `mariadb105`, `mariadb106`, `mariadb1011`, `mariadb118`, `mariadb121`
3. **Port HTTP** : Port pour accéder au site web (ex: `9000`)
4. **Port MySQL** : Port pour la connexion MySQL externe (ex: `9300`)

**Exemples :**
```bash
# PHP 8.5 + MariaDB 12.1
./test-config.sh php85 mariadb121 9000 9300

# PHP 8.4 + MySQL 8.4
./test-config.sh php84 mysql84 9001 9301

# PHP 8.3 + MariaDB 11.8
./test-config.sh php83 mariadb118 9002 9302
```

#### Mode 2 : Fichier .env personnalisé

Si vous avez déjà un fichier `.env` de test :

```bash
./test-config.sh .env.test.test-php85-mariadb121
```

Le script va :
- Lire la configuration depuis le fichier `.env` spécifié
- Créer les répertoires nécessaires si absents
- Construire les images Docker si elles n'existent pas
- Lancer les conteneurs
- Vérifier que tout fonctionne
- Afficher les URLs de test

### Ce que fait le script

1. **Vérification** : Vérifie que tous les arguments sont fournis
2. **Création du .env** : Crée un fichier `.env.test.{project-name}` avec la configuration
3. **Préparation** : Crée les répertoires nécessaires (`www/`, `config/`, `logs/`, etc.)
4. **Construction** : Construit les images Docker si elles n'existent pas
5. **Démarrage** : Lance les conteneurs Docker
6. **Vérification** : Attend que les services soient prêts
7. **Tests** : Vérifie les versions PHP et DB, teste la connexion MySQL
8. **Rapport** : Affiche les URLs et informations de connexion

### Logs

Chaque test génère un fichier de log dans `test/logs/` :

```
test/logs/
├── test-php85-mariadb121.log
├── test-php84-mysql84.log
└── ...
```

**Format des logs :**
- Timestamp de chaque action
- Configuration testée (PHP version, DB version, ports)
- Statut de démarrage des conteneurs
- URL de test
- Erreurs éventuelles
- Statut final (SUCCESS/FAILED)

## 🧹 Nettoyage

### Script de nettoyage

```bash
cd test/
./cleanup.sh
```

Le script `cleanup.sh` permet de :

1. **Supprimer les conteneurs de test**
   - Trouve tous les conteneurs avec le préfixe `test-`
   - Propose de les arrêter et supprimer

2. **Supprimer les images Docker de test**
   - Trouve toutes les images avec le préfixe `test-`
   - Propose de les supprimer

3. **Supprimer les fichiers .env de test**
   - Trouve tous les fichiers `.env.test.*` dans le répertoire parent
   - Propose de les supprimer

4. **Supprimer les logs**
   - Propose de supprimer les fichiers de log dans `test/logs/`

**Note :** Le script demande confirmation avant chaque action pour éviter les suppressions accidentelles.

### Nettoyage manuel

Si vous préférez nettoyer manuellement :

```bash
# Arrêter et supprimer tous les conteneurs de test
docker ps -a --filter "name=test-" --format "{{.Names}}" | xargs docker rm -f

# Supprimer les images de test
docker images --format "{{.Repository}}:{{.Tag}}" | grep "^test-" | xargs docker rmi -f

# Supprimer les fichiers .env de test
rm -f ../.env.test.*

# Supprimer les logs
rm -f logs/*.log
```

## 📁 Structure

```
test/
├── README.md           # Ce fichier
├── test-config.sh      # Script principal de test
├── cleanup.sh          # Script de nettoyage
└── logs/               # Répertoire des logs (créé automatiquement)
    ├── test-php85-mariadb121.log
    ├── test-php84-mysql84.log
    └── ...
```

## 🔍 Vérification après test

Après l'exécution d'un test, vous pouvez :

1. **Consulter les logs**
   ```bash
   cat logs/test-php85-mariadb121.log
   ```

2. **Accéder aux URLs affichées**
   - Site web : `http://localhost:9000`
   - phpMyAdmin : `http://localhost:9000/test-php85-mariadb121-mysql`

3. **Vérifier les conteneurs**
   ```bash
   docker ps | grep test-
   ```

4. **Tester la connexion MySQL**
   ```bash
   docker exec -it test-php85-mariadb121-database mysql -u testuser -ptestpass testdb
   ```

## 💡 Conseils d'utilisation

### Tester plusieurs configurations

Pour tester plusieurs configurations rapidement :

```bash
# Terminal 1
./test-config.sh php85 mariadb121 9000 9300

# Terminal 2 (après le premier test)
./test-config.sh php84 mysql84 9001 9301

# Terminal 3
./test-config.sh php83 mariadb118 9002 9302
```

**Important :** Utilisez des ports différents pour chaque test !

### Ports recommandés

Pour éviter les conflits, utilisez des plages de ports différentes :

- **Tests PHP 8.5** : Ports 9000-9099
- **Tests PHP 8.4** : Ports 9100-9199
- **Tests PHP 8.3** : Ports 9200-9299
- etc.

### Conserver les images

Les images Docker sont réutilisées si elles existent déjà. Pour forcer une reconstruction :

```bash
# Supprimer l'image avant le test
docker rmi test-php85-mariadb121-webserver
docker rmi test-php85-mariadb121-database

# Relancer le test (reconstruira les images)
./test-config.sh php85 mariadb121 9000 9300
```

### Debugging

Si un test échoue :

1. **Vérifier les logs**
   ```bash
   tail -n 50 logs/test-php85-mariadb121.log
   ```

2. **Vérifier les conteneurs**
   ```bash
   docker ps -a | grep test-php85-mariadb121
   ```

3. **Vérifier les logs Docker**
   ```bash
   docker logs test-php85-mariadb121-webserver
   docker logs test-php85-mariadb121-database
   ```

4. **Vérifier le fichier .env**
   ```bash
   cat ../.env.test.test-php85-mariadb121
   ```

## 🪟 Utilisation sous Windows

### Avec Git Bash (Recommandé)

1. **Installer Git Bash** : https://git-scm.com/downloads
2. **Ouvrir Git Bash** : Clic droit dans le dossier `test/` → "Git Bash Here"
3. **Exécuter les scripts** :
   ```bash
   ./test-config.sh php85 mariadb121 9000 9300
   ./cleanup.sh
   ```

### Avec WSL2

1. **Installer WSL2** :
   ```powershell
   wsl --install
   ```

2. **Ouvrir Ubuntu** et naviguer vers le projet :
   ```bash
   cd /mnt/c/Users/VotreNom/Projets/LampBox/test
   ./test-config.sh php85 mariadb121 9000 9300
   ```

### Problèmes courants Windows

**Erreur : "Permission denied"**
```bash
# Solution : Utiliser bash explicitement
bash test-config.sh php85 mariadb121 9000 9300
```

**Erreur : "No such file or directory"**
- Vérifier que vous êtes dans le bon répertoire
- Utiliser des chemins relatifs, pas absolus

**Les scripts ne s'exécutent pas**
- Vérifier que Git Bash ou WSL2 est installé
- Ne pas utiliser CMD ou PowerShell directement

## 📊 Exemples de sortie

### Sortie réussie

```
==========================================
Test de configuration: PHP php85 + mariadb121
Ports: HTTP=9000, MySQL=9300
==========================================
[INFO] Création du fichier .env de test...
[SUCCESS] Fichier .env créé: /path/to/.env.test.test-php85-mariadb121
[INFO] Vérification des images Docker...
[INFO] Construction des images Docker...
[SUCCESS] Images construites avec succès
[INFO] Démarrage des conteneurs...
[SUCCESS] Conteneurs démarrés
[INFO] Attente du démarrage des services...
[SUCCESS] Conteneurs démarrés et prêts
[INFO] Version PHP détectée: PHP 8.5.0 (cli)
[INFO] Version DB détectée: mariadb Ver 12.1.0
[SUCCESS] Connexion à la base de données réussie
==========================================
✅ Configuration testée avec succès!
==========================================
URLs de test:
  Site web:     http://localhost:9000
  phpMyAdmin:   http://localhost:9000/test-php85-mariadb121-mysql

Informations de connexion DB:
  Host:     localhost
  Port:     9300
  User:     testuser
  Password: testpass
  Database: testdb
```

## 🆘 Support

Si vous rencontrez des problèmes :

1. **Vérifier les logs** dans `test/logs/`
2. **Vérifier la documentation principale** : [README.md](../README.md)
3. **Vérifier le guide de dépannage** : [docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md)
4. **Ouvrir une issue** sur GitHub avec :
   - Votre OS et version
   - Le script utilisé et les arguments
   - Les logs d'erreur
   - Les étapes pour reproduire

---

**Version :** 2.1.0 (2026-05-11)
