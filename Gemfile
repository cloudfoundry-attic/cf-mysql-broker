source 'https://rubygems.org'

gem 'rails', '~> 4.2.1'
gem 'rails-api'
gem 'settingslogic'
gem 'mysql2'
gem 'omniauth-uaa-oauth2', github: 'cloudfoundry/omniauth-uaa-oauth2'
# nats was pulling an old version of eventmachine which would not compile
gem 'eventmachine', '~> 1.0.3'
gem 'nats'
gem 'sass-rails'

group :production do
  gem 'unicorn'
end

group :development, :test do
  gem 'test-unit'
  gem 'rspec-rails'
  gem 'database_cleaner'
end

group :test do
  gem 'codeclimate-test-reporter', require: nil
  gem 'webmock'
end
