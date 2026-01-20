# Configuration Examples

This file contains example configurations for common use cases.

## 📋 Table of Contents

- [Single Project - Direct Access](#single-project---direct-access)
- [Single Project - Domain Access](#single-project---domain-access)
- [Multiple Projects - Different Ports](#multiple-projects---different-ports)
- [Multiple Projects - Different Domains](#multiple-projects---different-domains)
- [WordPress Development](#wordpress-development)
- [Laravel Development](#laravel-development)
- [Symfony Development](#symfony-development)
- [E-commerce Platform](#e-commerce-platform)
- [API Development](#api-development)
- [Microservices Setup](#microservices-setup)

---

## Single Project - Direct Access

**Use case:** Simple local development with port access

**.env:**
```bash
COMPOSE_PROJECT_NAME=myproject
USER_ID=1000
GROUP_ID=1000

USE_REVERSE_PROXY=false
HTTP_PORT=8080
HTTPS_PORT=8443
MYSQL_PORT=3306

PHPVERSION=php83
DATABASE=mysql8

DOCUMENT_ROOT=./www
APACHE_DOCUMENT_ROOT=/var/www/html

MYSQL_ROOT_PASSWORD=root
MYSQL_DATABASE=myproject
MYSQL_USER=myproject
MYSQL_PASSWORD=secret
```

**Access:**
- http://localhost:8080
- http://localhost:8080/myproject-mysql (phpMyAdmin)

---

## Single Project - Domain Access

**Use case:** Production-like local environment with SSL

**.env:**
```bash
COMPOSE_PROJECT_NAME=myproject
USER_ID=1000
GROUP_ID=1000

USE_REVERSE_PROXY=true
PROJECT_DOMAIN=myproject.local

PHPVERSION=php83
DATABASE=mysql8

DOCUMENT_ROOT=./www
APACHE_DOCUMENT_ROOT=/var/www/html

MYSQL_ROOT_PASSWORD=root
MYSQL_DATABASE=myproject
MYSQL_USER=myproject
MYSQL_PASSWORD=secret
```

**/etc/hosts:**
```
127.0.0.1    myproject.local
```

**Access:**
- https://myproject.local
- https://myproject.local/myproject-mysql (phpMyAdmin)

**Start:**
```bash
./generate-ssl-certs.sh
./lamp.sh start --proxy
```

---

## Multiple Projects - Different Ports

**Use case:** Running several projects simultaneously

### Project 1 (.env):
```bash
COMPOSE_PROJECT_NAME=project1
HTTP_PORT=8080
HTTPS_PORT=8443
MYSQL_PORT=3306

PHPVERSION=php82
DATABASE=mysql8

MYSQL_ROOT_PASSWORD=root
MYSQL_DATABASE=project1
MYSQL_USER=project1
MYSQL_PASSWORD=secret1
```

### Project 2 (.env):
```bash
COMPOSE_PROJECT_NAME=project2
HTTP_PORT=8081
HTTPS_PORT=8444
MYSQL_PORT=3307

PHPVERSION=php83
DATABASE=mariadb106

MYSQL_ROOT_PASSWORD=root
MYSQL_DATABASE=project2
MYSQL_USER=project2
MYSQL_PASSWORD=secret2
```

### Project 3 (.env):
```bash
COMPOSE_PROJECT_NAME=project3
HTTP_PORT=8082
HTTPS_PORT=8445
MYSQL_PORT=3308

PHPVERSION=php81
DATABASE=mysql8

MYSQL_ROOT_PASSWORD=root
MYSQL_DATABASE=project3
MYSQL_USER=project3
MYSQL_PASSWORD=secret3
```

**Access:**
- Project 1: http://localhost:8080
- Project 2: http://localhost:8081
- Project 3: http://localhost:8082

---

## Multiple Projects - Different Domains

**Use case:** Multiple projects with realistic domain names

### Project 1 (.env):
```bash
COMPOSE_PROJECT_NAME=blog
USE_REVERSE_PROXY=true
PROJECT_DOMAIN=myblog.local

PHPVERSION=php83
DATABASE=mysql8
MYSQL_DATABASE=blog
```

### Project 2 (.env):
```bash
COMPOSE_PROJECT_NAME=shop
USE_REVERSE_PROXY=true
PROJECT_DOMAIN=myshop.local

PHPVERSION=php83
DATABASE=mysql8
MYSQL_DATABASE=shop
```

### Project 3 (.env):
```bash
COMPOSE_PROJECT_NAME=api
USE_REVERSE_PROXY=true
PROJECT_DOMAIN=api.local

PHPVERSION=php83
DATABASE=mysql8
MYSQL_DATABASE=api
```

**/etc/hosts:**
```
127.0.0.1    myblog.local
127.0.0.1    myshop.local
127.0.0.1    api.local
```

**Access:**
- https://myblog.local
- https://myshop.local
- https://api.local

---

## WordPress Development

**Use case:** WordPress site development

**.env:**
```bash
COMPOSE_PROJECT_NAME=wordpress
USER_ID=1000
GROUP_ID=1000

USE_REVERSE_PROXY=true
PROJECT_DOMAIN=wordpress.local

HTTP_PORT=8080
HTTPS_PORT=8443
MYSQL_PORT=3306

PHPVERSION=php82
DATABASE=mysql8

DOCUMENT_ROOT=./www
APACHE_DOCUMENT_ROOT=/var/www/html

MYSQL_ROOT_PASSWORD=root
MYSQL_DATABASE=wordpress
MYSQL_USER=wordpress
MYSQL_PASSWORD=wordpress
```

**wp-config.php:**
```php
define('DB_NAME', 'wordpress');
define('DB_USER', 'wordpress');
define('DB_PASSWORD', 'wordpress');
define('DB_HOST', 'wordpress-database');

// Development mode
define('WP_DEBUG', true);
define('WP_DEBUG_LOG', true);
define('WP_DEBUG_DISPLAY', false);

// Force SSL (if using reverse proxy)
if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    $_SERVER['HTTPS'] = 'on';
}
```

**/etc/hosts:**
```
127.0.0.1    wordpress.local
```

---

## Laravel Development

**Use case:** Laravel application

**.env (Docker LAMP):**
```bash
COMPOSE_PROJECT_NAME=laravel
USER_ID=1000
GROUP_ID=1000

USE_REVERSE_PROXY=false
HTTP_PORT=8080

PHPVERSION=php83
DATABASE=mysql8

DOCUMENT_ROOT=./www/public
APACHE_DOCUMENT_ROOT=/var/www/html

MYSQL_ROOT_PASSWORD=root
MYSQL_DATABASE=laravel
MYSQL_USER=laravel
MYSQL_PASSWORD=secret
```

**.env (Laravel):**
```bash
APP_NAME=Laravel
APP_ENV=local
APP_DEBUG=true
APP_URL=http://localhost:8080

DB_CONNECTION=mysql
DB_HOST=laravel-database
DB_PORT=3306
DB_DATABASE=laravel
DB_USERNAME=laravel
DB_PASSWORD=secret
```

**Note:** Place your Laravel project in `www/` directory.

---

## Symfony Development

**Use case:** Symfony application

**.env (Docker LAMP):**
```bash
COMPOSE_PROJECT_NAME=symfony
USER_ID=1000
GROUP_ID=1000

USE_REVERSE_PROXY=true
PROJECT_DOMAIN=symfony.local

PHPVERSION=php83
DATABASE=mysql8

DOCUMENT_ROOT=./www/public
APACHE_DOCUMENT_ROOT=/var/www/html

MYSQL_ROOT_PASSWORD=root
MYSQL_DATABASE=symfony
MYSQL_USER=symfony
MYSQL_PASSWORD=symfony
```

**.env (Symfony):**
```bash
APP_ENV=dev
APP_SECRET=your-secret-key

DATABASE_URL="mysql://symfony:symfony@symfony-database:3306/symfony?serverVersion=8.0"
```

**/etc/hosts:**
```
127.0.0.1    symfony.local
```

---

## E-commerce Platform

**Use case:** Multi-subdomain e-commerce site

**.env:**
```bash
COMPOSE_PROJECT_NAME=shop
USER_ID=1000
GROUP_ID=1000

USE_REVERSE_PROXY=true
PROJECT_DOMAIN=shop.local

PHPVERSION=php83
DATABASE=mysql8

DOCUMENT_ROOT=./www
APACHE_DOCUMENT_ROOT=/var/www/html

MYSQL_ROOT_PASSWORD=root
MYSQL_DATABASE=shop
MYSQL_USER=shop
MYSQL_PASSWORD=secret
```

**config/vhosts/shop.conf:**
```apache
<VirtualHost *:80>
    ServerName shop.local
    ServerAlias www.shop.local admin.shop.local api.shop.local
    DocumentRoot /var/www/html
    
    <Directory /var/www/html>
        AllowOverride All
        Require all granted
    </Directory>
    
    # Handle subdomain routing
    SetEnvIf Host ^admin\. SUBDOMAIN=admin
    SetEnvIf Host ^api\. SUBDOMAIN=api
    
    SetEnvIf X-Forwarded-Proto https HTTPS=on
</VirtualHost>
```

**/etc/hosts:**
```
127.0.0.1    shop.local
127.0.0.1    www.shop.local
127.0.0.1    admin.shop.local
127.0.0.1    api.shop.local
```

**Access:**
- https://shop.local (storefront)
- https://admin.shop.local (admin panel)
- https://api.shop.local (API)

---

## API Development

**Use case:** RESTful API development

**.env:**
```bash
COMPOSE_PROJECT_NAME=api
USER_ID=1000
GROUP_ID=1000

USE_REVERSE_PROXY=false
HTTP_PORT=8080
MYSQL_PORT=3306

PHPVERSION=php83
DATABASE=mysql8

DOCUMENT_ROOT=./www/public
APACHE_DOCUMENT_ROOT=/var/www/html

MYSQL_ROOT_PASSWORD=root
MYSQL_DATABASE=api
MYSQL_USER=api
MYSQL_PASSWORD=secret
```

**www/public/.htaccess:**
```apache
<IfModule mod_rewrite.c>
    RewriteEngine On
    
    # CORS headers
    Header always set Access-Control-Allow-Origin "*"
    Header always set Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
    Header always set Access-Control-Allow-Headers "Content-Type, Authorization"
    
    # Handle preflight
    RewriteCond %{REQUEST_METHOD} OPTIONS
    RewriteRule ^(.*)$ $1 [R=200,L]
    
    # API routing
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteRule ^(.*)$ index.php?request=$1 [QSA,L]
</IfModule>
```

**Access:**
- API: http://localhost:8080/api/v1/users
- API Docs: http://localhost:8080/docs

---

## Microservices Setup

**Use case:** Multiple microservices with gateway

### Gateway (.env):
```bash
COMPOSE_PROJECT_NAME=gateway
USE_REVERSE_PROXY=true
PROJECT_DOMAIN=gateway.local
HTTP_PORT=8080
PHPVERSION=php83
DATABASE=mysql8
MYSQL_DATABASE=gateway
```

### User Service (.env):
```bash
COMPOSE_PROJECT_NAME=users
USE_REVERSE_PROXY=true
PROJECT_DOMAIN=users.local
HTTP_PORT=8081
PHPVERSION=php83
DATABASE=mysql8
MYSQL_DATABASE=users
```

### Product Service (.env):
```bash
COMPOSE_PROJECT_NAME=products
USE_REVERSE_PROXY=true
PROJECT_DOMAIN=products.local
HTTP_PORT=8082
PHPVERSION=php83
DATABASE=mysql8
MYSQL_DATABASE=products
```

### Order Service (.env):
```bash
COMPOSE_PROJECT_NAME=orders
USE_REVERSE_PROXY=true
PROJECT_DOMAIN=orders.local
HTTP_PORT=8083
PHPVERSION=php83
DATABASE=mysql8
MYSQL_DATABASE=orders
```

**/etc/hosts:**
```
127.0.0.1    gateway.local
127.0.0.1    users.local
127.0.0.1    products.local
127.0.0.1    orders.local
```

**Architecture:**
```
Client → gateway.local (API Gateway)
          ├─> users.local (User Service)
          ├─> products.local (Product Service)
          └─> orders.local (Order Service)
```

---

## 💡 Tips

### Tip 1: Quick Project Switching
```bash
# Create aliases in ~/.bashrc or ~/.zshrc
alias lamp-project1='cd ~/projects/project1 && ./lamp.sh'
alias lamp-project2='cd ~/projects/project2 && ./lamp.sh'
alias lamp-project3='cd ~/projects/project3 && ./lamp.sh'
```

### Tip 2: Environment Variables in PHP
```php
<?php
// Access Docker environment variables
$dbHost = getenv('MYSQL_HOST') ?: 'localhost';
$dbName = getenv('MYSQL_DATABASE');
$dbUser = getenv('MYSQL_USER');
$dbPass = getenv('MYSQL_PASSWORD');
```

### Tip 3: Different PHP Versions for Different Projects
```bash
# Project 1: PHP 8.5 (latest features)
PHPVERSION=php85

# Project 2: PHP 8.4 (stable)
PHPVERSION=php84

# Project 3: PHP 8.3 (stable)
PHPVERSION=php83

# Project 4: PHP 8.2 (legacy)
PHPVERSION=php82

# Project 5: PHP 8.1 (legacy)
PHPVERSION=php81
```

### Tip 3b: Different Database Versions
```bash
# Latest MySQL
DATABASE=mysql84

# Latest MariaDB
DATABASE=mariadb121

# Stable MariaDB
DATABASE=mariadb118

# Older MariaDB
DATABASE=mariadb1011
```

### Tip 4: Resource Optimization
For limited resources, stop unused projects:
```bash
# Stop project 1
cd ~/projects/project1 && ./lamp.sh stop

# Start project 2
cd ~/projects/project2 && ./lamp.sh start
```

---

## 🧪 Testing Your Configuration

Before deploying, you can test your configuration using the test scripts:

```bash
cd test/
./test-config.sh php83 mysql8 9000 9300
```

This will:
- Create a test environment with your specified PHP and database versions
- Start containers on non-conflicting ports
- Verify everything works correctly
- Generate logs for debugging

See [test/README.md](../test/README.md) for complete documentation.

**Note for Windows users:** These scripts require Git Bash or WSL2. See the [Windows Guide](WINDOWS.md) for setup instructions.

## 📚 More Examples Needed?

Open an issue or pull request to add more examples!
