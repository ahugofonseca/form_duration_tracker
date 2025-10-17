# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/migration'
require 'rails/generators/active_record'

module FormDurationTracker
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      argument :model_name, type: :string, required: true
      argument :attribute_name, type: :string, default: 'started_at'

      class_option :index, type: :boolean, default: false, desc: 'Add database index'
      class_option :not_null, type: :boolean, default: false, desc: 'Add NOT NULL constraint'
      class_option :check_not_future, type: :boolean, default: false, desc: 'Add CHECK constraint to prevent future timestamps'
      class_option :skip_migration, type: :boolean, default: false, desc: 'Skip migration generation'
      class_option :skip_model, type: :boolean, default: false, desc: 'Skip model modification'
      class_option :skip_controller, type: :boolean, default: false, desc: 'Skip controller modification'
      class_option :skip_tests, type: :boolean, default: false, desc: 'Skip test file generation'

      class_option :controller_name, type: :string, desc: 'Controller name (default: ModelNameController)'
      class_option :expirable, type: :boolean, default: true, desc: 'Enable session expiration'
      class_option :expiry_time, type: :string, default: '2.hours', desc: 'Session expiry time (e.g., "2.hours", "30.minutes")'
      class_option :auto_initialize, type: :boolean, default: false, desc: 'Auto-initialize with before_action on :new'
      class_option :auto_params, type: :boolean, default: nil, desc: 'Auto-inject params (default: inferred from :on option)'
      class_option :auto_params_on, type: :array, desc: 'Explicit actions for auto-params injection'
      class_option :param_key, type: :string, desc: 'Custom params key (default: model name singularized)'

      class_option :prevent_future, type: :boolean, default: false, desc: 'Prevent future timestamps in model'
      class_option :prevent_update, type: :boolean, default: false, desc: 'Prevent updating timestamp after creation'
      class_option :validate_max_duration, type: :string, desc: 'Maximum form duration (e.g., "2.hours")'
      class_option :validate_min_duration, type: :string, desc: 'Minimum form duration (e.g., "5.seconds")'

      class_option :test_framework, type: :string, default: nil, desc: 'Test framework: rspec or minitest (auto-detected if not specified)'

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def validate_and_sync_time_options
        validate_time_consistency!
      end

      def create_migration_file
        return if options[:skip_migration]
        migration_template 'migration.rb.erb', "db/migrate/add_#{attribute_name}_to_#{table_name}.rb"
      end

      def inject_into_model
        return if options[:skip_model]

        model_file = "app/models/#{model_name.underscore}.rb"

        unless File.exist?(model_file)
          say_status :error, "Model file not found: #{model_file}", :red
          return
        end

        # Check if already included
        if File.read(model_file).include?('FormDurationTracker::ModelConcern')
          say_status :skip, "Model already includes FormDurationTracker::ModelConcern", :yellow
        else
          inject_into_class model_file, model_name.camelize do
            "  include FormDurationTracker::ModelConcern\n\n"
          end
        end

        # Add track_form_duration call
        model_config = build_model_config
        inject_into_class model_file, model_name.camelize do
          "  #{model_config}\n"
        end
      end

      def inject_into_controller
        return if options[:skip_controller]

        controller_file = "app/controllers/#{controller_path}.rb"

        unless File.exist?(controller_file)
          say_status :error, "Controller file not found: #{controller_file}", :red
          say_status :info, "You can specify controller with --controller-name option", :blue
          return
        end

        # Check if already included
        if File.read(controller_file).include?('FormDurationTracker::ControllerConcern')
          say_status :skip, "Controller already includes FormDurationTracker::ControllerConcern", :yellow
        else
          inject_into_class controller_file, controller_class_name do
            "  include FormDurationTracker::ControllerConcern\n\n"
          end
        end

        # Add track_form_duration call
        controller_config = build_controller_config
        inject_into_class controller_file, controller_class_name do
          "  #{controller_config}\n"
        end

        unless options[:auto_initialize] || auto_params_enabled?
          inject_controller_methods(controller_file)
        end
      end

      def create_test_files
        return if options[:skip_tests]

        case detected_test_framework
        when :rspec
          create_rspec_tests
        when :minitest
          create_minitest_tests
        else
          say_status :skip, "No test framework detected. Use --test-framework option.", :yellow
        end
      end

      def show_readme
        readme 'README' if behavior == :invoke
      end

      private

      def table_name
        model_name.tableize
      end

      def model_file_name
        model_name.underscore
      end

      def controller_path
        @controller_path ||= begin
          if options[:controller_name]
            options[:controller_name].underscore
          else
            "#{model_name.underscore.pluralize}_controller"
          end
        end
      end

      def controller_class_name
        controller_path.camelize.gsub('::', '::')
      end

      def migration_class_name
        "Add#{attribute_name.camelize}To#{model_name.pluralize.camelize}"
      end

      def migration_version
        "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
      end

      def add_index?
        options[:index]
      end

      def add_not_null?
        options[:not_null]
      end

      def add_check_constraint?
        options[:check_not_future]
      end

      def constraint_name
        "#{table_name}_#{attribute_name}_not_future"
      end

      def parse_duration(duration_string)
        return nil if duration_string.nil?
        return 2.hours if duration_string == '2.hours' # default

        if duration_string.match?(/(\d+(?:\.\d+)?)\.hours?/)
          $1.to_f.hours
        elsif duration_string.match?(/(\d+(?:\.\d+)?)\.minutes?/)
          $1.to_f.minutes
        elsif duration_string.match?(/(\d+(?:\.\d+)?)\.seconds?/)
          $1.to_f.seconds
        else
          2.hours # fallback
        end
      end

      def format_duration(seconds)
        if seconds % 1.hour == 0
          hours = seconds / 1.hour
          hours == hours.to_i ? "#{hours.to_i}.hours" : "#{hours}.hours"
        elsif seconds % 1.minute == 0
          minutes = seconds / 1.minute
          minutes == minutes.to_i ? "#{minutes.to_i}.minutes" : "#{minutes}.minutes"
        else
          "#{seconds}.seconds"
        end
      end

      def calculate_buffer_time(base_duration)
        # Add 20% buffer, minimum 30 minutes, maximum 2 hours
        buffer = (base_duration * 0.2).to_i
        [[buffer, 30.minutes].max, 2.hours].min
      end

      def smart_expiry_time
        # If user explicitly set expiry_time (not default), use it
        explicit_expiry = options[:expiry_time] != '2.hours'
        return options[:expiry_time] if explicit_expiry

        # If validate_max_duration is set and expirable, sync with buffer
        if options[:validate_max_duration] && options[:expirable]
          max_duration = parse_duration(options[:validate_max_duration])
          buffer = calculate_buffer_time(max_duration)
          total = max_duration + buffer

          @synced_expiry_time = format_duration(total)
          @auto_synced = true
          @synced_expiry_time
        else
          options[:expiry_time] # Use default
        end
      end

      def validate_time_consistency!
        return unless options[:validate_max_duration] && options[:expirable]

        max_duration = parse_duration(options[:validate_max_duration])
        expiry_time = parse_duration(smart_expiry_time)

        if expiry_time < max_duration
          say_status :warning, "⚠️  Time Mismatch Detected!", :yellow
          say_status :warning, "  Controller session expires: #{format_duration(expiry_time)}", :yellow
          say_status :warning, "  Model accepts forms up to: #{format_duration(max_duration)}", :yellow
          say_status :warning, "  Problem: Sessions expire BEFORE validation limit!", :yellow
          say_status :warning, "  Recommendation: Use --expiry-time #{format_duration(max_duration + calculate_buffer_time(max_duration))}", :yellow
        elsif @auto_synced
          say_status :create, "⏱️  Time Sync: expiry_time auto-set to #{smart_expiry_time} (#{options[:validate_max_duration]} + buffer)", :green
        elsif expiry_time > max_duration * 2
          say_status :info, "ℹ️  Session expiry (#{format_duration(expiry_time)}) is much longer than max (#{format_duration(max_duration)})", :blue
        elsif !@auto_synced && options[:expiry_time] != '2.hours'
          say_status :success, "✓ Time settings are consistent", :green
        end
      end

      def build_model_config
        parts = ["track_form_duration :#{attribute_name}"]
        config_options = []

        config_options << "prevent_future: true" if options[:prevent_future]
        config_options << "prevent_update: true" if options[:prevent_update]
        config_options << "validate_max_duration: #{options[:validate_max_duration]}" if options[:validate_max_duration]
        config_options << "validate_min_duration: #{options[:validate_min_duration]}" if options[:validate_min_duration]

        if config_options.any?
          parts[0] += ",\n                      #{config_options.join(",\n                      ")}"
        end

        parts.join
      end

      def build_controller_config
        parts = ["track_form_duration :#{attribute_name}"]
        config_options = []

        config_options << "expirable: #{options[:expirable]}"

        effective_expiry_time = smart_expiry_time
        config_options << "expiry_time: #{effective_expiry_time}" if options[:expirable]

        config_options << "on: :new" if options[:auto_initialize]

        if options[:auto_params] == false
          config_options << "auto_params: false"
        elsif options[:auto_params_on].present?
          actions_array = options[:auto_params_on].map { |a| ":#{a}" }.join(', ')
          config_options << "auto_params: [#{actions_array}]"
        end

        config_options << "param_key: :#{options[:param_key]}" if options[:param_key]

        if config_options.any?
          parts[0] += ",\n                      #{config_options.join(",\n                      ")}"
        end

        parts.join
      end

      def inject_controller_methods(controller_file)
        # Inject initialize_session in new action
        gsub_file controller_file, /(def new\n)/, "\\1    initialize_#{attribute_name}_session\n"

        # Inject session handling in create action
        create_action_code = <<-RUBY
    #{attribute_name} = #{attribute_name}_from_session

    @#{model_file_name} = #{model_name.camelize}.new(
      #{model_file_name}_params.merge(#{attribute_name}: #{attribute_name} || Time.zone.now)
    )

    if @#{model_file_name}.save
      cleanup_#{attribute_name}_session
        RUBY

        gsub_file controller_file, /(def create\n)(.*?)(if @#{model_file_name}\.save\n)/m do |match|
          "def create\n#{create_action_code}"
        end

        # Inject preserve in render
        render_preserve = "      preserve_#{attribute_name}_in_session(@#{model_file_name}.#{attribute_name})\n"
        gsub_file controller_file, /(else\n)(.*?)(render :new\n)/m do |match|
          "else\n#{render_preserve}      render :new\n"
        end
      end

      def detected_test_framework
        return options[:test_framework].to_sym if options[:test_framework]

        if File.exist?('spec/spec_helper.rb') || File.exist?('spec/rails_helper.rb')
          :rspec
        elsif File.exist?('test/test_helper.rb')
          :minitest
        end
      end

      def create_rspec_tests
        template 'spec/model_spec.rb.erb', "spec/models/#{model_file_name}_spec.rb"
        template 'spec/controller_spec.rb.erb', "spec/controllers/#{controller_path}_spec.rb"
      end

      def create_minitest_tests
        template 'test/model_test.rb.erb', "test/models/#{model_file_name}_test.rb"
        template 'test/controller_test.rb.erb', "test/controllers/#{controller_path}_test.rb"
      end

      def auto_params_enabled?
        return false if options[:auto_params] == false
        return true if options[:auto_params_on].present?
        return true if options[:auto_params]

        options[:auto_initialize]
      end
    end
  end
end
