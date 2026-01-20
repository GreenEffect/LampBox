FROM php:8.1-apache-buster

# Suppress debconf complaints of trying to install apt packages interactively
ARG DEBIAN_FRONTEND=noninteractive
ARG COMPOSE_PROJECT_NAME

# Définir COMPOSE_PROJECT_NAME comme variable d'environnement accessible dans tout le conteneur
ENV COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}

# Update packages and install basic dependencies
RUN apt-get -y update --fix-missing && \
    apt-get upgrade -y && \
    apt-get --no-install-recommends install -y apt-utils && \
    rm -rf /var/lib/apt/lists/*

# Install useful tools and important libraries
RUN apt-get -y update && \
    apt-get -y --no-install-recommends install nano wget dialog libsqlite3-dev libsqlite3-0 && \
    apt-get -y --no-install-recommends install default-mysql-client zlib1g-dev libzip-dev libicu-dev && \
    apt-get -y --no-install-recommends install --fix-missing apt-utils build-essential git curl libonig-dev && \
    apt-get install -y iputils-ping && \
    apt-get -y --no-install-recommends install --fix-missing libcurl4 libcurl4-openssl-dev zip openssl && \
    rm -rf /var/lib/apt/lists/* && \
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Install xdebug
RUN pecl install xdebug-3.1.4 && \
    docker-php-ext-enable xdebug && \
    mkdir /var/log/xdebug

# Install redis
RUN pecl install redis-5.3.3 && \
    docker-php-ext-enable redis

# Install imagick
RUN apt-get update && \
    apt-get -y --no-install-recommends install --fix-missing libmagickwand-dev && \
    rm -rf /var/lib/apt/lists/*

# Workaround to install imagick with PHP 8 support
ARG IMAGICK_COMMIT="661405abe21d12003207bc8eb0963fafc2c02ee4"
RUN cd /usr/local/src && \
    git clone https://github.com/Imagick/imagick && \
    cd imagick && \
    git checkout ${IMAGICK_COMMIT} && \
    phpize && \
    ./configure && \
    make && \
    make install && \
    cd .. && \
    rm -rf imagick && \
    docker-php-ext-enable imagick

# Other PHP Extensions
RUN docker-php-ext-install pdo_mysql && \
    docker-php-ext-install pdo_sqlite && \
    docker-php-ext-install bcmath && \
    docker-php-ext-install mysqli && \
    docker-php-ext-install curl && \
    docker-php-ext-install zip && \
    docker-php-ext-install -j$(nproc) intl && \
    docker-php-ext-install mbstring && \
    docker-php-ext-install gettext && \
    docker-php-ext-install calendar && \
    docker-php-ext-install exif

# Install Freetype
RUN apt-get -y update && \
    apt-get --no-install-recommends install -y libfreetype6-dev libjpeg62-turbo-dev libpng-dev && \
    rm -rf /var/lib/apt/lists/* && \
    docker-php-ext-configure gd --enable-gd --with-freetype --with-jpeg && \
    docker-php-ext-install gd

# Ensure an SSL directory exists
RUN mkdir -p /etc/apache2/ssl

# Enable SSL and other Apache modules
RUN a2enmod ssl rewrite headers

###
RUN apt-get update && \
    apt-get install -y unzip

# Install phpMyAdmin
ARG PHPMYADMIN_VERSION=5.2.1
RUN wget https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN_VERSION}/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.zip -O /tmp/phpmyadmin.zip && \
    unzip /tmp/phpmyadmin.zip -d /opt/ && \
    mv /opt/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages /opt/phpmyadmin && \
    rm /tmp/phpmyadmin.zip

# Configure Apache for phpMyAdmin avec sh -c pour forcer l'évaluation
RUN sh -c 'echo "Alias /${COMPOSE_PROJECT_NAME}-mysql /opt/phpmyadmin\n\
<Directory /opt/phpmyadmin>\n\
    Options Indexes FollowSymLinks\n\
    AllowOverride None\n\
    Require all granted\n\
</Directory>" > /etc/apache2/conf-available/phpmyadmin.conf' && \
    a2enconf phpmyadmin

# Set default document root for Apache
ENV APACHE_DOCUMENT_ROOT=/var/www/html
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
