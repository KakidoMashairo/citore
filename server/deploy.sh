#!/bin/sh

cd ../
git pull
cd ./server/
bundle install
RAILS_ENV=production rails db:migrate
RAILS_ENV=production rails assets:clean
RAILS_ENV=production rails assets:precompile
whenever --update-crontab
spring stop
kill -9 `cat tmp/pids/server.pid`
SECRET_KEY_BASE=$(rake secret) rails server -e production -p 3100 -d
kill -9 `cat tmp/pids/sidekiq.pid`
RAILS_ENV=production bundle exec sidekiq -C config/sidekiq.yml
cd ./streaming/
npm install
forever restart index.js
cd ../