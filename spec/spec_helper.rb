require "bundler/setup"
require "active_support/core_ext/numeric/time"
require "active_support/core_ext/time/zones"
require "form_duration_tracker"
require "timecop"

Time.zone = "UTC"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"

  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.after(:each) do
    Timecop.return
  end
end
