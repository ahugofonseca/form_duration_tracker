# frozen_string_literal: true

module FormDurationTracker
  module ControllerConcern
    extend ActiveSupport::Concern

    DEFAULT_SESSION_EXPIRY_TIME = 2.hours

    class_methods do
      def track_form_duration(attribute_name, options = {})
        expirable = options.fetch(:expirable, true)
        expiry_time = options.fetch(:expiry_time, DEFAULT_SESSION_EXPIRY_TIME)
        session_key = (options[:session_key] || "#{attribute_name}_timestamp").to_s
        expiry_key = "#{session_key}_expires_at"
        on_actions = options[:on]
        auto_params = resolve_auto_params_actions(options[:auto_params], on_actions)
        param_key = options[:param_key]
        auto_cleanup = options.fetch(:auto_cleanup, true)

        define_method("initialize_#{attribute_name}_session") do
          current_action = respond_to?(:action_name) ? action_name.to_sym : nil
          is_edit_action = %i[edit update].include?(current_action)

          cleanup_form_timestamp(session_key, expiry_key, expirable) if auto_cleanup && !is_edit_action

          return if is_edit_action

          if expirable
            cleanup_expired_form_timestamp(session_key, expiry_key)
            session[expiry_key] = expiry_time.from_now.to_s
          end

          session[session_key] = Time.zone.now.to_s
        end

        define_method("#{attribute_name}_from_session") do
          get_form_timestamp(session_key, expiry_key, expirable)
        end

        define_method("cleanup_#{attribute_name}_session") do
          cleanup_form_timestamp(session_key, expiry_key, expirable)
        end

        define_method("preserve_#{attribute_name}_in_session") do |value|
          preserve_form_timestamp(session_key, expiry_key, value, expiry_time, expirable)
        end

        define_method("#{attribute_name}_session_config") do
          {
            session_key: session_key,
            expiry_key: expiry_key,
            expiry_time: expiry_time,
            expirable: expirable,
            on_actions: on_actions,
            auto_params: auto_params,
            param_key: param_key,
            auto_cleanup: auto_cleanup
          }
        end

        if auto_params.present?
          define_method("inject_#{attribute_name}_into_params") do
            timestamp = send("#{attribute_name}_from_session")
            return unless timestamp

            target_key = param_key || controller_name.singularize.to_sym
            return unless params[target_key].respond_to?(:[]=)

            params[target_key][attribute_name] ||= timestamp
          end

          before_action only: auto_params do
            send("inject_#{attribute_name}_into_params")
          end
        end

        return unless on_actions.present?

        before_action only: on_actions do
          send("initialize_#{attribute_name}_session")
        end
      end

      private

      def resolve_auto_params_actions(auto_params_option, on_actions)
        return [] if auto_params_option == false
        return Array(auto_params_option) if auto_params_option.present?

        infer_auto_params_actions(on_actions)
      end

      def infer_auto_params_actions(on_actions)
        return [] unless on_actions.present?

        actions = Array(on_actions)
        inferred = []

        inferred << :create if actions.include?(:new)
        inferred << :update if actions.include?(:edit)

        inferred
      end
    end

    def get_form_timestamp(session_key, expiry_key, expirable)
      return nil unless session[session_key]

      if expirable && session[expiry_key]
        expires_at = Time.zone.parse(session[expiry_key])

        if Time.zone.now > expires_at
          cleanup_form_timestamp(session_key, expiry_key, expirable)
          return nil
        end
      end

      session[session_key]
    rescue ArgumentError
      cleanup_form_timestamp(session_key, expiry_key, expirable)
      nil
    end

    def cleanup_form_timestamp(session_key, expiry_key, expirable)
      session.delete(session_key)
      session.delete(expiry_key) if expirable
    end

    def cleanup_expired_form_timestamp(session_key, expiry_key)
      return unless session[expiry_key]

      expires_at = Time.zone.parse(session[expiry_key])
      cleanup_form_timestamp(session_key, expiry_key, true) if Time.zone.now > expires_at
    rescue ArgumentError
      cleanup_form_timestamp(session_key, expiry_key, true)
    end

    def preserve_form_timestamp(session_key, expiry_key, value, expiry_time, expirable)
      session[session_key] = value
      session[expiry_key] = expiry_time.from_now.to_s if expirable
    end
  end
end
