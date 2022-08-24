#! /usr/bin/env bash

set -e

echo "Deployment of a MISP development environment..."

# Database configuration
DBHOST='localhost'
DBNAME='misp'
DBUSER_ADMIN='root'
DBPASSWORD_ADMIN="$(openssl rand -hex 32)"
DBUSER_MISP='misp'
DBPASSWORD_MISP="$(openssl rand -hex 32)"

# Webserver configuration
PATH_TO_MISP='/var/www/MISP'
MISP_BASEURL='http://127.0.0.1:5000'
MISP_LIVE='1'
FQDN='localhost'

# Supervisor config
SUPERVISOR_PASSWORD="$(openssl rand -hex 32)"

# OpenSSL configuration
OPENSSL_C='LU'
OPENSSL_ST='State'
OPENSSL_L='Location'
OPENSSL_O='Organization'
OPENSSL_OU='Organizational Unit'
OPENSSL_CN='Common Name'
OPENSSL_EMAILADDRESS='info@localhost'

# GPG configuration
GPG_REAL_NAME='developer'
GPG_EMAIL_ADDRESS='info@localhost'
GPG_KEY_LENGTH='2048'
GPG_PASSPHRASE=''

# Sane PHP defaults
PHP_VERSION=7.4
upload_max_filesize=50M
post_max_size=50M
max_execution_time=300
max_input_time=223
memory_limit=512M
PHP_INI=/etc/php/${PHP_VERSION}/apache2/php.ini

export DEBIAN_FRONTEND=noninteractive
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
locale-gen en_US.UTF-8
dpkg-reconfigure locales


echo "--- Installing MISP… ---"
echo "--- Updating packages list ---"
apt update && apt upgrade -y


echo "--- Install base packages… ---"
apt-get -y install \
  curl \
  composer \
  acl \
  cmake \
  libcaca-dev \
  liblua5.3-dev \
  net-tools \
  ifupdown \
  gcc \
  git \
  gnupg-agent \
  pkg-config \
  make \
  python3 \
  python3-dev \
  python3-venv \
  python3-zmq \
  python3-testresources \
  python3-magic \
  openssl \
  redis-server \
  sudo \
  vim \
  zip \
  unzip \
  libfuzzy-dev \
  sqlite3 \
  moreutils \
  libxml2-dev \
  libxslt1-dev \
  zlib1g-dev \
  libpq5 \
  libjpeg-dev \
  tesseract-ocr \
  libpoppler-cpp-dev \
  imagemagick \
  libopencv-dev \
  zbar-tools \
  libzbar0 \
  libzbar-dev \
  ssdeep \
  clamav


echo "--- Installing and configuring Postfix… ---"
# # Postfix Configuration: Satellite system
# # change the relay server later with:
# postconf -e 'relayhost = example.com'
# postfix reload
echo "postfix postfix/mailname string `hostname`.misp.local" | debconf-set-selections
echo "postfix postfix/main_mailer_type string 'Satellite system'" | debconf-set-selections
apt-get install -y postfix


echo "--- Installing MariaDB specific packages and settings… ---"
apt-get install -y mariadb-client mariadb-server
# Secure the MariaDB installation (especially by setting a strong root password)
sleep 10 # give some time to the DB to launch...
systemctl restart mariadb.service
apt-get install -y expect
expect -f - <<-EOF
  set timeout 10
  spawn mysql_secure_installation
  expect "Enter current password for root (enter for none):"
  send -- "\r"
  expect "Set root password?"
  send -- "y\r"
  expect "New password:"
  send -- "${DBPASSWORD_ADMIN}\r"
  expect "Re-enter new password:"
  send -- "${DBPASSWORD_ADMIN}\r"
  expect "Remove anonymous users?"
  send -- "y\r"
  expect "Disallow root login remotely?"
  send -- "y\r"
  expect "Remove test database and access to it?"
  send -- "y\r"
  expect "Reload privilege tables now?"
  send -- "y\r"
  expect eof
EOF
apt-get purge -y expect

echo
echo "--- Installing Apache2… ---"
apt-get install -y apache2 apache2-doc apache2-utils
a2dismod status
a2enmod ssl
a2enmod rewrite
a2enmod headers
a2dissite 000-default
a2ensite default-ssl

echo "--- Installing PHP-specific packages… ---"
apt-get install -y \
  libapache2-mod-php7.4 \
  php7.4 \
  php7.4-cli \
  php7.4-gnupg \
  php7.4-dev \
  php7.4-json \
  php7.4-mysql \
  php7.4-opcache \
  php7.4-readline \
  php7.4-redis \
  php7.4-xml \
  php7.4-mbstring \
  php7.4-gd \
  php7.4-intl \
  php7.4-zip \
  php-apcu \
  php7.4-bcmath

test -f /usr/lib/libfuzzy.a || ln -s /usr/lib/x86_64-linux-gnu/libfuzzy.a /usr/lib/libfuzzy.a
test -f /usr/lib/libfuzzy.so || ln -s /usr/lib/x86_64-linux-gnu/libfuzzy.so /usr/lib/libfuzzy.so
test -f /usr/lib/libfuzzy.so.2 || ln -s /usr/lib/x86_64-linux-gnu/libfuzzy.so.2 /usr/lib/libfuzzy.so.2
test -f /usr/lib/libfuzzy.so.2.1.0 || ln -s /usr/lib/x86_64-linux-gnu/libfuzzy.so.2.1.0 /usr/lib/libfuzzy.so.2.1.0
pecl install ssdeep || pecl upgrade ssdeep
echo "extension=ssdeep.so" > /etc/php/7.4/mods-available/ssdeep.ini
sudo phpenmod ssdeep

echo -e "\n--- Configuring PHP (sane PHP defaults)… ---\n"
for key in upload_max_filesize post_max_size max_execution_time max_input_time memory_limit
do
 sed -i "s/^\($key\).*/\1 = $(eval echo \${$key})/" $PHP_INI
done


echo "--- Restarting Apache… ---"
systemctl restart apache2

chown www-data:www-data $PATH_TO_MISP
cd $PATH_TO_MISP

#sudo -u www-data -H git checkout tags/$(git describe --tags `git rev-list --tags --max-count=1`)
sudo -u www-data -H git config core.filemode false
# chown -R www-data $PATH_TO_MISP
# chgrp -R www-data $PATH_TO_MISP
# chmod -R 700 $PATH_TO_MISP


echo "--- Retrieving CakePHP… ---"
# CakePHP is included as a submodule of MISP, execute the following commands to let git fetch it:
# Once done, install CakeResque along with its dependencies if you intend to use the built in background jobs:
cd $PATH_TO_MISP/app
sudo -u www-data -H php composer.phar require kamisama/cake-resque:4.1.2
sudo -u www-data -H php composer.phar config vendor-dir Vendor
sudo -u www-data -H php composer.phar install
# Enable CakeResque with php-redis
phpenmod redis
# To use the scheduler worker for scheduled tasks, do the following:
sudo -u www-data -H cp -fa $PATH_TO_MISP/INSTALL/setup/config.php $PATH_TO_MISP/app/Plugin/CakeResque/Config/config.php


echo "--- Setting the permissions… ---"
chown -R www-data:www-data $PATH_TO_MISP
chmod -R 750 $PATH_TO_MISP
chmod -R g+ws $PATH_TO_MISP/app/tmp
chmod -R g+ws $PATH_TO_MISP/app/files
chmod -R g+ws $PATH_TO_MISP/app/files/scripts/tmp


echo "--- Creating a database user… ---"
mysql -u $DBUSER_ADMIN -p$DBPASSWORD_ADMIN -e "create database if not exists $DBNAME;"
mysql -u $DBUSER_ADMIN -p$DBPASSWORD_ADMIN -e "grant usage on *.* to $DBNAME@localhost identified by '$DBPASSWORD_MISP';"
mysql -u $DBUSER_ADMIN -p$DBPASSWORD_ADMIN -e "grant all privileges on $DBNAME.* to '$DBUSER_MISP'@'localhost';"
mysql -u $DBUSER_ADMIN -p$DBPASSWORD_ADMIN -e "flush privileges;"
# Import the empty MISP database from MYSQL.sql
sudo -u www-data -H mysql -u $DBUSER_MISP -p$DBPASSWORD_MISP $DBNAME < /var/www/MISP/INSTALL/MYSQL.sql


echo "--- Configuring Apache… ---"
# !!! apache.24.misp.ssl seems to be missing
#cp $PATH_TO_MISP/INSTALL/apache.24.misp.ssl /etc/apache2/sites-available/misp-ssl.conf
# If a valid SSL certificate is not already created for the server, create a self-signed certificate:
openssl req -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=$OPENSSL_C/ST=$OPENSSL_ST/L=$OPENSSL_L/O=<$OPENSSL_O/OU=$OPENSSL_OU/CN=$OPENSSL_CN/emailAddress=$OPENSSL_EMAILADDRESS" -keyout /etc/ssl/private/misp.local.key -out /etc/ssl/private/misp.local.crt


echo "--- Add a VirtualHost for MISP ---"
cat > /etc/apache2/sites-available/misp-ssl.conf <<EOF
<VirtualHost *:80>
    ServerAdmin admin@misp.local
    ServerName misp.local
    DocumentRoot $PATH_TO_MISP/app/webroot

    <Directory $PATH_TO_MISP/app/webroot>
        Options -Indexes
        AllowOverride all
        Require all granted
    </Directory>

    LogLevel warn
    ErrorLog /var/log/apache2/misp.local_error.log
    CustomLog /var/log/apache2/misp.local_access.log combined
    ServerSignature Off
</VirtualHost>
EOF
# activate new vhost
a2dissite default-ssl
a2ensite misp-ssl


echo "--- Restarting Apache… ---"
systemctl restart apache2


echo "--- Configuring log rotation… ---"
cp $PATH_TO_MISP/INSTALL/misp.logrotate /etc/logrotate.d/misp


echo "--- MISP configuration… ---"
# There are 4 sample configuration files in /var/www/MISP/app/Config that need to be copied
sudo -u www-data -H cp -a $PATH_TO_MISP/app/Config/bootstrap.default.php /var/www/MISP/app/Config/bootstrap.php
sudo -u www-data -H cp -a $PATH_TO_MISP/app/Config/database.default.php /var/www/MISP/app/Config/database.php
sudo -u www-data -H cp -a $PATH_TO_MISP/app/Config/core.default.php /var/www/MISP/app/Config/core.php
sudo -u www-data -H cp -a $PATH_TO_MISP/app/Config/config.default.php /var/www/MISP/app/Config/config.php
sudo -u www-data -H cat > $PATH_TO_MISP/app/Config/database.php <<EOF
<?php
class DATABASE_CONFIG {
        public \$default = array(
                'datasource' => 'Database/Mysql',
                //'datasource' => 'Database/Postgres',
                'persistent' => false,
                'host' => '$DBHOST',
                'login' => '$DBUSER_MISP',
                'port' => 3306, // MySQL & MariaDB
                //'port' => 5432, // PostgreSQL
                'password' => '$DBPASSWORD_MISP',
                'database' => '$DBNAME',
                'prefix' => '',
                'encoding' => 'utf8',
        );
}
EOF
# and make sure the file permissions are still OK
chown -R www-data:www-data $PATH_TO_MISP/app/Config
chmod -R 750 $PATH_TO_MISP/app/Config
# Set some MISP directives with the command line tool
$PATH_TO_MISP/app/Console/cake Baseurl $MISP_BASEURL
$PATH_TO_MISP/app/Console/cake Live $MISP_LIVE


echo "--- Generating a GPG encryption key… ---"
apt-get install -y rng-tools haveged
mkdir -p /opt/misp/.gnupg
chown -R www-data /opt/misp
chmod 700 /opt/misp/.gnupg
cat >gen-key-script <<EOF
    %echo Generating a default key
    Key-Type: default
    Key-Length: $GPG_KEY_LENGTH
    Subkey-Type: default
    Name-Real: $GPG_REAL_NAME
    Name-Comment: no comment
    Name-Email: $GPG_EMAIL_ADDRESS
    Expire-Date: 0
    Passphrase: '$GPG_PASSPHRASE'
    # Do a commit here, so that we can later print "done"
    %commit
    %echo done
EOF
sudo -u www-data -H gpg --list-keys $GPG_EMAIL_ADDRESS || sudo -u www-data -H gpg --homedir /opt/misp/.gnupg --batch --gen-key gen-key-script
rm gen-key-script
# And export the public key to the webroot
gpg --homedir $PATH_TO_MISP/.gnupg --export --armor $GPG_EMAIL_ADDRESS > $PATH_TO_MISP/app/webroot/gpg.asc


echo "--- Installing supervisord and workers… ---"
apt install supervisor
cd $PATH_TO_MISP/app
sudo -u www-data php composer.phar --with-all-dependencies require supervisorphp/supervisor \
    guzzlehttp/guzzle \
    php-http/message  \
    lstrojny/fxmlrpc
cat > /etc/supervisor/supervisord.conf << EOF
; supervisor config file

[unix_http_server]
file=/var/run/supervisor.sock   ; (the path to the socket file)
chmod=0700                       ; sockef file mode (default 0700)

[supervisord]
logfile=/var/log/supervisor/supervisord.log ; (main log file;default $CWD/supervisord.log)
pidfile=/var/run/supervisord.pid ; (supervisord pidfile;default supervisord.pid)
childlogdir=/var/log/supervisor            ; ('AUTO' child log dir, default $TEMP)

; the below section must remain in the config file for RPC
; (supervisorctl/web interface) to work, additional interfaces may be
; added by defining them in separate rpcinterface: sections
[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///var/run/supervisor.sock ; use a unix:// URL  for a unix socket

; The [include] section can just contain the "files" setting.  This
; setting can list multiple files (separated by whitespace or
; newlines).  It can also contain wildcards.  The filenames are
; interpreted as relative to this file.  Included files *cannot*
; include files themselves.

[include]
files = /etc/supervisor/conf.d/*.conf

[inet_http_server]
port=127.0.0.1:9001
username=supervisor
password=$SUPERVISOR_PASSWORD
EOF

cat > /etc/supervisor/conf.d/misp-workers.conf << EOF
[group:misp-workers]
programs=default,email,cache,prio,update

[program:default]
directory=$PATH_TO_MISP
command=$PATH_TO_MISP/app/Console/cake start_worker default
process_name=%(program_name)s_%(process_num)02d
numprocs=5
autostart=true
autorestart=true
redirect_stderr=false
stderr_logfile=$PATH_TO_MISP/app/tmp/logs/misp-workers-errors.log
stdout_logfile=$PATH_TO_MISP/app/tmp/logs/misp-workers.log
directory=$PATH_TO_MISP
user=www-data

[program:prio]
directory=$PATH_TO_MISP
command=$PATH_TO_MISP/app/Console/cake start_worker prio
process_name=%(program_name)s_%(process_num)02d
numprocs=5
autostart=true
autorestart=true
redirect_stderr=false
stderr_logfile=$PATH_TO_MISP/app/tmp/logs/misp-workers-errors.log
stdout_logfile=$PATH_TO_MISP/app/tmp/logs/misp-workers.log
directory=$PATH_TO_MISP
user=www-data

[program:email]
directory=$PATH_TO_MISP
command=$PATH_TO_MISP/app/Console/cake start_worker email
process_name=%(program_name)s_%(process_num)02d
numprocs=5
autostart=true
autorestart=true
redirect_stderr=false
stderr_logfile=$PATH_TO_MISP/app/tmp/logs/misp-workers-errors.log
stdout_logfile=$PATH_TO_MISP/app/tmp/logs/misp-workers.log
directory=$PATH_TO_MISP
user=www-data

[program:update]
directory=$PATH_TO_MISP
command=$PATH_TO_MISP/app/Console/cake start_worker update
process_name=%(program_name)s_%(process_num)02d
numprocs=1
autostart=true
autorestart=true
redirect_stderr=false
stderr_logfile=$PATH_TO_MISP/app/tmp/logs/misp-workers-errors.log
stdout_logfile=$PATH_TO_MISP/app/tmp/logs/misp-workers.log
directory=$PATH_TO_MISP
user=www-data

[program:cache]
directory=$PATH_TO_MISP
command=$PATH_TO_MISP/app/Console/cake start_worker cache
process_name=%(program_name)s_%(process_num)02d
numprocs=5
autostart=true
autorestart=true
redirect_stderr=false
stderr_logfile=$PATH_TO_MISP/app/tmp/logs/misp-workers-errors.log
stdout_logfile=$PATH_TO_MISP/app/tmp/logs/misp-workers.log
user=www-data
EOF
systemctl restart supervisor && systemctl enable supervisor

echo "--- Creating python venv ---"
[ -e /usr/local/lib/misp-venv/bin/activate ] || python3 -m venv --system-site-packages /usr/local/lib/misp-venv
sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "MISP.python_bin" "/usr/local/lib/misp-venv/bin/python"
source /usr/local/lib/misp-venv/bin/activate
pip install --upgrade pip setuptools wheel
pip install plyara>=2.0.2 pydeep pillow mattermostdriver


echo "--- Installing Mitre's STIX… ---"
SCRIPTS_PATH=$PATH_TO_MISP/app/files/scripts
cd $SCRIPTS_PATH
cd $SCRIPTS_PATH/python-cybox
pip install .
cd $SCRIPTS_PATH/python-stix
pip install .
cd $SCRIPTS_PATH/mixbox
pip install .


echo "--- Installing MISP modules… ---"
cd /usr/local/src/
[ -e /usr/local/src/misp-modules/.git ] || git clone https://github.com/MISP/misp-modules.git
cd misp-modules
pip install -r REQUIREMENTS
pip install .
sudo cat > /etc/systemd/system/misp-modules.service  <<EOF
[Unit]
Description=Start the misp modules server at boot
After=network.target

[Service]
User=www-data
WorkingDirectory=/usr/local/src/misp-modules
Environment="PATH=/usr/local/lib/misp-venv/bin"
ExecStart=/usr/local/lib/misp-venv/bin/misp-modules -l 127.0.0.1

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable misp-modules.service
sudo systemctl restart misp-modules.service

deactivate

echo "--- Restarting Apache… ---"
systemctl restart apache2
# TODO: Is it possible to ping MISP. Sleep is not a good option
sleep 5


echo "--- Updating… ---"
sudo -E $PATH_TO_MISP/app/Console/cake userInit -q
sudo -u www-data /var/www/MISP/app/Console/cake Admin runUpdates
echo "MySQL:  $DBUSER_ADMIN/$DBPASSWORD_ADMIN - $DBUSER_MISP/$DBPASSWORD_MISP"
AUTH_KEY=$(mysql -u $DBUSER_MISP -p $DBPASSWORD_MISP misp -e "SELECT authkey FROM users;" | tail -1)
echo "--- Updating the galaxies… ---"
curl --header "Authorization: $AUTH_KEY" --header "Accept: application/json" --header "Content-Type: application/json" -o /dev/null -s -X POST http://127.0.0.1/galaxies/update

echo "--- Updating the taxonomies… ---"
curl --header "Authorization: $AUTH_KEY" --header "Accept: application/json" --header "Content-Type: application/json" -o /dev/null -s -X POST http://127.0.0.1/taxonomies/update

echo "--- Updating the warning lists… ---"
curl --header "Authorization: $AUTH_KEY" --header "Accept: application/json" --header "Content-Type: application/json" -o /dev/null -s -X POST http://127.0.0.1/warninglists/update

echo "--- Updating the object templates… ---"
curl --header "Authorization: $AUTH_KEY" --header "Accept: application/json" --header "Content-Type: application/json" -o /dev/null -s -X  POST http://127.0.0.1/objectTemplates/update


echo "--- MISP is ready ---"
echo "Login and passwords for the MISP image are the following:"
echo "Web interface (default network settings): $MISP_BASEURL"
echo "MISP admin:  admin@admin.test/admin"
echo "Shell/SSH: misp/Password1234"
echo "Supervisor password: $SUPERVISOR_PASSWORD"
echo "MySQL:  $DBUSER_ADMIN/$DBPASSWORD_ADMIN - $DBUSER_MISP/$DBPASSWORD_MISP"
