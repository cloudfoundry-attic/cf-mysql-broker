source 'https://rubygems.org'

ruby '~> 2.3'

gem 'rails', '~> 4.2'
gem 'rails-api'
gem 'jquery-rails'
gem 'settingslogic'
gem 'mysql2'
gem 'omniauth-uaa-oauth2', git: 'https://github.com/cloudfoundry/omniauth-uaa-oauth2'
gem 'nats'
gem 'sass-rails'
gem 'eventmachine', '~> 1.0.7'

group :production do
  gem 'unicorn'
end

group :development, :test do
  gem 'test-unit'
  gem 'rspec-rails'
  gem 'database_cleaner'
  gem 'brakeman'
  gem 'pry'
  gem 'rb-readline'
end

group :test do
  gem 'codeclimate-test-reporter', require: nil
  gem 'webmock'
end
