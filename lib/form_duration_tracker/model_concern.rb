# frozen_string_literal: true

module FormDurationTracker
  module ModelConcern
    extend ActiveSupport::Concern

    class_methods do
      def track_form_duration(attribute_name, options = {})
        validates attribute_name, presence: true, on: :create

        if options[:prevent_future]
          validate :"validate_#{attribute_name}_not_in_future", on: :create
          define_method("validate_#{attribute_name}_not_in_future") do
            return if send(attribute_name).blank?

            if send(attribute_name) > Time.zone.now
              errors.add(attribute_name, "can't be in the future")
            end
          end
        end

        if options[:prevent_update]
          before_validation :"prevent_#{attribute_name}_change", on: :update
          define_method("prevent_#{attribute_name}_change") do
            attribute_was = send("#{attribute_name}_was")
            if persisted? && send("#{attribute_name}_changed?") && attribute_was.present?
              send("#{attribute_name}=", attribute_was)
            end
          end
        end

        if options[:validate_max_duration]
          max_duration = options[:max_duration]
          validate :"validate_#{attribute_name}_max_duration", on: :create
          define_method("validate_#{attribute_name}_max_duration") do
            return if send(attribute_name).blank?

            duration = Time.zone.now - send(attribute_name)
            if duration > max_duration
              errors.add(attribute_name, "form took too long to complete (max: #{max_duration / 60} minutes)")
            end
          end
        end

        if options[:validate_min_duration]
          min_duration = options[:min_duration]
          validate :"validate_#{attribute_name}_min_duration", on: :create
          define_method("validate_#{attribute_name}_min_duration") do
            return if send(attribute_name).blank?

            duration = Time.zone.now - send(attribute_name)
            if duration < min_duration
              errors.add(attribute_name, "form was completed too quickly (min: #{min_duration} seconds)")
            end
          end
        end
      end
    end
  end
end
