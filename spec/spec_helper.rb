require 'rails_helper'
require 'pry-rails'
require 'database_cleaner'
require 'webmock/rspec'

TEST_VAPID_PUBLIC_KEY = "BBj2BQJdncdLjKbnYqWue5KffyeGlidA1Bt1YBR8ecEn-IIwVVt1ybD61YWtEgNykbEAuJhMJENVLj1GDDu71V8".freeze
TEST_VAPID_PRIVATE_KEY = "sqqwmD4JEb9pjB29NHqwBOnj2bmQ_wyY-DmO9lO2XTk=".freeze

ScrabbleWithFriends.config do |config|
  config.web_push_vapid_public_key = TEST_VAPID_PUBLIC_KEY
  config.web_push_vapid_private_key = TEST_VAPID_PRIVATE_KEY
end

RSpec.configure do |config|

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.example_status_persistence_file_path = "spec/examples.txt"

  config.disable_monkey_patching!

  #if config.files_to_run.one?
  #  config.default_formatter = "doc"
  #end

  config.order = :random

  Kernel.srand(config.seed)

  config.before(:suite) do
    ### PERFORMS CLEAN IMMEDIATELY
    DatabaseCleaner.clean_with(:truncation)

    #DatabaseCleaner.strategy = :truncation, { except: [], pre_count: true }
    DatabaseCleaner.strategy = :transaction
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  config.before(:all) do

  end

  require 'rails-controller-testing'
  RSpec.configure do |config|
    [:controller, :view, :request].each do |type|
      config.include ::Rails::Controller::Testing::TestProcess, type: type
      config.include ::Rails::Controller::Testing::TemplateAssertions, :type => type
      config.include ::Rails::Controller::Testing::Integration, :type => type
    end
  end

end
