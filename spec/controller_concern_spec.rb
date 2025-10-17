# frozen_string_literal: true

require "spec_helper"

RSpec.describe FormDurationTracker::ControllerConcern do
  let(:controller_class) do
    Class.new do
      include FormDurationTracker::ControllerConcern

      attr_accessor :session

      def initialize
        @session = {}
      end

      track_form_duration :started_at, expiry_time: 2.hours
    end
  end

  let(:controller) { controller_class.new }

  describe ".track_form_duration" do
    it "defines initialize method" do
      expect(controller).to respond_to(:initialize_started_at_session)
    end

    it "defines getter method without 'get_' prefix" do
      expect(controller).to respond_to(:started_at_from_session)
    end

    it "defines cleanup method" do
      expect(controller).to respond_to(:cleanup_started_at_session)
    end

    it "defines preserve method" do
      expect(controller).to respond_to(:preserve_started_at_in_session)
    end

    it "defines session config method" do
      expect(controller).to respond_to(:started_at_session_config)
    end
  end

  describe "#initialize_started_at_session" do
    context "with expirable: true (default)" do
      it "sets timestamp in session" do
        Timecop.freeze do
          controller.initialize_started_at_session

          expect(controller.session["started_at_timestamp"]).to eq(Time.zone.now.to_s)
        end
      end

      it "sets expiry time in session" do
        Timecop.freeze do
          controller.initialize_started_at_session

          expect(controller.session["started_at_timestamp_expires_at"]).to eq(2.hours.from_now.to_s)
        end
      end
    end

    context "with expirable: false" do
      let(:non_expirable_controller_class) do
        Class.new do
          include FormDurationTracker::ControllerConcern

          attr_accessor :session

          def initialize
            @session = {}
          end

          track_form_duration :started_at, expirable: false
        end
      end

      let(:non_expirable_controller) { non_expirable_controller_class.new }

      it "sets timestamp in session" do
        Timecop.freeze do
          non_expirable_controller.initialize_started_at_session

          expect(non_expirable_controller.session["started_at_timestamp"]).to eq(Time.zone.now.to_s)
        end
      end

      it "does not set expiry time in session" do
        non_expirable_controller.initialize_started_at_session

        expect(non_expirable_controller.session["started_at_timestamp_expires_at"]).to be_nil
      end
    end
  end

  describe "#started_at_from_session" do
    context "when session has valid timestamp" do
      it "returns the timestamp" do
        timestamp = 10.minutes.ago.to_s
        controller.session["started_at_timestamp"] = timestamp
        controller.session["started_at_timestamp_expires_at"] = 1.hour.from_now.to_s

        expect(controller.started_at_from_session).to eq(timestamp)
      end
    end

    context "when session is expired" do
      it "returns nil" do
        controller.session["started_at_timestamp"] = 10.minutes.ago.to_s
        controller.session["started_at_timestamp_expires_at"] = 1.minute.ago.to_s

        expect(controller.started_at_from_session).to be_nil
      end

      it "cleans up session" do
        controller.session["started_at_timestamp"] = 10.minutes.ago.to_s
        controller.session["started_at_timestamp_expires_at"] = 1.minute.ago.to_s

        controller.started_at_from_session

        expect(controller.session["started_at_timestamp"]).to be_nil
        expect(controller.session["started_at_timestamp_expires_at"]).to be_nil
      end
    end

    context "when session does not exist" do
      it "returns nil" do
        expect(controller.started_at_from_session).to be_nil
      end
    end

    context "when expiry time is invalid" do
      it "returns nil and cleans up session" do
        controller.session["started_at_timestamp"] = 10.minutes.ago.to_s
        controller.session["started_at_timestamp_expires_at"] = "invalid"

        expect(controller.started_at_from_session).to be_nil
        expect(controller.session["started_at_timestamp"]).to be_nil
      end
    end

    context "with expirable: false" do
      let(:non_expirable_controller_class) do
        Class.new do
          include FormDurationTracker::ControllerConcern

          attr_accessor :session

          def initialize
            @session = {}
          end

          track_form_duration :started_at, expirable: false
        end
      end

      let(:non_expirable_controller) { non_expirable_controller_class.new }

      it "returns timestamp without checking expiry" do
        timestamp = 10.minutes.ago.to_s
        non_expirable_controller.session["started_at_timestamp"] = timestamp

        expect(non_expirable_controller.started_at_from_session).to eq(timestamp)
      end
    end
  end

  describe "#cleanup_started_at_session" do
    it "removes timestamp from session" do
      controller.session["started_at_timestamp"] = Time.zone.now.to_s
      controller.session["started_at_timestamp_expires_at"] = 2.hours.from_now.to_s

      controller.cleanup_started_at_session

      expect(controller.session["started_at_timestamp"]).to be_nil
      expect(controller.session["started_at_timestamp_expires_at"]).to be_nil
    end
  end

  describe "#preserve_started_at_in_session" do
    it "updates timestamp in session" do
      new_timestamp = 5.minutes.ago
      controller.preserve_started_at_in_session(new_timestamp)

      expect(controller.session["started_at_timestamp"]).to eq(new_timestamp)
    end

    it "updates expiry time" do
      Timecop.freeze do
        controller.preserve_started_at_in_session(5.minutes.ago)

        expect(controller.session["started_at_timestamp_expires_at"]).to eq(2.hours.from_now.to_s)
      end
    end
  end

  describe "#started_at_session_config" do
    it "returns configuration hash" do
      config = controller.started_at_session_config

      expect(config[:session_key]).to eq("started_at_timestamp")
      expect(config[:expiry_key]).to eq("started_at_timestamp_expires_at")
      expect(config[:expiry_time]).to eq(2.hours)
      expect(config[:expirable]).to eq(true)
      expect(config[:on_actions]).to be_nil
      expect(config[:auto_params]).to eq([])
      expect(config[:param_key]).to be_nil
      expect(config[:auto_cleanup]).to eq(true)
    end
  end

  describe "custom session key" do
    let(:custom_controller_class) do
      Class.new do
        include FormDurationTracker::ControllerConcern

        attr_accessor :session, :action_name

        def initialize
          @session = {}
          @action_name = "new"
        end

        track_form_duration :started_at, session_key: :custom_key, expiry_time: 1.hour
      end
    end

    let(:custom_controller) { custom_controller_class.new }

    it "uses custom session key" do
      Timecop.freeze do
        custom_controller.initialize_started_at_session

        expect(custom_controller.session["custom_key"]).to eq(Time.zone.now.to_s)
        expect(custom_controller.session["custom_key_expires_at"]).to eq(1.hour.from_now.to_s)
      end
    end
  end

  describe "before_action integration" do
    let(:controller_with_before_action_class) do
      Class.new do
        include FormDurationTracker::ControllerConcern

        attr_accessor :session, :before_actions

        def initialize
          @session = {}
          @before_actions = []
        end

        def self.before_action(options = {}, &block)
          # Mock before_action to capture configuration
          @before_action_config = options
        end

        def self.before_action_config
          @before_action_config
        end

        track_form_duration :started_at, on: [:new, :edit]
      end
    end

    it "sets up before_action when :on option provided" do
      config = controller_with_before_action_class.before_action_config
      expect(config).to eq(only: [:new, :edit])
    end

    context "without :on option" do
      let(:controller_without_before_action_class) do
        Class.new do
          include FormDurationTracker::ControllerConcern

          attr_accessor :session

          def initialize
            @session = {}
          end

          def self.before_action_called?
            @before_action_called ||= false
          end

          def self.before_action(options = {})
            @before_action_called = true
          end

          track_form_duration :started_at
        end
      end

      it "does not set up before_action" do
        expect(controller_without_before_action_class.before_action_called?).to be false
      end
    end
  end

  describe "auto_params inference" do
    context "with on: :new" do
      let(:auto_params_controller_class) do
        Class.new do
          include FormDurationTracker::ControllerConcern

          attr_accessor :session, :params

          def initialize
            @session = {}
            @params = {}
          end

          def controller_name
            "posts"
          end

          def self.before_action(options = {}, &block)
          end

          track_form_duration :started_at, on: :new
        end
      end

      let(:auto_params_controller) { auto_params_controller_class.new }

      it "infers auto_params: [:create]" do
        config = auto_params_controller.started_at_session_config
        expect(config[:auto_params]).to eq([:create])
      end

      it "defines inject method" do
        expect(auto_params_controller).to respond_to(:inject_started_at_into_params)
      end

      it "injects timestamp into params" do
        timestamp = 10.minutes.ago.to_s
        auto_params_controller.session["started_at_timestamp"] = timestamp
        auto_params_controller.session["started_at_timestamp_expires_at"] = 1.hour.from_now.to_s
        auto_params_controller.params[:post] = {}

        result = auto_params_controller.inject_started_at_into_params

        expect(auto_params_controller.params[:post][:started_at]).to eq(timestamp)
      end

      it "does not inject if session is empty" do
        auto_params_controller.params[:post] = {}

        auto_params_controller.inject_started_at_into_params

        expect(auto_params_controller.params[:post][:started_at]).to be_nil
      end
    end

    context "with on: :edit" do
      let(:edit_controller_class) do
        Class.new do
          include FormDurationTracker::ControllerConcern

          attr_accessor :session

          def initialize
            @session = {}
          end

          def self.before_action(options = {}, &block)
          end

          track_form_duration :started_at, on: :edit
        end
      end

      let(:edit_controller) { edit_controller_class.new }

      it "infers auto_params: [:update]" do
        config = edit_controller.started_at_session_config
        expect(config[:auto_params]).to eq([:update])
      end
    end

    context "with on: [:new, :edit]" do
      let(:both_controller_class) do
        Class.new do
          include FormDurationTracker::ControllerConcern

          attr_accessor :session

          def initialize
            @session = {}
          end

          def self.before_action(options = {}, &block)
          end

          track_form_duration :started_at, on: [:new, :edit]
        end
      end

      let(:both_controller) { both_controller_class.new }

      it "infers auto_params: [:create, :update]" do
        config = both_controller.started_at_session_config
        expect(config[:auto_params]).to eq([:create, :update])
      end
    end

    context "with auto_params: false" do
      let(:disabled_controller_class) do
        Class.new do
          include FormDurationTracker::ControllerConcern

          attr_accessor :session

          def initialize
            @session = {}
          end

          def self.before_action(options = {}, &block)
          end

          track_form_duration :started_at, on: :new, auto_params: false
        end
      end

      let(:disabled_controller) { disabled_controller_class.new }

      it "disables auto_params" do
        config = disabled_controller.started_at_session_config
        expect(config[:auto_params]).to eq([])
      end

      it "does not define inject method" do
        expect(disabled_controller).not_to respond_to(:inject_started_at_into_params)
      end
    end

    context "with custom auto_params" do
      let(:custom_auto_params_class) do
        Class.new do
          include FormDurationTracker::ControllerConcern

          attr_accessor :session

          def initialize
            @session = {}
          end

          def self.before_action(options = {}, &block)
          end

          track_form_duration :started_at, auto_params: [:create, :custom_action]
        end
      end

      let(:custom_auto_params_controller) { custom_auto_params_class.new }

      it "uses custom auto_params" do
        config = custom_auto_params_controller.started_at_session_config
        expect(config[:auto_params]).to eq([:create, :custom_action])
      end
    end

    context "with custom param_key" do
      let(:custom_param_key_class) do
        Class.new do
          include FormDurationTracker::ControllerConcern

          attr_accessor :session, :params

          def initialize
            @session = {}
            @params = {}
          end

          def self.before_action(options = {}, &block)
          end

          track_form_duration :started_at, on: :new, param_key: :blog_post
        end
      end

      let(:custom_param_key_controller) { custom_param_key_class.new }

      it "uses custom param_key" do
        timestamp = 10.minutes.ago.to_s
        custom_param_key_controller.session["started_at_timestamp"] = timestamp
        custom_param_key_controller.session["started_at_timestamp_expires_at"] = 1.hour.from_now.to_s
        custom_param_key_controller.params[:blog_post] = {}

        custom_param_key_controller.inject_started_at_into_params

        expect(custom_param_key_controller.params[:blog_post][:started_at]).to eq(timestamp)
      end
    end
  end

  describe "auto_cleanup feature" do
    context "with auto_cleanup: true (default)" do
      let(:auto_cleanup_controller_class) do
        Class.new do
          include FormDurationTracker::ControllerConcern

          attr_accessor :session, :action_name

          def initialize
            @session = {}
            @action_name = "new"
          end

          def self.before_action(options = {}, &block)
          end

          track_form_duration :started_at, on: :new
        end
      end

      let(:auto_cleanup_controller) { auto_cleanup_controller_class.new }

      it "cleans up previous session on new action" do
        auto_cleanup_controller.session["started_at_timestamp"] = "old_timestamp"
        auto_cleanup_controller.session["started_at_timestamp_expires_at"] = 1.hour.from_now.to_s
        auto_cleanup_controller.action_name = "new"

        auto_cleanup_controller.initialize_started_at_session

        expect(auto_cleanup_controller.session["started_at_timestamp"]).not_to eq("old_timestamp")
      end

      it "does not cleanup on edit action" do
        auto_cleanup_controller.session["started_at_timestamp"] = "old_timestamp"
        auto_cleanup_controller.action_name = "edit"

        auto_cleanup_controller.initialize_started_at_session

        expect(auto_cleanup_controller.session["started_at_timestamp"]).to eq("old_timestamp")
      end

      it "does not cleanup on update action" do
        auto_cleanup_controller.session["started_at_timestamp"] = "old_timestamp"
        auto_cleanup_controller.action_name = "update"

        auto_cleanup_controller.initialize_started_at_session

        expect(auto_cleanup_controller.session["started_at_timestamp"]).to eq("old_timestamp")
      end
    end

    context "with auto_cleanup: false" do
      let(:no_auto_cleanup_class) do
        Class.new do
          include FormDurationTracker::ControllerConcern

          attr_accessor :session, :action_name

          def initialize
            @session = {}
            @action_name = "new"
          end

          def self.before_action(options = {}, &block)
          end

          track_form_duration :started_at, on: :new, auto_cleanup: false
        end
      end

      let(:no_auto_cleanup_controller) { no_auto_cleanup_class.new }

      it "still sets new timestamp but doesn't explicitly cleanup" do
        no_auto_cleanup_controller.session["started_at_timestamp"] = "old_timestamp"
        no_auto_cleanup_controller.session["other_key"] = "other_value"
        no_auto_cleanup_controller.action_name = "new"

        no_auto_cleanup_controller.initialize_started_at_session

        expect(no_auto_cleanup_controller.session["started_at_timestamp"]).not_to eq("old_timestamp")
        expect(no_auto_cleanup_controller.session["other_key"]).to eq("other_value")
      end
    end
  end

  describe "auto_params smart injection" do
    context "does not overwrite existing params" do
      let(:smart_inject_class) do
        Class.new do
          include FormDurationTracker::ControllerConcern

          attr_accessor :session, :params

          def initialize
            @session = {}
            @params = {}
          end

          def controller_name
            "posts"
          end

          def self.before_action(options = {}, &block)
          end

          track_form_duration :started_at, on: :new
        end
      end

      let(:smart_inject_controller) { smart_inject_class.new }

      it "injects when param is not present" do
        timestamp = 10.minutes.ago.to_s
        smart_inject_controller.session["started_at_timestamp"] = timestamp
        smart_inject_controller.session["started_at_timestamp_expires_at"] = 1.hour.from_now.to_s
        smart_inject_controller.params[:post] = {}

        smart_inject_controller.inject_started_at_into_params

        expect(smart_inject_controller.params[:post][:started_at]).to eq(timestamp)
      end

      it "does not overwrite when param already exists" do
        existing_timestamp = 20.minutes.ago.to_s
        session_timestamp = 10.minutes.ago.to_s
        
        smart_inject_controller.session["started_at_timestamp"] = session_timestamp
        smart_inject_controller.session["started_at_timestamp_expires_at"] = 1.hour.from_now.to_s
        smart_inject_controller.params[:post] = { started_at: existing_timestamp }

        smart_inject_controller.inject_started_at_into_params

        expect(smart_inject_controller.params[:post][:started_at]).to eq(existing_timestamp)
      end
    end
  end
end
