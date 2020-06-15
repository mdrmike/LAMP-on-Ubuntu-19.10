
## Prerequisites/Credit

This is an Ubuntu 20.04 StackScript, based (loosely) on https://github.com/machieajones/LAMP-on-Ubuntu-19.10 (itself is based on https://github.com/hmorris3293/Lamp-on-Ubuntu-18.04LTS/).

- [ ] @TODO: Add ubutnu lockdown similiar to: https://cloud.linode.com/stackscripts/612220
  - [x] ~~Add SSH key login~~ (included for root in default linode dashboard)
  - [ ] root password and SSH access disabled
  - [x] timezone configuration
  - [x] Fail2Ban (default configuration)
  - [x] UFW (allow incoming on port 22) based on https://gist.github.com/mdrmike/fa10238831915a988298
- [ ] @TODO: Lockdown MySQL
- [ ] @TODO: Add option for Apache PHP-FPM
  - [ ] FPM: unique per-site process users, similar to this example (search for heading): [Create New PHP-FPM Pool with different user](https://www.cloudbooklet.com/how-to-install-php-fpm-with-apache-on-ubuntu-18-04-google-cloud/)
- [ ] @TODO: Add [fsniper](https://github.com/l3ib/fsniper/) to monitor web file permissions
- [ ] @TODO: Look into web/user permissions based on this post https://web.archive.org/web/20180422200034/http://blog.netgusto.com/solving-web-file-permissions-problem-once-and-for-all/ (also worth a read, esp comments: https://www.digitalocean.com/community/questions/discussion-about-permissions-for-web-folders) ok, read this too: https://serverfault.com/questions/357108/what-permissions-should-my-website-files-folders-have-on-a-linux-webserver


## Post Installation Suggestions

- Use ZSH 
- Make `bash` more friendly: add [oh-my-bash](https://github.com/ohmybash/oh-my-bash). Though any system changes introduce security risks.
```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" && sed -i 's|OSH_THEME=".*"|OSH_THEME="powerline"|g' ~/.bashrc
```