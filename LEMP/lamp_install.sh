#!/usr/bin/env bash

if [[ "$EUID" -ne 0 ]]; then
  echo "This script must be run as root (sudo $0)" >&2
  exit 1
fi

set -e

# is www user created
# maybe other libs also install
# meaning of service files
# install tee and sed
# remove cat from nginx
#  > /dev/null remove from php and nginx maybe
# maybe it would make sence to change the owner of each lamp part to it's owner? not just one folder?

pcre_version="10.45"
zlib_version="1.3.1"
openssl_version="3.5.0"

mariadb_version="10.11"
remote_ip="10.1.0.73"
db_user="dbadmin"
db_pass="Unix2025"

php_version="8.3.6"

nginx_version="1.28.0"

start_dir="$(pwd)"
install_dir="/opt"

mkdir -p "${install_dir}/src"
chown "$(whoami):$(whoami)" "${install_dir}/src"

apt-get update
apt-get upgrade -y
apt-get install -y build-essential wget curl git tar cmake coreutils ccache sudo

# For MariaDB
apt-get install -y libncurses5-dev libncursesw5-dev libgnutls28-dev libbison-dev bison libssl-dev
# For PHP
apt-get install -y libsqlite3-dev libonig-dev pkg-config libxml2-dev zlib1g-dev libtool-bin

# 0. Dependencies
cd "${install_dir}/src"
wget -nc "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${pcre_version}/pcre2-${pcre_version}.tar.gz"
tar -zxf "pcre2-${pcre_version}.tar.gz"
cd "pcre2-${pcre_version}"
./configure --prefix="${install_dir}/pcre"
make -j4
make -j4 install

cd "${install_dir}/src"
wget -nc "https://github.com/madler/zlib/releases/download/v${zlib_version}/zlib-${zlib_version}.tar.gz"
tar -zxf "zlib-${zlib_version}.tar.gz"
cd "zlib-${zlib_version}"
./configure --prefix="${install_dir}/zlib"
make -j4
make -j4 install

cd "${install_dir}/src"
wget -nc "https://github.com/openssl/openssl/releases/download/openssl-${openssl_version}/openssl-${openssl_version}.tar.gz"
tar -zxf "openssl-${openssl_version}.tar.gz"
cd "openssl-${openssl_version}"
./config --prefix="${install_dir}/openssl" --openssldir="${install_dir}/openssl"
make -j4
make -j4 install



# 1. MariaDB
cd "${install_dir}/src"
git clone --depth 1 --single-branch --branch "${mariadb_version}" https://github.com/MariaDB/server.git
cd server
mkdir build-mariadb-server-debug
cd build-mariadb-server-debug
cmake .. \
  -DCMAKE_INSTALL_PREFIX="${install_dir}/mariadb" \
  -DWITH_SSL="${install_dir}/openssl" \
  -DZLIB_INCLUDE_DIR="${install_dir}/zlib/include" \
  -DZLIB_LIBRARY="${install_dir}/zlib/lib/libz.so"
cmake --build . --parallel 4
cmake --install .

mkdir -p "${install_dir}/mariadb/data"
groupadd --system --force mysql
id -u mysql &>/dev/null || useradd --system --no-create-home --shell /usr/sbin/nologin --gid mysql mysql
chown -R mysql:mysql "${install_dir}/mariadb"

tee "${install_dir}/mariadb/my.cnf" <<EOF
[mysqld]
basedir=${install_dir}/mariadb
datadir=${install_dir}/mariadb/data
socket=${install_dir}/mariadb/data/mysql.sock
pid-file=${install_dir}/mariadb/data/mariadb.pid
bind-address=0.0.0.0
log-error=${install_dir}/mariadb/data/mariadb.err
EOF

"${install_dir}/mariadb/scripts/mariadb-install-db" \
  --defaults-file="${install_dir}/mariadb/my.cnf" \
  --user=mysql

tee /etc/systemd/system/mariadb.service <<EOF
[Unit]
Description=MariaDB
After=network.target

[Service]
Type=simple
User=mysql
Group=mysql
ExecStart=${install_dir}/mariadb/bin/mariadbd-safe --defaults-file=${install_dir}/mariadb/my.cnf --user=mysql
ExecStop=${install_dir}/mariadb/bin/mysqladmin --defaults-file=${install_dir}/mariadb/my.cnf --user=root --socket=${install_dir}/mariadb/data/mysql.sock shutdown
PIDFile=${install_dir}/mariadb/data/mariadb.pid
TimeoutSec=300
Restart=on-failure
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mariadb
systemctl start mariadb
sleep 5

"${install_dir}/mariadb/bin/mysql" -u root -S "${install_dir}/mariadb/data/mysql.sock" <<EOF
CREATE USER IF NOT EXISTS '${db_user}'@'${remote_ip}' IDENTIFIED BY '${db_pass}';
GRANT ALL PRIVILEGES ON *.* TO '${db_user}'@'${remote_ip}' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF



# 2. PHP
cd "${install_dir}/src"
wget -nc "https://www.php.net/distributions/php-${php_version}.tar.gz"
tar -zxf "php-${php_version}.tar.gz"
cd "php-${php_version}"
export PKG_CONFIG_PATH="${install_dir}/openssl/lib/pkgconfig:${install_dir}/zlib/lib/pkgconfig:$PKG_CONFIG_PATH"
export LD_LIBRARY_PATH="${install_dir}/openssl/lib:${install_dir}/zlib/lib:$LD_LIBRARY_PATH"
export CFLAGS="-I${install_dir}/openssl/include -I${install_dir}/zlib/include $CFLAGS"
export LDFLAGS="-L${install_dir}/openssl/lib -L${install_dir}/zlib/lib $LDFLAGS"
./configure \
  --prefix="${install_dir}/php" \
  --with-fpm-user=www-data \
  --with-fpm-group=www-data \
  --enable-fpm \
  --with-mysqli=mysqlnd \
  --with-pdo-mysql=mysqlnd \
  --enable-mbstring \
  --enable-opcache \
  --with-openssl \
  --with-zlib
make -j4
make -j4 install

cp php.ini-production "${install_dir}/php/lib/php.ini"
cp "${install_dir}/php/etc/php-fpm.conf.default" "${install_dir}/php/etc/php-fpm.conf"
cp "${install_dir}/php/etc/php-fpm.d/www.conf.default" "${install_dir}/php/etc/php-fpm.d/www.conf"

mkdir -p "${install_dir}/php/var/run"
chown -R www-data:www-data "${install_dir}/php/var"

tee /etc/systemd/system/php-fpm.service > /dev/null <<EOF
[Unit]
Description=PHP
After=network.target

[Service]
Type=simple
ExecStart=${install_dir}/php/sbin/php-fpm --nodaemonize --fpm-config ${install_dir}/php/etc/php-fpm.conf
ExecReload=/bin/kill -USR2 \$MAINPID
User=www-data
Group=www-data
Restart=on-failure
Environment="LD_LIBRARY_PATH=${install_dir}/openssl/lib:${install_dir}/zlib/lib"

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable php-fpm
systemctl start php-fpm



# 3. NGINX
cd "${install_dir}/src"
wget -nc "https://github.com/nginx/nginx/releases/download/release-${nginx_version}/nginx-${nginx_version}.tar.gz"
tar -zxf "nginx-${nginx_version}.tar.gz"
cd "nginx-${nginx_version}"

groupadd --system --force nginx
id -u nginx &>/dev/null || useradd --system --no-create-home --shell /usr/sbin/nologin --gid nginx nginx

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
make -j4
make -j4 install

mkdir -p /var/www/html
echo "<?php phpinfo(); ?>" > /var/www/html/info.php

mkdir -p "${install_dir}/nginx/run"
mkdir -p "${install_dir}/nginx/logs"
chown -R nginx:nginx "${install_dir}/nginx"

cat <<EOF | tee "${install_dir}/nginx/conf/nginx.conf"
user  nginx;
worker_processes  1;
pid ${install_dir}/nginx/logs/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       ${install_dir}/nginx/conf/mime.types;
    default_type  application/octet-stream;

    access_log  ${install_dir}/nginx/logs/access.log;
    error_log   ${install_dir}/nginx/logs/error.log;

    sendfile        on;
    keepalive_timeout  65;

    server {
        listen       80;
        server_name  localhost;

        root   /var/www/html;
        index  index.php index.html index.htm;

        location / {
            try_files \$uri \$uri/ =404;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /var/www/html;
        }

        location ~ \.php$ {
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

tee /etc/systemd/system/nginx.service > /dev/null <<EOF
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=network.target

[Service]
Type=forking
PIDFile=${install_dir}/nginx/logs/nginx.pid
ExecStartPre=${install_dir}/nginx/sbin/nginx -t -c ${install_dir}/nginx/conf/nginx.conf
ExecStart=${install_dir}/nginx/sbin/nginx -c ${install_dir}/nginx/conf/nginx.conf
ExecReload=${install_dir}/nginx/sbin/nginx -s reload
ExecStop=${install_dir}/nginx/sbin/nginx -s quit
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable nginx
systemctl start nginx

curl localhost/info.php
systemctl status mariadb --no-pager
systemctl status php-fpm --no-pager
systemctl status nginx --no-pager