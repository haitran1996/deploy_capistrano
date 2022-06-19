server '13.250.109.122', port: 22, roles: [:web, :app, :db], primary: true
set :application, "deploy_capistrano"
set :repo_url, "git@github.com:haitran1996/deploy_capistrano.gi"
set :stage, :staging
set :branch, :master
