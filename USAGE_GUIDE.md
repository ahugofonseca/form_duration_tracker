# FormDurationTracker Usage Guide

Complete guide for integrating FormDurationTracker into your Rails application.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Installation](#installation)
3. [Controller Setup](#controller-setup)
4. [Model Setup](#model-setup)
5. [Configuration Options](#configuration-options)
6. [Common Use Cases](#common-use-cases)
7. [Troubleshooting](#troubleshooting)
8. [Best Practices](#best-practices)

## Quick Start

### 1. Add the gem

```ruby
# Gemfile
gem 'form_duration_tracker'
```

### 2. Create migration

```bash
rails generate migration AddStartedAtToYourModel started_at:datetime
rails db:migrate
```

### 3. Update your model

```ruby
class YourModel < ApplicationRecord
  include FormDurationTracker::ModelConcern
  
  track_form_duration :started_at
end
```

### 4. Update your controller

```ruby
class YourController < ApplicationController
  include FormDurationTracker::ControllerConcern
  
  track_form_duration :started_at

  def new
    initialize_started_at_session
    @record = YourModel.new
  end

  def create
    started_at = started_at_from_session
    
    @record = YourModel.new(
      record_params.merge(started_at: started_at || Time.zone.now)
    )

    if @record.save
      cleanup_started_at_session
      redirect_to records_path
    else
      preserve_started_at_in_session(@record.started_at)
      render :new
    end
  end
end
```

Done! Your form now tracks completion duration.

## Installation

Add to your Gemfile:

```ruby
gem 'form_duration_tracker'
```

Run bundler:

```bash
bundle install
```

## Controller Setup

### Basic Setup

```ruby
class ContactsController < ApplicationController
  include FormDurationTracker::ControllerConcern
  
  # Default: 2 hour expiry
  track_form_duration :started_at
end
```

### With Custom Expiry Time

```ruby
class ContactsController < ApplicationController
  include FormDurationTracker::ControllerConcern
  
  # Session expires after 4 hours
  track_form_duration :started_at, expiry_time: 4.hours
end
```

### With Custom Session Key

```ruby
class ContactsController < ApplicationController
  include FormDurationTracker::ControllerConcern
  
  # Use custom session key to avoid conflicts
  track_form_duration :started_at, 
                      session_key: :contact_form_start,
                      expiry_time: 3.hours
end
```

### Generated Methods

The `track_form_duration` macro generates these methods:

```ruby
# Initialize timestamp when form loads
initialize_started_at_session

# Get timestamp from session (nil if expired)
started_at_from_session

# Clean up session after successful save
cleanup_started_at_session

# Preserve timestamp on validation error
preserve_started_at_in_session(value)

# Get session configuration
started_at_session_config
```

### Complete Controller Example

```ruby
class ArticlesController < ApplicationController
  include FormDurationTracker::ControllerConcern
  
  track_form_duration :started_at, expiry_time: 1.hour

  def new
    initialize_started_at_session
    @article = Article.new
  end

  def create
    started_at = started_at_from_session

    @article = Article.new(
      article_params.merge(
        started_at: started_at || Time.zone.now,
        author_id: current_user.id
      )
    )

    if @article.save
      cleanup_started_at_session
      redirect_to @article, notice: 'Article created!'
    else
      preserve_started_at_in_session(@article.started_at)
      flash.now[:alert] = 'Please correct the errors below'
      render :new
    end
  end

  private

  def article_params
    params.require(:article).permit(:title, :content)
  end
end
```

## Model Setup

### Basic Setup

```ruby
class Article < ApplicationRecord
  include FormDurationTracker::ModelConcern
  
  # Only validates presence
  track_form_duration :started_at
end
```

### Prevent Future Timestamps

```ruby
class Article < ApplicationRecord
  include FormDurationTracker::ModelConcern
  
  track_form_duration :started_at, prevent_future: true
end

# Validation error if started_at is in the future
```

### Prevent Updates

```ruby
class Article < ApplicationRecord
  include FormDurationTracker::ModelConcern
  
  track_form_duration :started_at, prevent_update: true
end

# started_at cannot be changed after record creation
article.update(started_at: Time.zone.now) # silently ignored
```

### Maximum Duration

```ruby
class Article < ApplicationRecord
  include FormDurationTracker::ModelConcern
  
  track_form_duration :started_at, validate_max_duration: 30.minutes
end

# Validation error if form took longer than 30 minutes
```

### Minimum Duration (Bot Detection)

```ruby
class Article < ApplicationRecord
  include FormDurationTracker::ModelConcern
  
  track_form_duration :started_at, validate_min_duration: 5.seconds
end

# Validation error if form completed in less than 5 seconds
```

### All Options Combined

```ruby
class Article < ApplicationRecord
  include FormDurationTracker::ModelConcern
  
  track_form_duration :started_at,
                      prevent_future: true,
                      prevent_update: true,
                      validate_max_duration: 2.hours,
                      validate_min_duration: 3.seconds
end
```

## Configuration Options

### Controller Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `expiry_time` | Duration | `2.hours` | How long before session expires |
| `session_key` | Symbol/String | `"#{attribute}_timestamp"` | Custom session key name |

### Model Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `prevent_future` | Boolean | `false` | Reject timestamps in the future |
| `prevent_update` | Boolean | `false` | Prevent changing after creation |
| `validate_max_duration` | Duration | `nil` | Maximum time to complete form |
| `validate_min_duration` | Duration | `nil` | Minimum time to complete form |

## Common Use Cases

### 1. Survey/Questionnaire

```ruby
# Long form with timeout protection
class Survey < ApplicationRecord
  include FormDurationTracker::ModelConcern
  
  track_form_duration :started_at,
                      prevent_future: true,
                      validate_max_duration: 1.hour
end

class SurveysController < ApplicationController
  include FormDurationTracker::ControllerConcern
  
  track_form_duration :started_at, expiry_time: 1.hour
end
```

### 2. Registration Form (Bot Detection)

```ruby
# Prevent bot submissions
class Registration < ApplicationRecord
  include FormDurationTracker::ModelConcern
  
  track_form_duration :started_at,
                      prevent_future: true,
                      validate_min_duration: 10.seconds,
                      validate_max_duration: 30.minutes
end
```

### 3. Multi-Step Form

```ruby
# Track start of first step, save on final step
class Application < ApplicationRecord
  include FormDurationTracker::ModelConcern
  
  track_form_duration :form_started_at,
                      prevent_update: true,
                      validate_max_duration: 4.hours
end

class ApplicationsController < ApplicationController
  include FormDurationTracker::ControllerConcern
  
  track_form_duration :form_started_at, expiry_time: 4.hours

  def step1
    initialize_form_started_at_session
    @application = Application.new
  end

  def step2
    @application = Application.new(session[:application_data])
  end

  def create
    form_started_at = form_started_at_from_session
    
    @application = Application.new(
      application_params.merge(form_started_at: form_started_at || Time.zone.now)
    )

    if @application.save
      cleanup_form_started_at_session
      redirect_to success_path
    else
      preserve_form_started_at_in_session(@application.form_started_at)
      render :step2
    end
  end
end
```

### 4. Audit Forms

```ruby
# Track audit completion time for compliance
class Audit < ApplicationRecord
  include FormDurationTracker::ModelConcern
  
  track_form_duration :started_at,
                      prevent_future: true,
                      prevent_update: true,
                      validate_max_duration: 2.hours,
                      validate_min_duration: 5.seconds

  # Additional audit validations
  validates :auditor_id, :location_id, presence: true
  
  after_create :log_completion_time

  private

  def log_completion_time
    duration = created_at - started_at
    Rails.logger.info "Audit #{id} completed in #{duration.to_i} seconds"
  end
end
```

### 5. Comment/Feedback Forms

```ruby
# Simple tracking without strict validations
class Comment < ApplicationRecord
  include FormDurationTracker::ModelConcern
  
  track_form_duration :started_at
end

class CommentsController < ApplicationController
  include FormDurationTracker::ControllerConcern
  
  track_form_duration :started_at, expiry_time: 30.minutes
end
```

## Troubleshooting

### Session Not Persisting

**Problem:** Session timestamp keeps resetting

**Solution:** Ensure session store is configured:

```ruby
# config/initializers/session_store.rb
Rails.application.config.session_store :cookie_store, key: '_your_app_session'
```

### Validation Always Failing

**Problem:** `started_at can't be blank` error

**Solution:** Ensure controller is setting the timestamp:

```ruby
def create
  started_at = started_at_from_session
  
  # IMPORTANT: Merge started_at into params
  @record = Record.new(
    record_params.merge(started_at: started_at || Time.zone.now)
  )
end
```

### Session Expired Too Soon

**Problem:** Users getting "can't be blank" errors

**Solution:** Increase expiry time:

```ruby
track_form_duration :started_at, expiry_time: 4.hours
```

### Timestamp Not Updating on Error

**Problem:** Timestamp changes after validation error

**Solution (Usually Not an Issue):**

With **auto-cleanup and auto-params enabled** (both enabled by default), timestamps are managed automatically:

```ruby
# Modern approach - fully automatic!
track_form_duration :started_at, on: :new  # auto_cleanup and auto_params enabled

def create
  @record = Record.new(record_params)  # started_at auto-injected
  
  if @record.save
    redirect_to records_path  # No cleanup needed - auto-cleanup on next form!
  else
    render :new  # Timestamp auto-injected again on next submit
  end
end
```

**Only manually manage if you disabled auto features:**
```ruby
# Full manual control
track_form_duration :started_at, on: :new, auto_params: false, auto_cleanup: false

def create
  started_at = started_at_from_session
  @record = Record.new(record_params.merge(started_at: started_at))
  
  if @record.save
    cleanup_started_at_session  # Manual cleanup when auto_cleanup: false
    redirect_to records_path
  else
    render :new
  end
end
```

### Multiple Forms Conflicting

**Problem:** Different forms sharing same session key

**Solution:** Use custom session keys:

```ruby
class Form1Controller < ApplicationController
  track_form_duration :started_at, session_key: :form1_start
end

class Form2Controller < ApplicationController
  track_form_duration :started_at, session_key: :form2_start
end
```

## Best Practices

### 1. Always Provide Fallback

```ruby
# Good: Fallback to current time if session expired
started_at = started_at_from_session || Time.zone.now

# Bad: Can cause validation errors
started_at = started_at_from_session
```

### 2. Let Auto-Cleanup Handle Session Management

```ruby
# With auto_cleanup: true (default) - no manual cleanup needed!
if @record.save
  redirect_to records_path  # Session cleaned on next form load
end
```

### 3. Disable Auto Features Only When Needed

```ruby
# Only disable if you need full manual control
track_form_duration :started_at, on: :new, auto_cleanup: false

def create
  started_at = started_at_from_session
  @record = Record.new(record_params.merge(started_at: started_at))
  
  if @record.save
    cleanup_started_at_session  # Manual cleanup required
    redirect_to records_path
  else
    render :new
  end
end
```

### 4. Set Appropriate Expiry Times

```ruby
# Short forms: 30 minutes - 1 hour
track_form_duration :started_at, expiry_time: 30.minutes

# Long forms: 2-4 hours
track_form_duration :started_at, expiry_time: 4.hours

# Multi-day forms: Use database instead of session
```

### 5. Use Bot Detection Wisely

```ruby
# Too aggressive (might block real users)
validate_min_duration: 2.seconds  # BAD

# Reasonable (blocks obvious bots)
validate_min_duration: 5.seconds  # GOOD

# Conservative (blocks only fastest bots)
validate_min_duration: 10.seconds  # BETTER
```

### 6. Log Form Completion Times

```ruby
class Article < ApplicationRecord
  include FormDurationTracker::ModelConcern
  
  track_form_duration :started_at
  
  after_create :log_metrics

  private

  def log_metrics
    duration = (created_at - started_at).to_i
    
    Rails.logger.info({
      event: "form_completed",
      model: self.class.name,
      duration_seconds: duration,
      user_id: author_id
    }.to_json)
  end
end
```

### 7. Handle Edge Cases

```ruby
def create
  started_at = started_at_from_session
  
  # Handle nil case
  if started_at.nil?
    Rails.logger.warn "Session expired for user #{current_user&.id}"
    flash.now[:notice] = "Your session expired, but we've restarted the timer"
    started_at = Time.zone.now
  end
  
  # ... rest of create action
end
```

### 8. Add Analytics

```ruby
# Track form abandonment
class ApplicationController < ActionController::Base
  after_action :track_form_abandonment, only: [:new]

  private

  def track_form_abandonment
    return unless session[:form_started_at]
    
    # Track that user loaded form but didn't submit
    Analytics.track_event("form_viewed", {
      controller: controller_name,
      action: action_name,
      user_id: current_user&.id
    })
  end
end
```

### 9. Test Thoroughly

```ruby
RSpec.describe ArticlesController, type: :controller do
  describe "POST #create" do
    it "handles expired session gracefully" do
      # Don't set session - simulate expired/missing session
      post :create, params: { article: valid_params }
      
      expect(response).to redirect_to(articles_path)
      expect(Article.last.started_at).to be_present
    end

    it "uses session timestamp when available" do
      session[:started_at_timestamp] = 10.minutes.ago.to_s
      
      post :create, params: { article: valid_params }
      
      expect(Article.last.started_at).to be_within(1.second).of(10.minutes.ago)
    end
  end
end
```

### 10. Consider Database Cleanup

```ruby
# Periodically clean up old records with analysis
class FormMetrics
  def self.analyze_and_cleanup
    # Analyze completion times
    avg_duration = Article.average("EXTRACT(EPOCH FROM (created_at - started_at))")
    
    Rails.logger.info "Average form completion: #{avg_duration} seconds"
    
    # Archive old records
    Article.where("created_at < ?", 1.year.ago).delete_all
  end
end

# Run in scheduled job (sidekiq, whenever, etc.)
```

## Need Help?

- 📖 [Full README](README.md)
- 💡 [Examples](examples/)
- 🐛 [Report Issues](https://github.com/indiecampers/form_duration_tracker/issues)
- 💬 [Discussions](https://github.com/indiecampers/form_duration_tracker/discussions)
