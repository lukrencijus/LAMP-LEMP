#!/usr/bin/env bash

#sudo apt-get update
#sudo apt install git -y
#git clone https://git.mif.vu.lt/luse0397/lamp_install.git
#cd lamp_install
#chmod +rwx lamp_install.sh
#./lamp_install.sh -y

sudo apt-get update
sudo apt-get install build-essential -y
wget https://dlcdn.apache.org/httpd/httpd-2.4.59.tar.gz
wget https://dlcdn.apache.org//apr/apr-1.7.4.tar.gz
wget https://dlcdn.apache.org//apr/apr-util-1.6.3.tar.gz
wget https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.43/pcre2-10.43.tar.gz
tar -xf apr-1.7.4.tar.gz
tar -xf apr-util-1.6.3.tar.gz
tar -xf httpd-2.4.59.tar.gz
tar -xf pcre2-10.43.tar.gz

cd apr-1.7.4/
./configure --prefix=/opt/apache24/apr
sudo make
sudo make install
cd ..

cd apr-util-1.6.3/
./configure --prefix=/opt/apache24/apr-util --with-apr=/opt/apache24/apr
sudo apt-get install libexpat1-dev
sudo make
sudo make install
cd ..

cd pcre2-10.43
./configure --prefix=/opt/apache24/pcre
sudo make
sudo make install
cd ..

cd httpd-2.4.59
./configure --prefix=/opt/apache24/apache --with-apr=/opt/apache24/apr --with-apr-util=/opt/apache24/apr-util --with-pcre=/opt/apache24/pcre/bin/pcre2-config
sudo make
sudo make install
cd ..

cd /opt/apache24/bin
sudo ./apachectl -k start
curl http://localhost
