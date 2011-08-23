Ranking
========

Live rankings for the Rally on Rails. Sponsored by http://timehub.net.

Based on original script by lucasefe: https://gist.github.com/1148224

How to use
----------

`bundle`

On a cron task, run:

`bundle exec ruby ranking.rb update`

To start the server, run:

`bundle exec ruby ranking.rb`

Then make a Passenger Reverse Proxy to port 4567.