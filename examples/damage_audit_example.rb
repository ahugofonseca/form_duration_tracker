# frozen_string_literal: true

# Example: Damage Audit Form with Duration Tracking
# This example shows how to integrate FormDurationTracker into a Rails application
# for tracking how long users take to complete damage audit forms.

# ============================================================================
# 1. MIGRATION
# ============================================================================

class AddStartedAtToDamageAudits < ActiveRecord::Migration[4.2]
  def change
    add_column :damage_audits, :started_at, :datetime
    add_index :damage_audits, :started_at
  end
end

# ============================================================================
# 2. MODEL
# ============================================================================

class DamageAudit < ApplicationRecord
  include FormDurationTracker::ModelConcern

  # Track form duration with all validations enabled
  track_form_duration :started_at,
                      prevent_future: true,       # Timestamp can't be in future
                      prevent_update: true,       # Can't change after creation
                      validate_max_duration: 2.hours,    # Max 2 hours to complete
                      validate_min_duration: 3.seconds   # Min 3 seconds (bot detection)

  # Regular validations
  belongs_to :fleet
  belongs_to :created_by, class_name: "User"

  has_many :damage_audit_items, dependent: :destroy
  accepts_nested_attributes_for :damage_audit_items

  validates :fleet_id, presence: true
  validates :tire_type, presence: true
  validates :vehicle_current_mileage, presence: true

  # Custom validation to ensure form wasn't rushed
  validate :ensure_reasonable_completion_time, on: :create

  private

  def ensure_reasonable_completion_time
    return unless started_at.present?

    duration_minutes = (Time.zone.now - started_at) / 60.0

    if duration_minutes < 1
      errors.add(:base, "Please take your time to complete the audit carefully")
    end
  end
end

# ============================================================================
# 3. CONTROLLER
# ============================================================================

module Admin
  class DamageAuditsController < Admin::BaseController
    include FormDurationTracker::ControllerConcern

    # Track the started_at timestamp with 2-hour expiry
    track_form_duration :started_at, expiry_time: 2.hours

    before_action :set_fleet

    def index
      @audits = @fleet.damage_audits.order(created_at: :desc)
    end

    def new
      # Initialize session timestamp when form loads
      initialize_started_at_session

      @damage_audit = @fleet.damage_audits.build
      setup_audit_items
    end

    def create
      damage_audit_attributes = damage_audit_params.merge(
        created_by_id: current_user.id,
        fleet_id: @fleet.id
      )

      @damage_audit = DamageAudit.new(damage_audit_attributes)

      if @damage_audit.save
        flash[:notice] = "Damage audit created successfully"
        redirect_to admin_fleet_damage_audits_path(@fleet)
      else
        setup_audit_items
        render :new
      end
    end

    def edit
      @damage_audit = @fleet.damage_audits.find(params[:id])
    end

    def update
      @damage_audit = @fleet.damage_audits.find(params[:id])

      # Note: started_at won't change even if provided in params
      # because of prevent_update: true in the model
      if @damage_audit.update(damage_audit_params)
        flash[:notice] = "Damage audit updated successfully"
        redirect_to admin_fleet_damage_audits_path(@fleet)
      else
        render :edit
      end
    end

    private

    def set_fleet
      @fleet = Fleet.find(params[:fleet_id])
    end

    def setup_audit_items
      open_incidents = @fleet.incidents.open.order(:id)
      open_incidents.each do |incident|
        @damage_audit.damage_audit_items.build(incident: incident)
      end
    end

    def damage_audit_params
      params.require(:damage_audit).permit(
        :started_at,
        :tire_type,
        :tire_front_left,
        :tire_front_right,
        :tire_back_left,
        :tire_back_right,
        :vehicle_current_mileage,
        damage_audit_items_attributes: [:id, :audited_by_id, :active, :file_url]
      )
    end
  end
end

# ============================================================================
# 4. VIEW
# ============================================================================

# app/views/admin/damage_audits/new.html.erb
# 
# <%= form_for [:admin, @fleet, @damage_audit] do |f| %>
#   <%= f.hidden_field :started_at %>
# 
#   <% if @damage_audit.errors.any? %>
#     <div class="alert alert-danger">
#       <h4><%= pluralize(@damage_audit.errors.count, "error") %> prohibited this audit:</h4>
#       <ul>
#         <% @damage_audit.errors.full_messages.each do |message| %>
#           <li><%= message %></li>
#         <% end %>
#       </ul>
#     </div>
#   <% end %>
# 
#   <div class="form-group">
#     <%= f.label :tire_type %>
#     <%= f.select :tire_type, DamageAudit.tire_type_options, {}, class: "form-control" %>
#   </div>
# 
#   <div class="form-group">
#     <%= f.label :vehicle_current_mileage %>
#     <%= f.number_field :vehicle_current_mileage, class: "form-control" %>
#   </div>
# 
#   <%= f.fields_for :damage_audit_items do |item_form| %>
#     <div class="audit-item">
#       <%= item_form.hidden_field :incident_id %>
#       <%= item_form.check_box :active %>
#       <%= item_form.label :active, "Mark as fixed" %>
#     </div>
#   <% end %>
# 
#   <%= f.submit "Create Audit", class: "btn btn-primary" %>
# <% end %>

# ============================================================================
# 5. SPECS
# ============================================================================

# spec/models/damage_audit_spec.rb
RSpec.describe DamageAudit, type: :model do
  let(:fleet) { create(:fleet) }
  let(:user) { create(:user) }

  describe "form duration tracking" do
    it "requires started_at on create" do
      audit = DamageAudit.new(fleet: fleet, created_by: user)
      expect(audit).not_to be_valid
      expect(audit.errors[:started_at]).to include("can't be blank")
    end

    it "rejects future timestamps" do
      audit = build(:damage_audit, started_at: 1.hour.from_now)
      expect(audit).not_to be_valid
      expect(audit.errors[:started_at]).to include("can't be in the future")
    end

    it "rejects forms completed too quickly" do
      audit = build(:damage_audit, started_at: 1.second.ago)
      expect(audit).not_to be_valid
      expect(audit.errors[:started_at]).to include("form was completed too quickly")
    end

    it "rejects forms that took too long" do
      audit = build(:damage_audit, started_at: 3.hours.ago)
      expect(audit).not_to be_valid
      expect(audit.errors[:started_at]).to include("form took too long to complete")
    end

    it "prevents updating started_at" do
      audit = create(:damage_audit, started_at: 1.hour.ago)
      original_time = audit.started_at

      audit.update(started_at: Time.zone.now)
      audit.reload

      expect(audit.started_at).to be_within(1.second).of(original_time)
    end

    it "accepts valid form completion" do
      audit = build(:damage_audit, started_at: 10.minutes.ago)
      expect(audit).to be_valid
    end
  end
end

# spec/controllers/admin/damage_audits_controller_spec.rb
RSpec.describe Admin::DamageAuditsController, type: :controller do
  let(:fleet) { create(:fleet) }
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET #new" do
    it "initializes session timestamp" do
      Timecop.freeze do
        get :new, params: { fleet_id: fleet.id }

        expect(session[:started_at_timestamp]).to eq(Time.zone.now.to_s)
      end
    end
  end

  describe "POST #create" do
    let(:valid_params) do
      {
        fleet_id: fleet.id,
        damage_audit: attributes_for(:damage_audit)
      }
    end

    context "with session timestamp" do
      before do
        session[:started_at_timestamp] = 10.minutes.ago.to_s
        session[:started_at_timestamp_expires_at] = 1.hour.from_now.to_s
      end

      it "uses session timestamp" do
        post :create, params: valid_params

        audit = DamageAudit.last
        expect(audit.started_at).to be_within(1.second).of(10.minutes.ago)
      end

      it "cleans up session on success" do
        post :create, params: valid_params

        expect(session[:started_at_timestamp]).to be_nil
        expect(session[:started_at_timestamp_expires_at]).to be_nil
      end
    end

    context "with expired session" do
      before do
        session[:started_at_timestamp] = 1.hour.ago.to_s
        session[:started_at_timestamp_expires_at] = 30.minutes.ago.to_s
      end

      it "falls back to current time" do
        Timecop.freeze do
          post :create, params: valid_params

          audit = DamageAudit.last
          expect(audit.started_at).to be_within(1.second).of(Time.zone.now)
        end
      end
    end

    context "with validation errors" do
      let(:invalid_params) do
        {
          fleet_id: fleet.id,
          damage_audit: { tire_type: nil }
        }
      end

      before do
        session[:started_at_timestamp] = 10.minutes.ago.to_s
      end

      it "preserves session timestamp" do
        post :create, params: invalid_params

        expect(session[:started_at_timestamp]).to be_present
      end

      it "re-renders form" do
        post :create, params: invalid_params

        expect(response).to render_template(:new)
      end
    end
  end
end

# ============================================================================
# 6. ANALYTICS (OPTIONAL)
# ============================================================================

# Add a service to track form completion analytics
class DamageAuditAnalyticsService
  def self.track_completion(damage_audit)
    return unless damage_audit.started_at.present?

    duration_seconds = (damage_audit.created_at - damage_audit.started_at).to_i

    # Send to analytics service (e.g., Google Analytics, Mixpanel)
    AnalyticsTracker.track_event(
      event: "damage_audit_completed",
      properties: {
        duration_seconds: duration_seconds,
        duration_minutes: (duration_seconds / 60.0).round(2),
        fleet_id: damage_audit.fleet_id,
        user_id: damage_audit.created_by_id,
        items_count: damage_audit.damage_audit_items.count
      }
    )
  end
end

# Call in controller after successful creation
# DamageAuditAnalyticsService.track_completion(@damage_audit)
