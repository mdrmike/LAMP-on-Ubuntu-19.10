
**Prerequisites/Credit**
##
This is an Ubuntu 20.04 StackScript, based (loosely) on https://github.com/machieajones/LAMP-on-Ubuntu-19.10 (itself is based on https://github.com/hmorris3293/Lamp-on-Ubuntu-18.04LTS/).

- [ ] @TODO: Add ubutnu lockdown similiar to: https://cloud.linode.com/stackscripts/612220
  - [ ] Add SSH key login
  - [ ] root password and SSH access disabled
  - [ ] timezone configuration
  - [ ] Fail2Ban (default configuration)
  - [ ] UFW (allow incoming on port 22) based on: https://gist.github.com/mdrmike/fa10238831915a988298
- [ ] @TODO: Lockdown MySQL
- [ ] @TODO: Add option for Apache PHP-FPM
  - [ ] FPM: unique per-site process users, similar to this example (search for heading): [Create New PHP-FPM Pool with different user](https://www.cloudbooklet.com/how-to-install-php-fpm-with-apache-on-ubuntu-18-04-google-cloud/)
