#!/usr/bin/env bash

set -e

pcre_version="10.45"
zlib_version="1.3.1"
openssl_version="3.5.0"
nginx_version="1.28.0"

start_dir=$(pwd)

sudo mkdir -p /opt/src
sudo chown "$(whoami):$(whoami)" /opt/src

# maybe also change the owner of /opt?

# maybe some of these are redundant and maybe defeat the purpose of installing from source?
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y build-essential software-properties-common wget curl git gcc make tar
sudo apt-get install -y libgd-dev libgeoip-dev geoip-bin libxml2 libxml2-dev libxslt1.1 libxslt1-dev perl libperl-dev libgd3 libgeoip1



# Required by the NGINX Core and Rewrite modules.
cd /opt/src
wget "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${pcre_version}/pcre2-${pcre_version}.tar.gz"
tar -zxf "pcre2-${pcre_version}.tar.gz"
cd "pcre2-${pcre_version}"
sudo ./configure --prefix=/opt/pcre
sudo make -j4
sudo make -j4 install
cd "$start_dir"

# Required by the NGINX Gzip module.
cd /opt/src
sudo wget "https://github.com/madler/zlib/releases/download/v${zlib_version}/zlib-${zlib_version}.tar.gz"
tar -zxf "zlib-${zlib_version}.tar.gz"
cd "zlib-${zlib_version}"
sudo ./configure --prefix=/opt/zlib
sudo make -j4
sudo make -j4 install
cd "$start_dir"

# Required by the NGINX SSL module and others.
cd /opt/src
wget "https://github.com/openssl/openssl/releases/download/openssl-${openssl_version}/openssl-${openssl_version}.tar.gz"
tar -zxf "openssl-${openssl_version}.tar.gz"
cd "openssl-${openssl_version}"
sudo ./config --prefix=/opt/openssl
sudo make -j4
sudo make -j4 install
cd "$start_dir"

# NGINX
cd /opt/src
wget "https://github.com/nginx/nginx/releases/download/release-${nginx_version}/nginx-${nginx_version}.tar.gz"
tar -zxf "nginx-${nginx_version}.tar.gz"
cd "nginx-${nginx_version}"

sudo groupadd --system nginx
sudo useradd --system --no-create-home --shell /bin/false --group nginx nginx

./configure \
    --prefix=/opt/nginx \
    --sbin-path=/opt/nginx/sbin/nginx \
    --modules-path=/opt/nginx/modules \
    --conf-path=/opt/nginx/conf/nginx.conf \
    --error-log-path=/opt/nginx/logs/error.log \
    --http-log-path=/opt/nginx/logs/access.log \
    --pid-path=/opt/nginx/run/nginx.pid \
    --lock-path=/opt/nginx/run/nginx.lock \
    --user=nginx \
    --group=nginx \
    --with-threads \
    --with-file-aio \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_sub_module \
    --with-http_mp4_module \
    --with-http_gzip_static_module \
    --with-http_auth_request_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_stub_status_module \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_realip_module \
    --with-compat \
    --with-pcre=/opt/src/pcre2-${pcre_version} \
    --with-pcre-jit \
    --with-zlib=/opt/src/zlib-${zlib_version} \
    --with-openssl=/opt/src/openssl-${openssl_version}

sudo make -j4
sudo make -j4 install
sudo /opt/nginx/sbin/nginx
curl localhost
/opt/nginx/sbin/nginx -V
cd "$start_dir"