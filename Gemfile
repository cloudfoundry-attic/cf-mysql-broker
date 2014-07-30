source 'https://rubygems.org'

gem 'rails'
gem 'rails-api'
gem 'settingslogic'
gem 'mysql2'
gem 'omniauth-uaa-oauth2', github: 'cloudfoundry/omniauth-uaa-oauth2'
gem 'cf-registrar', git: 'https://github.com/cloudfoundry/cf-registrar'
gem 'nats'
gem 'sass-rails'

group :production do
  gem 'unicorn'
end

group :development, :test do
  gem 'rspec-rails'
  gem 'database_cleaner'
end

group :development do
  gem 'guard-rails'
  gem 'roodi'
end

group :test do
  gem 'codeclimate-test-reporter', require: nil
  gem 'webmock'
end
