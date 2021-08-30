FROM centos:centos7

MAINTAINER weijer

ENV SRC_DIR /usr/local
ENV PHP_VERSION 7.4.23
ENV PHP_DIR /usr/local/php/${PHP_VERSION}
ENV PHP_INI_DIR /etc/php/${PHP_VERSION}/cli
ENV INIT_FILE ${PHP_INI_DIR}/conf.d
ENV PHPREDIS_VERSION 5.3.4
ENV HTTPD_PREFIX /usr/local/apache2

#set ldconf
RUN echo "include /etc/ld.so.conf.d/*.conf" > /etc/ld.so.conf \
    && cd /etc/ld.so.conf.d \
    && echo "/usr/local/lib" > /etc/ld.so.conf.d/libc.conf

# tools
RUN yum -y update

RUN yum -y install \
        wget \
        gcc \
        make \
        autoconf \
        libxml2 \
        libxml2-devel \
        libjpeg-turbo \
        libjpeg-turbo-devel \
        libpng \
        libpng-devel \
        openssl \
        openssl-devel \
        curl \
        curl-devel \
        pcre \
        pcre-devel \
        libxslt \
        libxslt-devel \
        freetype-devel \
        bzip2 \
        bzip2-devel \
        libedit \
        libedit-devel \
        glibc-headers \
        gcc-c++ \
        openldap \
        openldap-devel \
        python-setuptools \
        libevent-dev \
    && cp -frp /usr/lib64/libldap* /usr/lib/  \
    && rm -rf /var/cache/{yum,ldconfig}/* \
    && rm -rf /etc/ld.so.cache \
    && yum clean all

RUN easy_install supervisor

# 配置Apache
ADD install-httpd.sh /
RUN chmod +x /install-httpd.sh
RUN sed -i 's/\r//' /install-httpd.sh
RUN bash -c "/install-httpd.sh"
ADD config/httpd/ /usr/local/apache2/conf
RUN ln -sf /dev/stdout /usr/local/apache2/logs/access_log
RUN ln -sf /dev/stdout /usr/local/apache2/logs/error_log

# 安装php
ADD install/php-${PHP_VERSION}.tar.gz ${SRC_DIR}/
RUN cd ${SRC_DIR}/php-${PHP_VERSION} \
    && ln -s /usr/lib64/libssl.so /usr/lib \
    && ./configure --prefix=${PHP_DIR} \
        --with-config-file-path=${PHP_INI_DIR} \
       	--with-config-file-scan-dir="${PHP_INI_DIR}/conf.d" \
       --disable-cgi \
       --enable-fpm \
       --enable-bcmath \
       --enable-mbstring \
       --enable-mysqlnd \
       --enable-opcache \
       --enable-pcntl \
       --enable-fileinfo \
       --enable-xml \
       --enable-zip \
       --enable-intl \
       --enable-sockets \
       --enable-gd \
       --with-curl \
       --with-png-dir \
       --with-jpeg-dir \
       --with-gettext \
       --with-freetype-dir \
       --with-libedit \
       --with-openssl \
       --with-zlib \
       --with-curl \
       --with-mysqli \
       --with-pdo-mysql \
       --with-pear \
       --with-zlib \
       --with-ldap \
       --with-jpeg-dir=/usr \
    && sed -i '/^EXTRA_LIBS/ s/$/ -llber/' Makefile \
    && make clean > /dev/null \
    && make \
    && make install \
    && ln -s ${PHP_DIR}/bin/php /usr/local/bin/ \
    && ln -s ${PHP_DIR}/bin/phpize /usr/local/bin/ \
    && ln -s ${PHP_DIR}/bin/pecl /usr/local/bin/ \
    && ln -s ${PHP_DIR}/bin/php-config /usr/local/bin/ \
    && mkdir -p ${PHP_INI_DIR}/conf.d \
    && cp ${SRC_DIR}/php-${PHP_VERSION}/php.ini-production ${PHP_INI_DIR}/php.ini \
    && echo -e "opcache.enable=1\nopcache.enable_cli=1\nzend_extension=opcache.so" > ${PHP_INI_DIR}/conf.d/10-opcache.ini \
    && rm -f ${SRC_DIR}/php-${PHP_VERSION}.tar.gz \
    && rm -rf ${SRC_DIR}/php-${PHP_VERSION}

# php-fpm配置文件
COPY config/php-fpm/php-fpm-7.2.conf /usr/local/php/${PHP_VERSION}/etc/php-fpm.conf

#  redis && event
RUN pecl install -o -f redis \
    && pecl install -o -f event \
    && docker-php-ext-enable redis \
    && echo -e "extension=event.so" > ${PHP_INI_DIR}/conf.d/z-event.ini \
    && pecl clear-cache

# composer
RUN curl -sS https://getcomposer.org/installer | php \
    && mv composer.phar /usr/local/bin/composer

COPY ./config/* ${INIT_FILE}/

# ADD Source
ADD app/ /app

# Working dir
WORKDIR $HTTPD_PREFIX

# Run
COPY supervisord.conf /etc/supervisor/supervisord.conf

# Run queue worker progress
RUN cd /app \
    && php queue.php start -d

CMD ["/usr/bin/supervisord"]
EXPOSE 80
