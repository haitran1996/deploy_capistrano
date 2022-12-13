# Deploy

## Config project

```ruby
# Gemfile

group :development do    
  gem 'capistrano',         require: false
  gem 'capistrano-rvm',     require: false
  gem 'capistrano-rails',   require: false
  gem 'capistrano-bundler', require: false
  gem 'capistrano3-puma',   require: false
end
```

Run

```bash
bundle install
cap install
cp config/enviroments/production.rb config/enviroments/staging.rb
```

```ruby
# Capfile
require "capistrano/rails"
# replace by 'capistrano/rails/migrations' if application is api app/not need to run assets:precompile

require "capistrano/bundler"
require "capistrano/rvm"
require 'capistrano/puma'
install_plugin Capistrano::Puma
install_plugin Capistrano::Puma::Nginx
```

```ruby
# config/deploy.rb

lock "~> 3.17.0"

set :user, 'deploy'
set :application, "mysite"
set :puma_threads,    [4, 16]
set :puma_workers,    0
set :keep_releases, 5

set :linked_files, %w(config/database.yml config/master.key)
set :linked_dirs, %w(log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system public/uploads)

set :pty,             true
set :use_sudo,        false
set :deploy_via,      :remote_cache
set :deploy_to,       "/var/www/#{fetch(:application)}"
set :puma_bind,       "unix://#{shared_path}/tmp/sockets/puma.sock"
set :puma_state,      "#{shared_path}/tmp/pids/puma.state"
set :puma_rackup,  -> {File.join(current_path, "config.ru")}
set :puma_pid,        "#{shared_path}/tmp/pids/puma.pid"
set :puma_conf,    -> {"#{shared_path}/puma.rb"}
set :puma_access_log, "#{release_path}/log/puma.access.log"
set :puma_error_log,  "#{release_path}/log/puma.error.log"
set :ssh_options,     { forward_agent: true, user: fetch(:user), keys: %w(~/.ssh/id_rsa.pub) }
# keys on local, paste it to authorized_keys on server
set :puma_preload_app, true
set :puma_worker_timeout, nil
set :puma_init_active_record, true  # Change to false when not using ActiveRecord
```

```ruby
# staging || production

server 'mysite.com', port: 22, roles: [:web, :app, :db], primary: true
set :repo_url, "git@github.com:me/mysite.git"
set :stage, :production
set :branch, :master
```

## Setting Amazon linux 2 server

```bash
sudo adduser deploy
sudo mkdir -p /home/deploy/.ssh
sudo chown -R deploy:deploy /home/deploy/.ssh/


sudo usermod -aG wheel deploy
sudo vi /etc/sudoers
## add this line to the file
%deploy ALL=(ALL) NOPASSWD: ALL
```

Switch to new user

```bash
sudo su - deploy
vi .ssh/authorized_keys
# paste your keys on ssh_options deploy to the file
sudo chmod 600 ~/.ssh/authorized_keys
```

Exit and ssh by `ssh deploy@<your_public_ip_sv>`

Install dependencies

```bash
#install yarn
curl --silent --location https://rpm.nodesource.com/setup_14.x | sudo bash -
sudo yum install nodejs
curl --silent --location https://dl.yarnpkg.com/rpm/yarn.repo | sudo tee /etc/yum.repos.d/yarn.repo
sudo rpm --import https://dl.yarnpkg.com/rpm/pubkey.gpg
sudo yum install yarn
yarn --version


#install rvm
yum install -y gcc openssl-devel libyaml-devel libffi-devel readline-devel zlib-devel gdbm-devel ncurses-devel ruby-devel gcc-c++ jq git
curl -sSL https://rvm.io/mpapis.asc | gpg2 --import -
curl -sSL https://get.rvm.io | bash -s stable --ruby
```

Change ruby version to project's ruby version

```bash
rvm install "ruby-3.0.1"
rvm use 3.0.1 --default
```

Install nginx

```bash
sudo amazon-linux-extras enable epel
sudo yum install epel-release
sudo yum install nginx
nginx -v

sudo systemctl start nginx
sudo systemctl enable nginx
```

Config nginx

`sudo vi /etc/nginx/conf.d/default.conf`

```
upstream puma {
   # Path to Puma SOCK file, as defined previously
   server unix:///var/www/boat-race/shared/tmp/sockets/puma.sock;
 }

 server {
   listen 80;
   root /home/rails/apps/mysite/current/public;#?
   access_log /home/rails/apps/mysite/current/log/nginx.access.log;#?
   error_log /home/rails/apps/mysite/current/log/nginx.error.log info? #?

   location ^~ /assets/ {
    gzip_static on;
    expires max;
    add_header Cache-Control public;
   }

   location / {
    try_files $uri @puma;
   }

   location @puma {
    proxy_pass http://puma;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_redirect off;

   }

   error_page 500 502 503 504 /500.html;
   client_max_body_size 100M;
   keepalive_timeout 10;
}
```

Restart nginx

```
nginx -t
sudo systemctl restart nginx
```

Install mysql

```bash
sudo yum install https://dev.mysql.com/get/mysql80-community-release-el7-5.noarch.rpm
sudo amazon-linux-extras install epel -y
sudo yum -y install mysql-community-server
sudo yum install mysql-devel
sudo systemctl enable --now mysqld
systemctl status mysqld
```

Config mysql

```bash
# get temp password root user (temppass: U>x)EC;L,2M?)
sudo grep 'temporary password' /var/log/mysqld.log


# create and grant all permission for user deploy mysql
mysql -u root -p
CREATE USER 'deploy'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON *.* TO 'sammy'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;

mysql -u deploy -p
create database <project_datatabse_name>;
exit;
```

Create shared file on server

```bash
ssh deploy@...
sudo mkdir -p /var/www/mysite
# back on your machine
cd mysite
scp config/master.key deploy@mysite.com:/var/www/mysite/shared/config
scp config/database.yml  deploy@mysite.com:/var/www/mysite/shared/config
```

Create puma service

```bash
# create puma service to create puma.sock file

[Unit]
Description=Puma HTTP Server for mysite (production)
After=network.target

[Service]
Type=simple
User=deploy
WorkingDirectory=/var/www/mysite/current
ExecStart=/home/deploy/.rvm/bin/rvm default do bundle exec puma -C /var/www/mysite/shared/puma.rb
ExecReload=/bin/kill -TSTP $MAINPID
StandardOutput=append:/var/www/mysite/current/log/puma.access.log
StandardError=append:/var/www/mysite/current/log/puma.error.log
Restart=always
RestartSec=1
SyslogIdentifier=puma

[Install]
WantedBy=multi-user.target
```

Start puma service (shared/tmp/sockets always exists for puma.socket file)

```
systemctl start puma_mysite_production
systemctl enable puma_mysite_production
systemctl status puma_mysite_production
```

open port 80 on instance ec2

```
- Go to the "Network & Security" -> Security Group settings in the left hand navigation
- Find the Security Group that your instance is apart of
- Click on Inbound Rules
- Click on Edit inbound rules
- Click on Add Rule
- Choose http/https 
  VD: http / TCP / 80 / Anywhere... ...
- Click Apply and enjoy
```

Setting git ssh on server

```bash
ssh-keygen -t rsa -C "myserver"
cat myserver.pub
# paste it to deploy keys on your project which you will deploy
```

Cap staging deploy

### Interesting

- Can run server by
  
  ```
  bundle exec puma -e staging -b unix:///var/www/deploy_capistrano/shared/tmp/sockets/puma.sock
  ```
  
  

## Errors

- Exception while executing on host 13.250.109.122: Authentication failed for user deploy@13.250.109.122 (SSHKit::Runner::ExecuteError)
  
  ```bash
  eval `ssh-agent -s`
  ssh-add(add ssh irsa key) # if authentication fail after run cap deploy
  ```

- An error occurred while installing mysql2 (0.5.4), and Bundler cannot continue
  
  ```bash
  sudo yum install mysql-devel
  ```
