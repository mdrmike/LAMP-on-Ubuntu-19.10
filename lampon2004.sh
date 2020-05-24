#!/bin/bash
## 
#<UDF name="ssuser" Label="New user" example="username" />
#<UDF name="sspassword" Label="New user password" example="Password" />
#<UDF name="hostname" Label="Hostname" example="examplehost" />
#<UDF name="website" Label="Website" example="example.com" />

# <UDF name="db_password" Label="MySQL root Password" />
# <UDF name="db_name" Label="Create Database" default="" example="Create database" />


# ADD SUDO USER
adduser $SSUSER --disabled-password --gecos "" && \
echo "$SSUSER:$SSPASSWORD" | chpasswd
adduser $SSUSER sudo

# UPDATES
apt -y update
apt -y upgrade 
apt -y autoremove

# SET HOSTNAME	
hostnamectl set-hostname $HOSTNAME
echo "127.0.0.1   $HOSTNAME" >> /etc/hosts

#INSTALL APACHE
apt -y install apache2

# EDIT APACHE CONFIG
sed -ie "s/KeepAlive Off/KeepAlive On/g" /etc/apache2/apache2.conf

# COPY CONFIG TO NEW SITE:                                                      @TODO this is horrible. Use Apache tools so things work as expected.
cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/$WEBSITE.conf

# CONFIGURE VHOST
cat <<END >/etc/apache2/sites-available/$WEBSITE.conf
<Directory /var/www/html/$WEBSITE/web>
    Require all granted
</Directory>
<VirtualHost *:80>
        ServerName $WEBSITE
        ServerAlias www.$WEBSITE
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html/$WEBSITE/web
        ErrorLog /var/www/html/$WEBSITE/logs/error.log
        CustomLog /var/www/html/$WEBSITE/logs/access.log combined
</VirtualHost>
END

mkdir -p /var/www/html/$WEBSITE/{web,logs}

cat > /var/www/html/$WEBSITE/web/index.php <<EOL
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
sudo a2ensite $WEBSITE.conf

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
