# frozen_string_literal: true

require 'spec_helper'
require 'active_model'

RSpec.describe FormDurationTracker::ModelConcern do
  let(:model_class) do
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Validations::Callbacks
      include FormDurationTracker::ModelConcern

      attr_accessor :started_at, :id

      track_form_duration :started_at,
                          prevent_future: true,
                          prevent_update: true,
                          validate_max_duration: 2.hours,
                          validate_min_duration: 5.seconds

      def self.model_name
        ActiveModel::Name.new(self, nil, 'TestModel')
      end

      def persisted?
        !id.nil?
      end

      attr_reader :started_at_was

      def started_at_changed?
        @started_at != @started_at_was
      end

      def save
        @started_at_was = @started_at if valid?(:create)
        @id = rand(1000)
        valid?(:create)
      end

      def update(attributes)
        run_callbacks :validation do
          attributes.each { |k, v| send("#{k}=", v) }
          valid?(:update)
        end
      end
    end
  end

  let(:model) { model_class.new }

  describe 'presence validation' do
    it 'requires started_at on create' do
      model.started_at = nil
      expect(model.valid?(:create)).to be false
      expect(model.errors[:started_at]).to include("can't be blank")
    end

    it 'is valid with started_at' do
      model.started_at = 10.minutes.ago
      expect(model.valid?(:create)).to be true
    end
  end

  describe 'prevent_future validation' do
    it 'rejects future timestamps' do
      model.started_at = 1.hour.from_now
      expect(model.valid?(:create)).to be false
      expect(model.errors[:started_at]).to include("can't be in the future")
    end

    it 'accepts past timestamps' do
      model.started_at = 1.hour.ago
      expect(model.valid?(:create)).to be true
    end

    it 'accepts current timestamp' do
      Timecop.freeze do
        model.started_at = 10.seconds.ago
        expect(model.valid?(:create)).to be true
      end
    end
  end

  describe 'prevent_update' do
    it 'prevents changing started_at on update' do
      model.started_at = 1.hour.ago
      model.save

      original_time = model.started_at
      model.update(started_at: Time.zone.now)

      expect(model.started_at).to eq(original_time)
    end
  end

  describe 'validate_max_duration' do
    it 'rejects forms that took too long' do
      model.started_at = 3.hours.ago
      expect(model.valid?(:create)).to be false
      expect(model.errors[:started_at]).to include('form took too long to complete (max: 120.0 minutes)')
    end

    it 'accepts forms within time limit' do
      model.started_at = 1.hour.ago
      expect(model.valid?(:create)).to be true
    end
  end

  describe 'validate_min_duration' do
    it 'rejects forms completed too quickly' do
      model.started_at = 2.seconds.ago
      expect(model.valid?(:create)).to be false
      expect(model.errors[:started_at]).to include('form was completed too quickly (min: 5 seconds)')
    end

    it 'accepts forms that took minimum time' do
      model.started_at = 10.seconds.ago
      expect(model.valid?(:create)).to be true
    end
  end

  describe 'minimal configuration' do
    let(:minimal_model_class) do
      Class.new do
        include ActiveModel::Model
        include FormDurationTracker::ModelConcern

        attr_accessor :started_at

        track_form_duration :started_at

        def self.model_name
          ActiveModel::Name.new(self, nil, 'MinimalTestModel')
        end
      end
    end

    let(:minimal_model) { minimal_model_class.new }

    it 'only validates presence' do
      minimal_model.started_at = nil
      expect(minimal_model.valid?(:create)).to be false

      minimal_model.started_at = 1.hour.from_now
      expect(minimal_model.valid?(:create)).to be true
    end
  end
end
