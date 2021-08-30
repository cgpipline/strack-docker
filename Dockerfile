FROM php:7.4.23-fpm-alpine3.14

# Add basics first
RUN apk --no-cache update && apk upgrade && apk --no-cache add \
	bash curl ca-certificates openssl openssh git nano libxml2-dev tzdata icu-dev openntpd libedit-dev libzip-dev libjpeg-turbo-dev libpng-dev freetype-dev \
	    autoconf dpkg-dev dpkg file g++ gcc libc-dev make pkgconf re2c pcre-dev openssl-dev libffi-dev libressl-dev libevent-dev zlib-dev libtool automake \
        nginx supervisor

RUN docker-php-ext-install soap zip pcntl sockets intl exif opcache pdo_mysql mysqli bcmath calendar gd ldap


# Configure PHP
COPY config/php.ini /usr/local/etc/php/conf.d/zzz_custom.ini

# Configure nginx
COPY config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY config/fpm-pool.conf /usr/local/etc/php/conf.d/zzz_custom.conf
COPY config/php.ini /usr/local/etc/php/conf.d/zzz_custom.ini

# install event
RUN pecl install -o -f event \
    && echo extension=event.so >> /usr/local/etc/php/conf.d/docker-php-ext-sockets.ini \
    && pecl clear-cache

# Add Composer
RUN curl -sS https://getcomposer.org/installer | php && mv composer.phar /usr/local/bin/composer

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Add application
RUN mkdir -p /var/www
WORKDIR /var/www

EXPOSE 80
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
