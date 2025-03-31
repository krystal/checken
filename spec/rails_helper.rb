require "action_controller/railtie"
require 'rspec/rails'

ENV["RAILS_ENV"] ||= "test"

module TestApp
  class Application < Rails::Application
    config.eager_load = false
    config.secret_key_base = 'test_secret_key_base'
  end
end

test_app = TestApp::Application.new
Rails.application = test_app
Rails.application.configure do
  config.eager_load = false
  config.logger = Logger.new(nil)
end
test_app.initialize!

RSpec.configure do |config|
  config.include ActionController::TestCase::Behavior, type: :controller
  config.infer_base_class_for_anonymous_controllers = false
end


