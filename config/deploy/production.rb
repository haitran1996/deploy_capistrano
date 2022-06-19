server 'mysite.com', port: 22, roles: [:web, :app, :db], primary: true
set :application, "mysite"
set :repo_url, "git@github.com:me/mysite.git"
set :stage, :production
