#!/bin/bash

# <UDF name="ssuser" Label="New user" example="username" />
# <UDF name="sspassword" Label="New user password" example="Password" />
# <UDF name="sshkey" Label="User SSH Key" />

# <UDF name="hostname" Label="Hostname" example="examplehost" />
# <UDF name="fqdn" Label="Website (FQDN)" example="www.example.com" />

# <UDF name="db_name" Label="Create Database" default="" example="Create database" />
# <UDF name="db_user" Label="Database Username" default="" />
# <UDF name="db_password" Label="Database Password" />

# <UDF name="ufw_enable" Label="Enable Firewall?" oneOf="yes,no" default="yes" />
# <UDF name="setup_f2b" Label="Fail2ban with (mostly) default configuration" oneOf="yes,no" default="yes" />
# <UDF name="timezone" Label="TZ Database Timezone" default="America/Los_Angeles" example="America/Los_Angeles, America/Denver, America/Chicago, America/New_York" />
# <UDF name="port_in_udp" Label="Firewall UDP Ports IN" default="" example="comma, separated, list, (but typically left blank)" />
# <UDF name="port_in_tcp" Label="Firewall TCP Ports IN" default="22,80,443" example="22, 80, 443" />
# <UDF name="sshport" Label="Special Port for Firewall" default="22" example="22, 2222, 33333" />

# <UDF name="ssdebug" Label="Create install.log in home folder?" oneof="yes,no" default="no" example="yes" />

curl -o configure.sh -L https://raw.githubusercontent.com/mdrmike/LAMP-on-Ubuntu-20.04/master/lampon2004.sh 

source configure.sh