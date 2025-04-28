#!/usr/bin/env bash

start_dir=$(pwd)

sudo apt-get update
sudo apt upgrade -y
sudo apt-get install build-essential -y
sudo apt-get install -y git gcc g++ autoconf libtool-bin libexpat1 libexpat1-dev libpcre2-dev libncurses-dev libgnutls28-dev libbison-dev libsqlite3-dev re2c zlib1g-dev texinfo gettext automake autopoint
sudo apt-get install -y make libssl-dev libpcre3 libpcre3-dev libapr1-dev libaprutil1-dev pkg-config libncurses5-dev bison ccache libxml2-dev libapr1 expat
sudo apt-get install -y curl wget tar cmake



wget https://dlcdn.apache.org/httpd/httpd-2.4.59.tar.gz
wget https://dlcdn.apache.org//apr/apr-1.7.4.tar.gz
wget https://dlcdn.apache.org//apr/apr-util-1.6.3.tar.gz
wget https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.43/pcre2-10.43.tar.gz
tar -xf apr-1.7.4.tar.gz
tar -xf apr-util-1.6.3.tar.gz
tar -xf httpd-2.4.59.tar.gz
tar -xf pcre2-10.43.tar.gz

cd apr-1.7.4/
sudo ./configure --prefix=/opt/apache/apr
sudo make -j4
sudo make -j4 install
cd "$start_dir"

cd apr-util-1.6.3/
sudo ./configure --prefix=/opt/apache/apr-util --with-apr=/opt/apache/apr
sudo make -j4
sudo make -j4 install
cd "$start_dir"

cd pcre2-10.43
sudo ./configure --prefix=/opt/apache/pcre
sudo make -j4
sudo make -j4 install
cd "$start_dir"

cd httpd-2.4.59
sudo ./configure --prefix=/opt/apache/apache --with-apr=/opt/apache/apr --with-apr-util=/opt/apache/apr-util --with-pcre=/opt/apache/pcre/bin/pcre2-config
sudo make -j4
sudo make -j4 install
cd "$start_dir"

cd /opt/apache/apache/bin
sudo ./apachectl -k start
cd "$start_dir"



wget https://www.php.net/distributions/php-8.3.6.tar.gz
tar -xf php-8.3.6.tar.gz
cd php-8.3.6
sudo ./configure --prefix=/opt/php --with-apxs2=/opt/apache/apache/bin/apxs
sudo make -j4
sudo make -j4 install
cd "$start_dir"



git clone --depth 1 --single-branch --branch 10.11 https://github.com/MariaDB/server.git
cd server
mkdir build-mariadb-server-debug
cd build-mariadb-server-debug
sudo cmake .. -DCMAKE_INSTALL_PREFIX=/opt/mariadb
sudo cmake --build . --parallel 4
sudo cmake --install .
cd "$start_dir"

sudo groupadd mysql
sudo useradd -g mysql mysql
sudo chown -R mysql:mysql /opt/mariadb
sudo echo "[mariadb]
datadir=/opt/mariadb/data/" > ./my.cnf
sudo chmod +rwx my.cnf
sudo mv ./my.cnf /etc
sudo /opt/mariadb/scripts/mysql_install_db --user=mysql
sudo /opt/mariadb/bin/mariadbd-safe --user=mysql &



echo
sudo /opt/apache/apache/bin/apachectl -v
echo
sudo curl http://localhost
echo
sudo /opt/php/bin/php -v
echo
sudo /opt/mariadb/bin/mariadb -V
echo
cd /opt/mariadb/bin
sleep 5s
sudo ./mariadb-admin ping
cd "$start_dir"
