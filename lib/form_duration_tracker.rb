# frozen_string_literal: true

require 'active_support/concern'
require 'active_support/core_ext/numeric/time'
require 'active_support/core_ext/string/inflections'
require 'form_duration_tracker/version'
require 'form_duration_tracker/controller_concern'
require 'form_duration_tracker/model_concern'

module FormDurationTracker
  class Error < StandardError; end
end

# Load generators if in Rails environment
require 'generators/form_duration_tracker/install/install_generator' if defined?(Rails)
