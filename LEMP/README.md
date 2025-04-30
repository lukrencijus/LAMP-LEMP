Script downloads LEMP stack from source code (~~Linux~~, NGINX, MariaDB, PHP)

Does downloading, extracting, compiling, installing, configuring, starting and testing.

Saved in /opt/

## To run the script:

```
sudo apt-get update

sudo apt-get upgrade -y

sudo apt-get install -y git

git clone https://git.mif.vu.lt/luse0397/unix25task2.git

cd unix25task2

chmod +rwx lamp_install.sh

sudo ./lamp_install.sh
```