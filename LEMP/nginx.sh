#!/usr/bin/env bash

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

# I need to use sudo less

# check_root() {
#     if [ "$(id -u)" -ne 0 ]; then
#         echo "This script must be run as root" >&2
#         exit 1
#     fi
# }

# !!!!!!!
# If you want PHP-FPM (to use with NGINX): You'll need libfcgi-dev or libfcgi0ldbl.

# If you run the script twice, groupadd and useradd will fail.

# maybe actually let's use wget and tar flags to do intelligent checks

# script needs to install software with dependencies libraries compiled from the source also

# look into how to create a mariadb user and group

# make long lines easier to read with \

# add as services

sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y build-essential wget curl git tar cmake

# For MariaDB
sudo apt-get install -y libncurses5-dev libncursesw5-dev libgnutls28-dev bison
# For PHP
sudo apt-get install -y libsqlite3-dev libonig-dev
#sudo apt-get install -y libgd-dev libgeoip-dev geoip-bin libxml2 libxml2-dev libxslt1.1 libxslt1-dev perl libperl-dev libgd3 libgeoip1

#sudo apt-get install -y libfcgi-dev libfcgi0ldbl
#sudo apt-get install -y php-fpm

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
sudo groupadd -f mysql
sudo useradd -g mysql mysql
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

sleep 5

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
cp sapi/fpm/php-fpm.conf "${install_dir}/php/etc/php-fpm.conf"
cp sapi/fpm/www.conf "${install_dir}/php/etc/php-fpm.d/www.conf"

sed -i "s|^listen = .*|listen = ${install_dir}/php/var/run/php-fpm.sock|" "${install_dir}/php/etc/php-fpm.d/www.conf"
mkdir -p "${install_dir}/php/var/run"
chown -R www-data:www-data "${install_dir}/php/var"

sed -i "s|fastcgi_pass.*;|fastcgi_pass   unix:${install_dir}/php/var/run/php-fpm.sock;|" "${install_dir}/nginx/conf/nginx.conf"
sed -i 's|fastcgi_param[[:space:]]\+SCRIPT_FILENAME.*;|fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;|' "${install_dir}/nginx/conf/nginx.conf"



# 3. NGINX
# Required by the NGINX Core and Rewrite modules.
cd "${install_dir}/src"
wget "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${pcre_version}/pcre2-${pcre_version}.tar.gz"
tar -zxf "pcre2-${pcre_version}.tar.gz"
cd "pcre2-${pcre_version}"
sudo ./configure --prefix="${install_dir}/pcre"
sudo make -j4
sudo make -j4 install
cd "$start_dir"

# Required by the NGINX Gzip module.
cd "${install_dir}/src"
wget "https://github.com/madler/zlib/releases/download/v${zlib_version}/zlib-${zlib_version}.tar.gz"
tar -zxf "zlib-${zlib_version}.tar.gz"
cd "zlib-${zlib_version}"
sudo ./configure --prefix="${install_dir}/zlib"
sudo make -j4
sudo make -j4 install
cd "$start_dir"

# Required by the NGINX SSL module and others.
cd "${install_dir}/src"
wget "https://github.com/openssl/openssl/releases/download/openssl-${openssl_version}/openssl-${openssl_version}.tar.gz"
tar -zxf "openssl-${openssl_version}.tar.gz"
cd "openssl-${openssl_version}"
sudo ./config --prefix="${install_dir}/openssl"
sudo make -j4
sudo make -j4 install
cd "$start_dir"

# NGINX
cd "${install_dir}/src"
wget "https://github.com/nginx/nginx/releases/download/release-${nginx_version}/nginx-${nginx_version}.tar.gz"
tar -zxf "nginx-${nginx_version}.tar.gz"
cd "nginx-${nginx_version}"

sudo groupadd --system nginx
sudo useradd --system --no-create-home --shell /bin/false --group nginx nginx

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

sed -i 's|root[[:space:]]\+html;|root   /var/www/html;|' "${install_dir}/nginx/conf/nginx.conf"
sudo mkdir -p /var/www/html
echo "<h1>Hello world</h1>" | sudo tee /var/www/html/index.html
echo "<?php phpinfo(); ?>" | sudo tee /var/www/html/info.php

"${install_dir}/php/sbin/php-fpm" --fpm-config "${install_dir}/php/etc/php-fpm.conf" &

sudo "${install_dir}/nginx/sbin/nginx" -s reload || sudo "${install_dir}/nginx/sbin/nginx"