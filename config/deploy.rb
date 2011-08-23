# -*- coding: utf-8 -*-

set :application, "ranking"
set :repository,  "git@github.com:timehub/ranking.git"
set :branch, "master"
set :scm, :git
set :scm_verbose, false
set :deploy_via, :checkout
set :rails_env, "production"
set :user, "elkin"

set :deploy_to, "/var/apps/#{application}"

set :global_shared_files, %w(config/database.yml)
set :rvm_ruby_string, '1.9.2-p180@ranking'
set :rvm_type, :user

set :use_sudo,  false
set :keep_releases, 30

role :web, "65.39.226.140"                   # Your HTTP server, Apache/etc
role :app, "65.39.226.140"                   # This may be the same as your `Web` server
role :db,  "65.39.226.140", :primary => true # This is where Rails migrations will run

ssh_options[:forward_agent] = true
default_run_options[:pty] = true



################################################################

namespace :passenger do
  desc "Restart Application"
  task :restart, :roles => :app do
    run "touch #{current_path}/tmp/restart.txt"
  end

  desc "Restart Application's Standalone passenger service"
  task :restart_standalone, :roles => :app do
    puts "Stopping passenger on port #{custom_passenger_port}"
    run "cd #{current_path} && passenger stop -p #{custom_passenger_port}"
    puts "Starting passenger on port #{custom_passenger_port}"
    run "cd #{current_path} && passenger start -a localhost -p #{custom_passenger_port} -e #{rails_env} -d"
  end

end

namespace :deploy do
  desc "Restart the Passenger system."
  task :restart, :roles => :app do
    passenger.restart
  end


  desc 'Symlink shared configs and folders on each release.'
  task :symlink_shared do
    global_shared_files.each do |shared_file|
      run "ln -nfs #{shared_path}/#{shared_file} #{release_path}/#{shared_file}"
    end
  end
end

after "deploy", "deploy:symlink_shared"
before "deploy:migrate", "deploy:symlink_shared"
after "deploy", "deploy:cleanup"

require 'bundler/capistrano'
$:.unshift(File.expand_path('./lib', ENV['rvm_path']))
require "rvm/capistrano"
