#!/usr/bin/env bash

if [[ "$EUID" -ne 0 ]]; then
  echo "This script must be run as root (use sudo)" >&2
  exit 1
fi

set -e

pcre_version="10.45"
zlib_version="1.3.1"
openssl_version="3.5.0"
nginx_version="1.28.0"

mariadb_version="10.11"
remote_ip="10.1.0.73"
db_user="dbadmin"
db_pass="Unix2025"

php_version="8.3.6"

start_dir="$(pwd)"
install_dir="/opt"

sudo mkdir -p "${install_dir}/src"
sudo chown "$(whoami):$(whoami)" "${install_dir}/src"

# Need to use sudo less

# maybe actually let's use wget and tar flags to do intelligent checks

# script needs to install software with dependencies libraries compiled from the source also
# maybe add others libs for php and mariadb

# add as services, run as services

sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y build-essential wget curl git tar cmake coreutils ccache

# For MariaDB
sudo apt-get install -y libncurses5-dev libncursesw5-dev libgnutls28-dev libbison-dev bison libssl-dev
# For PHP
sudo apt-get install -y libsqlite3-dev libonig-dev pkg-config libxml2-dev zlib1g-dev libtool-bin

# 1. MariaDB
cd "${install_dir}/src"
git clone --depth 1 --single-branch --branch "${mariadb_version}" https://github.com/MariaDB/server.git
cd server
mkdir build-mariadb-server-debug
cd build-mariadb-server-debug
sudo cmake .. -DCMAKE_INSTALL_PREFIX="${install_dir}/mariadb"
sudo cmake --build . --parallel 4
sudo cmake --install .
cd "$start_dir"

mkdir -p "${install_dir}/mariadb/data"
sudo groupadd --system --force mysql
id -u mysql &>/dev/null || sudo useradd --system --no-create-home --shell /usr/sbin/nologin --gid mysql mysql
sudo chown -R mysql:mysql "${install_dir}/mariadb"

cat <<EOF | sudo tee "${install_dir}/mariadb/my.cnf"
[mysqld]
basedir=${install_dir}/mariadb
datadir=${install_dir}/mariadb/data
socket=${install_dir}/mariadb/data/mysql.sock
pid-file=${install_dir}/mariadb/data/mariadb.pid
bind-address=0.0.0.0
log-error=${install_dir}/mariadb/data/mariadb.err
EOF

sudo "${install_dir}/mariadb/scripts/mariadb-install-db" \
  --defaults-file="${install_dir}/mariadb/my.cnf" \
  --user=mysql

sudo "${install_dir}/mariadb/bin/mariadbd-safe" \
  --defaults-file="${install_dir}/mariadb/my.cnf" \
  --user=mysql &
sleep 5

sudo "${install_dir}/mariadb/bin/mysql" -u root -S "${install_dir}/mariadb/data/mysql.sock" <<EOF
CREATE USER IF NOT EXISTS '${db_user}'@'${remote_ip}' IDENTIFIED BY '${db_pass}';
GRANT ALL PRIVILEGES ON *.* TO '${db_user}'@'${remote_ip}' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF



# 2. PHP
cd "${install_dir}/src"
wget "https://www.php.net/distributions/php-${php_version}.tar.gz"
tar -zxf "php-${php_version}.tar.gz"
cd "php-${php_version}"
sudo ./configure \
  --prefix="${install_dir}/php" \
  --with-fpm-user=www-data \
  --with-fpm-group=www-data \
  --enable-fpm \
  --with-mysqli=mysqlnd \
  --with-pdo-mysql=mysqlnd \
  --enable-mbstring \
  --enable-opcache
sudo make -j4
sudo make -j4 install

cp php.ini-production "${install_dir}/php/lib/php.ini"
cp "${install_dir}/php/etc/php-fpm.conf.default" "${install_dir}/php/etc/php-fpm.conf"
cp "${install_dir}/php/etc/php-fpm.d/www.conf.default" "${install_dir}/php/etc/php-fpm.d/www.conf"

sudo "${install_dir}/php/sbin/php-fpm"



# 3. NGINX
# Required by the NGINX Core and Rewrite modules
cd "${install_dir}/src"
wget "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${pcre_version}/pcre2-${pcre_version}.tar.gz"
tar -zxf "pcre2-${pcre_version}.tar.gz"
cd "$start_dir"

# Required by the NGINX Gzip module
cd "${install_dir}/src"
wget "https://github.com/madler/zlib/releases/download/v${zlib_version}/zlib-${zlib_version}.tar.gz"
tar -zxf "zlib-${zlib_version}.tar.gz"
cd "$start_dir"

# Required by the NGINX SSL module and others
cd "${install_dir}/src"
wget "https://github.com/openssl/openssl/releases/download/openssl-${openssl_version}/openssl-${openssl_version}.tar.gz"
tar -zxf "openssl-${openssl_version}.tar.gz"
cd "$start_dir"

# NGINX
cd "${install_dir}/src"
wget "https://github.com/nginx/nginx/releases/download/release-${nginx_version}/nginx-${nginx_version}.tar.gz"
tar -zxf "nginx-${nginx_version}.tar.gz"
cd "nginx-${nginx_version}"

sudo groupadd --system --force nginx
id -u nginx &>/dev/null || sudo useradd --system --no-create-home --shell /usr/sbin/nologin --gid nginx nginx

./configure \
  --prefix="${install_dir}/nginx" \
  --user=nginx \
  --group=nginx \
  --with-threads \
  --with-file-aio \
  --with-http_ssl_module \
  --with-http_v2_module \
  --with-http_gzip_static_module \
  --with-http_stub_status_module \
  --with-pcre="${install_dir}/src/pcre2-${pcre_version}" \
  --with-pcre-jit \
  --with-zlib="${install_dir}/src/zlib-${zlib_version}" \
  --with-openssl="${install_dir}/src/openssl-${openssl_version}"
sudo make -j4
sudo make -j4 install
cd "$start_dir"

mkdir -p /var/www/html
# maybe need to add tee here
#echo "<h1>Hello world</h1>" > /var/www/html/index.html
echo "<?php phpinfo(); ?>" > /var/www/html/info.php

cat <<EOF | sudo tee "${install_dir}/nginx/conf/nginx.conf"
worker_processes  1;

events {
    worker_connections  1024;
}

http {
    include       ${install_dir}/nginx/conf/mime.types;
    default_type  application/octet-stream;

    sendfile        on;
    keepalive_timeout  65;

    server {
        listen       80;
        server_name  localhost;

        location / {
            root   /var/www/html;
            index  index.php index.html index.htm;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /var/www/html;
        }

        location ~ \.php$ {
            root           /var/www/html;
            fastcgi_pass   127.0.0.1:9000;
            fastcgi_index  index.php;
            fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
            include        fastcgi_params;
        }

        location ~ /\.ht {
            deny  all;
        }
    }
}
EOF

"${install_dir}/nginx/sbin/nginx"