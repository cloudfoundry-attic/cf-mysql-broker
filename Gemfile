source 'https://rubygems.org'

ruby '2.2.3'

gem 'rails', '4.0.13'
gem 'rails-api'
gem 'settingslogic'
gem 'mysql2'
gem 'omniauth-uaa-oauth2', github: 'cloudfoundry/omniauth-uaa-oauth2'
gem 'nats'
gem 'sass-rails'
gem 'eventmachine', '~> 1.0.7'

group :production do
  gem 'unicorn'
end

group :development, :test do
  gem 'test-unit'
  gem 'rspec-rails', '2.14.2'
  gem 'database_cleaner'
  gem 'brakeman'
end

group :test do
  gem 'codeclimate-test-reporter', require: nil
  gem 'webmock'
end
