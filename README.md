# "Air Traffic Control"

DLST app for managing data flights to cloud storage.


**First-Time Setup (for developers)**
Clone the repository.
`git clone git@github.com:cul/atc.git`

Install gem dependencies.
`bundle install`

Set up config files.
`bundle exec rake atc:setup:config_files`

Run database migrations.
`bundle exec rake db:migrate`

Install Javascript dependencies.
`yarn`

Seed the database with necessary values for operation.
`rails db:seed`

Start the vite dev server.
`bin/vite dev`

Start the application using `rails server`.
`rails s -p 3000`