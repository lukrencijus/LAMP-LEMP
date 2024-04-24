#!/usr/bin/env bash

wget https://dlcdn.apache.org/httpd/httpd-2.4.59.tar.gz
wget https://dlcdn.apache.org//apr/apr-1.7.4.tar.gz
wget https://dlcdn.apache.org//apr/apr-util-1.6.3.tar.gz
wget https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.43/pcre2-10.43.tar.gz
sudo apt-get update
sudo apt install git -y
sudo apt-get install build-essential -y
tar -xf apr-1.7.4.tar.gz
tar -xf apr-util-1.6.3.tar.gz
tar -xf httpd-2.4.59.tar.gz
tar -xf pcre2-10.43.tar.gz

cd apr-1.7.4/
./configure --prefix=/opt/apache24/apr
sudo make
sudo make install
cd ..

cd apr-util-1.6.3/`
./configure --prefix=/opt/apache24/apr-util --with-apr=/opt/apache24/apr
sudo apt-get install libexpat1-dev
sudo apt-get install libncurses5-dev
sudo make
sudo make install
cd ..

cd pcre2-10.43
./configure --prefix=/opt/apache24/pcre
sudo make
sudo make install
cd ..

cd httpd-2.4.59
./configure --prefix=/opt/apache24 --with-apr=/opt/apache24/apr --with-apr-util=/opt/apache24/apr-util --with-pcre=/opt/apache24/pcre/bin/pcre2-config
sudo make
sudo make install
cd ..

cd bin
sudo ./apachectl -k start
curl http://localhost
