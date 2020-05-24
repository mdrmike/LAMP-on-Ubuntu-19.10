#!/bin/bash

## 

#<UDF name="ssuser" Label="New user" example="username" />

#<UDF name="sspassword" Label="New user password" example="Password" />

#<UDF name="hostname" Label="Hostname" example="examplehost" />

#<UDF name="website" Label="Website" example="example.com" />

# <UDF name="db_password" Label="MySQL root Password" />

# <UDF name="db_name" Label="Create Database" default="" example="Create database" />

curl -o out.sh -L https://raw.githubusercontent.com/mdrmike/LAMP-on-Ubuntu-20.04/master/lampon2004.sh

. ./out.sh