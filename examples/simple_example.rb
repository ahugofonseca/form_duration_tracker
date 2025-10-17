# frozen_string_literal: true

# Simple Example: Basic Form Duration Tracking
# This is the minimal setup needed to track form completion time

# ============================================================================
# 1. Add column to your model
# ============================================================================

# rails generate migration AddStartedAtToPosts started_at:datetime
# rake db:migrate

# ============================================================================
# 2. Include concern in model
# ============================================================================

class Post < ApplicationRecord
  include FormDurationTracker::ModelConcern

  # Minimal setup - just validates presence
  track_form_duration :started_at

  validates :title, :content, presence: true
end

# ============================================================================
# 3. Include concern in controller
# ============================================================================

class PostsController < ApplicationController
  include FormDurationTracker::ControllerConcern

  # Option 1: With Smart Auto-Params (Recommended)
  track_form_duration :started_at, on: :new

  def new
    @post = Post.new
  end

  def create
    @post = Post.new(post_params)

    if @post.save
      redirect_to posts_path, notice: "Post created!"
    else
      render :new
    end
  end

  # Option 2: Manual approach (legacy - if you need manual control)
  # track_form_duration :started_at, on: :new, auto_params: false, auto_cleanup: false
  #
  # def create
  #   started_at = started_at_from_session
  #   @post = Post.new(post_params.merge(started_at: started_at || Time.zone.now))
  #
  #   if @post.save
  #     cleanup_started_at_session  # Manual cleanup if auto_cleanup: false
  #     redirect_to posts_path
  #   else
  #     render :new
  #   end
  # end

  private

  def post_params
    params.require(:post).permit(:title, :content)
  end
end

# ============================================================================
# 4. Add hidden field to form (optional but recommended)
# ============================================================================

# <%= form_for @post do |f| %>
#   <%= f.hidden_field :started_at %>
#   <%= f.text_field :title %>
#   <%= f.text_area :content %>
#   <%= f.submit %>
# <% end %>

# That's it! Now you can analyze form completion times:
# Post.average("EXTRACT(EPOCH FROM (created_at - started_at))")
