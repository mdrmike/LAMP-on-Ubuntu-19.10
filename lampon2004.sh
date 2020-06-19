#!/bin/bash


if [ "${SSDEBUG,,}" = "yes" ]; then
  # CREATE LOGFILE, 
  #   based on https://askubuntu.com/a/1001404/139249
  exec   > >(tee -ia /root/install.log)
  exec  2> >(tee -ia /root/install.log >& 2)
  exec 19> /root/install.log
  export BASH_XTRACEFD="19"
  set -x
fi

[ "${SSH_CFGFILE}" = "" ] && SSH_CFGFILE="stackscript.conf"                     # Set default for ssh_configfile


## Harden SSH
function harden_ssh() {
  local _port="${1}"                                                            # Capture port from $1
  [ "${_port}" = "" ] && _port="22"                                             # Set to default 22 if alternate port wasn't set in stackscript
  cat > "/etc/ssh/sshd_config.d/${SSH_CFGFILE}" <<EOL
  Port ${_port}
  AddressFamily inet
  PasswordAuthentication no
  AllowTcpForwarding no
  X11Forwarding no
  PermitRootLogin no
  DenyUsers root
  AllowUsers ${SSUSER}
EOL
sshd -t || exit $?                                                              # Test config if fails, exit function
# systemctl restart sshd
}


harden_ssh "${SSHPORT}"


# INSTALL UPDATES
apt-get -y update
apt-get -y upgrade 
apt-get -y autoremove


# SET HOSTNAME	
# Configure hostname and configure entry to /etc/hosts
IPADDR=`hostname -I | awk '{ print $1 }'`
echo -e "\n# The following was added via Linode StackScript" >> /etc/hosts
# Set FQDN and HOSTNAME if they aren't defined
[ "$FQDN" = "" ] && FQDN=`dnsdomainname -A | cut -d' ' -f1`
[ "$HOST" = "" ] && HOSTNAME=`echo $FQDN | cut -d'.' -f1` || HOSTNAME="$HOST"

echo -e "$IPADDR\t$FQDN $HOSTNAME" >> /etc/hosts
hostnamectl set-hostname "$HOSTNAME"

if [ -n "$TIMEZONE" ]; then
  # Configure timezone
  timedatectl set-timezone "$TIMEZONE"
fi

#INSTALL APACHE
apt-get -y install apache2

# EDIT APACHE CONFIG
sed -ie "s/KeepAlive Off/KeepAlive On/g" /etc/apache2/apache2.conf

# COPY CONFIG TO NEW SITE:                                                      @TODO this is horrible. Use Apache tools so things work as expected.
cp /etc/apache2/sites-available/000-default.conf "/etc/apache2/sites-available/$FQDN.conf"

# CONFIGURE VHOST
cat > /etc/apache2/sites-available/$FQDN.conf <<EOL
<Directory /var/www/html/$FQDN/web>
    Require all granted
    AllowOverride All
    Allow from All
</Directory>
<VirtualHost *:80>
        ServerName $FQDN
        ServerAlias www.$FQDN
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html/$FQDN/web
        ErrorLog /var/www/html/$FQDN/logs/error.log
        CustomLog /var/www/html/$FQDN/logs/access.log combined
</VirtualHost>
EOL

mkdir -p /var/www/html/$FQDN/{web,logs}

cat > /var/www/html/$FQDN/web/index.php <<EOL
<html>
  <head>
   <title>Stackscript: Ubuntu 20.04 LAMP successfully installed.</title>
  </head>
  <body>
    <h2>Ubuntu 20.04 LAMP Installed: `date "+%m-%d-%y %r (%Z)"`</h2>
    <?php phpinfo(); ?> 
  </body>
</html>
EOL

rm /var/www/html/index.html

# Add Drupal permissions reset tool
curl -o /opt/scripts/fix-permissions.sh -L https://raw.githubusercontent.com/mdrmike/LAMP-on-Ubuntu-20.04/master/scripts/fix-permissions.sh 
sed -i "s|DefaultPath=\"\"|DefaultPath=\"/var/www/html/$FQDN/web\"|g" /opt/scripts/fix-permissions.sh
sed -i "s|DefaultUser=\"\"|DefaultUser=\"${SSUSER}\"|g" /opt/scripts/fix-permissions.sh
chmod 0440 /opt/scripts/fix-permissions.sh                                                           # allow script to be executed
ln -s /opt/scripts/fix-permissions.sh  /usr/local/bin/
tee > /etc/sudoers.d/fix-permissions <<EOL
${SSUSER} ALL = (root) NOPASSWD: /usr/local/bin/fix-permissions.sh
EOL


# Link your virtual host file from the sites-available directory to the sites-enabled directory:
sudo a2ensite $FQDN.conf

#Disable the default virtual host to minimize security risks:
a2dissite 000-default.conf

# restart apache
systemctl reload apache2
systemctl restart apache2

# Install MySQL Server in a Non-Interactive mode. Default root password will be "root"
# echo "mysql-server mysql-server/root_password password $DB_PASSWORD" | sudo debconf-set-selections
# echo "mysql-server mysql-server/root_password_again password $DB_PASSWORD" | sudo debconf-set-selections
apt-get -y install mysql-server

# mysql --host localhost -u$SQLuser -p$SQLpwd
# create database ${DB_NAME};
# create user ${DB_USER};
# GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, LOCK TABLES, CREATE TEMPORARY TABLES ON ${DB_NAME}.* TO ${DB_USER}@localhost IDENTIFIED BY ${DB_PASSWORD};
# exit
# 
# 
# 
# 
# mysql -u${DB_USER} -p$DB_PASSWORD -e "create database $DB_NAME"

mysql -uroot -e "CREATE DATABASE ${DB_NAME} /*\!40100 DEFAULT CHARACTER SET utf8 */;"
mysql -uroot -e "CREATE USER ${DB_USER}@localhost IDENTIFIED BY '${DB_PASSWORD}';"
#mysql -uroot -e "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, LOCK TABLES, CREATE TEMPORARY TABLES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
mysql -uroot -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
mysql -uroot -e "FLUSH PRIVILEGES;"

service mysql restart
 
#installing php
apt-get -y install php libapache2-mod-php php-mysql 
apt-get -y install php-curl php-db php-dom php-gd php-json php-tokenizer php-pear php-xml php-mbstring #drupal requirements

# adjust dir.conf to look for index.php 1st
sed -ie "s/DirectoryIndex index.html index.cgi index.pl index.php index.xhtml indem/DirectoryIndex index.php index.html index.htm/g" /etc/apache2/mods-enabled/dir.conf

# customize php
sed -i "s|error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT|error_reporting = E_COMPILE_ERROR \| E_RECOVERABLE_ERROR \| E_ERROR \| E_CORE_ERROR|g" /etc/php/7.4/apache2/php.ini
sed -i "s|max_input_time = 60|max_input_time = 30|g" /etc/php/7.4/apache2/php.ini
sed -i "s|post_max_size = 2M|post_max_size = 8M|g" /etc/php/7.4/apache2/php.ini
sed -i "s|upload_max_filesize = 2M|upload_max_filesize = 8M|g" /etc/php/7.4/apache2/php.ini
sed -i "s|max_input_time = 60|max_input_time = 30|g" /etc/php/7.4/apache2/php.ini

sed -i "s|;error_log = php_errors\.log|error_log = /var/log/php/error\.log|g" /etc/php/7.4/apache2/php.ini

# making directory for php? giving apache permissions to that log? restarting php
mkdir /var/log/php
chown www-data /var/log/php


# Unattended security updates
if [ "${SSUU,,}" = "yes" ]; then
  apt-get -y install unattended-upgrades
  # Based loosely on https://help.ubuntu.com/community/AutomaticSecurityUpdates
  # and 
  
  # It seems ubuntu 20.04 installs unattended-upgrades automatically, and 
  # echo '
  # // This is normally a much bigger file with multiple commented lines, this has been generated via a script so only includes what we need. If you need more options read the MAN page
  # Unattended-Upgrade::Allowed-Origins {
  # 	"${distro_id}:${distro_codename}-security";
  # 	"${distro_id}ESM:${distro_codename}";
  # };
  # ' > /etc/apt/apt.conf.d/50unattended-upgrades
  cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOL
  APT::Periodic::Update-Package-Lists "1";
  APT::Periodic::Unattended-Upgrade "1";

  // might just download non-security related updates, but doesn't install
  APT::Periodic::Download-Upgradeable-Packages "1";
  // Not needed for updates, but helps keep system clean/light. Always have backups
  APT::Periodic::AutocleanInterval "3";
EOL

fi



## Lockdown Firewall
# see list of ports: https://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers#Table_legend
# default OUT/UDP: 53,67,68,137,138/udp Allow outbound DNS,dhcp,dhcp,netbios(SAMBA),netbios(SAMBA)/udp 
# default OUT/TCP: 
# default  IN/UDP:
# default  IN/TCP:
if [ "$UFW_ENABLE" = "yes" ]; then
  apt-get -y install ufw
  ufw --force reset
  ufw default deny
  [ "${SSHPORT}" != "" ] && [ "$PORT_IN_TCP" != "" ] && PORT_IN_TCP="${PORT_IN_TCP},${SSHPORT}" || PORT_IN_TCP="${SSHPORT}" # ensure firewall allows ssh in
  [ -n "$PORT_OUT_UDP" ] && ufw allow out "$PORT_OUT_UDP/udp"                   # Test for variable &&  Then Set UFW
  [ -n "$PORT_OUT_TCP" ] && ufw allow out "$PORT_OUT_TCP/tcp"                   # Test for variable &&  Then Set UFW
  [ -n "$PORT_IN_UDP" ]  && ufw allow in "$PORT_IN_UDP/udp"                     # Test for variable &&  Then Set UFW
  [ -n "$PORT_IN_TCP" ]  && ufw allow in "$PORT_IN_TCP/tcp"                     # Test for variable &&  Then Set UFW
  [ -n "$PORT_OUT_TCP" ] || [ -n "$PORT_OUT_TCP" ] && ufw deny out to any
  ufw logging on
  ufw enable
  #ufw status verbose
fi

## Setup Fail2Ban 
if [ "$SETUP_F2B" = "yes" ]; then
    apt-get -y install fail2ban
    cp /etc/fail2ban/fail2ban.conf /etc/fail2ban/fail2ban.local
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    sed -ie "s/bantime.*10m/bantime  = 1h/g" /etc/fail2ban/jail.local 
    sed -ie "s/maxretry.*5/maxretry = 4/g" /etc/fail2ban/jail.local 
    systemctl start fail2ban
    systemctl enable fail2ban
fi


if [ "${SSZSH,,}" = "yes" ]; then
  apt-get -y install zsh
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 
  while [ ! -f "/root/.zshrc" ] || [ ! -d "/root/.oh-my-zsh" ]                      # wait until oh-my-zsh is installed
  do
    sleep 3 
  done
  sleep 3
  sed -i 's|ZSH_THEME=".*"|ZSH_THEME="rkj-repos"|g' ~/.zshrc
  sed -i 's|export ZSH=".*"|export ZSH="\$HOME/.oh-my-zsh"|g' ~/.zshrc
  mv .oh-my-zsh /etc/skel/
  mv .z* /etc/skel/
fi
if [ "$SSUSER" != "" ] && [ "$SSUSER" != "root" ]; then
  useradd -m "$SSUSER" -U --skel --groups sudo -s /bin/bash
  echo "$SSUSER:$SSPASSWORD" | chpasswd
  ln -s /var/www/html/$FQDN  "/home/$SSUSER/"
  chown "$SSUSER:www-data" "/var/www/html/$FQDN"
  chown "$SSUSER:www-data" "/var/www/html/$FQDN/web"
  chmod u+srwX,g=srX,o= "/var/www/html/$FQDN"
  chmod u+srwX,g=srX,o= "/var/www/html/$FQDN/web"

  # Disable root password
  passwd --lock root
  # ensure sudo is installed and configure secure user
  apt-get -y install sudo
  # configure ssh key for secure user
  SSHDIR="/home/$SSUSER/.ssh"
  mkdir $SSHDIR && echo "$SSHKEY" >> $SSHDIR/authorized_keys
  chmod -R 700 $SSHDIR && chmod 600 $SSHDIR/authorized_keys
  chown -R $SSUSER:$SSUSER $SSHDIR
fi

# Install Adminder for MYSQL
if [ "${SSADMINER,,}" = "yes" ]; then
  apt-get -y install adminer
  a2enconf adminer
  systemctl reload apache2
fi


# === this should be last in the file to esure full log is copied
cat /root/install.log > /home/$SSUSER/install.log
chown "$SSUSER:$SSUSER" /home/$SSUSER/install.log

## Disable Root Login
if [ "$SSDISABLEROOT" = " yes" ]; then
  passwd --lock root
fi

shutdown --reboot +1 
