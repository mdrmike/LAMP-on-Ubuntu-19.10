#!/bin/bash

if [ "${SSDEBUG,,}" == "yes" ]; then
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
  cat > /etc/ssh/sshd_config.d/$SSH_CFGFILE <<EOL
  Port ${_port}
  AddressFamily inet
  PasswordAuthentication no
  AllowTcpForwarding no
  X11Forwarding no
  PermitRootLogin no
  DenyUsers root
  AllowUsers ${newuser}
EOL
sshd -t || exit
# systemctl restart sshd
}


harden_ssh "${SSHPORT}"


# INSTALL UPDATES
apt -y update
apt -y upgrade 
apt -y autoremove

# SET HOSTNAME	
# Configure hostname and configure entry to /etc/hosts
IPADDR=`hostname -I | awk '{ print $1 }'`
echo -e "\n# The following was added via Linode StackScript" >> /etc/hosts
# Set FQDN and HOSTNAME if they aren't defined
[ "$FQDN" == "" ] && FQDN=`dnsdomainname -A | cut -d' ' -f1`
[ "$HOST" == "" ] && HOSTNAME=`echo $FQDN | cut -d'.' -f1` || HOSTNAME="$HOST"

echo -e "$IPADDR\t$FQDN $HOSTNAME" >> /etc/hosts
hostnamectl set-hostname "$HOSTNAME"

if [ -n "$TIMEZONE" ]; then
  # Configure timezone
  timedatectl set-timezone "$TIMEZONE"
fi

#INSTALL APACHE
apt -y install apache2

# EDIT APACHE CONFIG
sed -ie "s/KeepAlive Off/KeepAlive On/g" /etc/apache2/apache2.conf

# COPY CONFIG TO NEW SITE:                                                      @TODO this is horrible. Use Apache tools so things work as expected.
cp /etc/apache2/sites-available/000-default.conf "/etc/apache2/sites-available/$FQDN.conf"

# CONFIGURE VHOST
cat > /etc/apache2/sites-available/$FQDN.conf <<EOL
<Directory /var/www/html/$FQDN/web>
    Require all granted
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
    <h2>Stackscript: Ubuntu 20.04 LAMP successfully installed.</h2>
    <p>Testing PHP...</p><hr />
    <?php phpinfo(); ?> 
  </body>
</html>
EOL

rm /var/www/html/index.html

# Link your virtual host file from the sites-available directory to the sites-enabled directory:
sudo a2ensite $FQDN.conf

#Disable the default virtual host to minimize security risks:
a2dissite 000-default.conf

# restart apache
systemctl reload apache2
systemctl restart apache2

# Install MySQL Server in a Non-Interactive mode. Default root password will be "root"
echo "mysql-server mysql-server/root_password password $DB_PASSWORD" | sudo debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $DB_PASSWORD" | sudo debconf-set-selections
apt -y install mysql-server

mysql -uroot -p$DB_PASSWORD -e "create database $DB_NAME"

service mysql restart
 
#installing php
apt -y install php libapache2-mod-php php-mysql 

# adjust dir.conf to look for index.php 1st
sed -ie "s/DirectoryIndex index.html index.cgi index.pl index.php index.xhtml indem/DirectoryIndex index.php index.html index.htm/g" /etc/apache2/mods-enabled/dir.conf

# making directory for php? giving apache permissions to that log? restarting php
mkdir /var/log/php
chown www-data /var/log/php


## Lockdown Firewall
# see list of ports: https://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers#Table_legend
# default OUT/UDP: 53,67,68,137,138/udp Allow outbound DNS,dhcp,dhcp,netbios(SAMBA),netbios(SAMBA)/udp 
# default OUT/TCP: 
# default  IN/UDP:
# default  IN/TCP:
if [ "$UFW_ENABLE" == "yes" ]; then
  apt -y install ufw
  ufw --force reset
  ufw default deny
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
if [ "$SETUP_F2B" == "yes" ]; then
    apt install fail2ban -y
    cp /etc/fail2ban/fail2ban.conf /etc/fail2ban/fail2ban.local
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    sed -ie "s/bantime.*10m/bantime  = 1h/g" /etc/fail2ban/jail.local 
    sed -ie "s/maxretry.*5/maxretry = 4/g" /etc/fail2ban/jail.local 
    systemctl start fail2ban
    systemctl enable fail2ban
fi



if [ "$SSUSER" != "" ] && [ "$SSUSER" != "root" ]; then
  useradd -m "$SSUSER" -U --groups sudo -s /bin/bash
  echo "$SSUSER:$SSPASSWORD" | chpasswd
  ln -s /var/www  "/home/$SSUSER/"
  chown "$SSUSER:www-data" "/var/www/html/$FQDN"
  chown "$SSUSER:www-data" "/var/www/html/$FQDN/web"
  chmod u+srwX,g=srX,o= "/var/www/html/$FQDN"
  chmod u+srwX,g=srX,o= "/var/www/html/$FQDN/web"

  # Disable root password
  passwd --lock root
  # ensure sudo is installed and configure secure user
  apt -y install sudo
  # configure ssh key for secure user
  SSHDIR="/home/$SSUSER/.ssh"
  mkdir $SSHDIR && echo "$SSHKEY" >> $SSHDIR/authorized_keys
  chmod -R 700 $SSHDIR && chmod 600 $SSHDIR/authorized_keys
  chown -R $SSUSER:$SSUSER $SSHDIR
fi


# === this should be last in the file to esure full log is copied
cat /root/install.log > /home/$SSUSER/install.log
chown "$SSUSER:$SSUSER" /home/$SSUSER/install.log

