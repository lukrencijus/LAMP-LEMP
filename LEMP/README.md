Script downloads LEMP stack from source code (~~Linux~~, NGINX, MariaDB, PHP)

Does downloading, extracting, configuring, compiling installing and testing.

Saved in /opt/

## To run the script:

sudo apt-get update

sudo apt install git -y

git clone https://git.mif.vu.lt/luse0397/unix25task2.git

cd unix25task2

chmod +rwx lamp_install.sh

sudo ./lamp_install.sh -y