FROM alpine:latest

# Install packages
RUN apk --no-cache update && apk --no-cache add curl libevent-dev php7 php7-fpm \
    php7-mysqli php7-pdo php7-pdo_mysql  php7-json php7-bcmath php7-sockets php7-opcache php7-openssl php7-curl php7-zlib php7-xml \
	php7-phar php7-intl php7-dom php7-xmlreader php7-ctype php7-session  php7-ldap \
	php7-mbstring php7-gd php7-redis nginx supervisor

# Add Composer
RUN curl -sS https://getcomposer.org/installer | php && mv composer.phar /usr/local/bin/composer

# Configure nginx
COPY config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY config/fpm-pool.conf /etc/php7/php-fpm.d/zzz_custom.conf
COPY config/php.ini /etc/php7/conf.d/zzz_custom.ini

# install event
RUN pecl install -o -f event \
    && echo extension=event.so >> /etc/php7/conf.d/zzz_custom.ini \
    && pecl clear-cache

RUN php -m

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Add application
RUN mkdir -p /var/www
WORKDIR /var/www

EXPOSE 80
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
