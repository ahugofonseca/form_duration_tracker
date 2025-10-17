# FormDurationTracker

[![Coverage](https://img.shields.io/badge/coverage-89.34%25-brightgreen)](coverage)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.txt)

A robust Rails gem for tracking how long users take to fill out forms. This gem provides controller and model concerns to manage session-based timestamp tracking with customizable expiry times, validations, and update prevention.

## Features

- **Session-based timestamp tracking** - Store form start times in session storage
- **Optional expiry** - Enable/disable session expiration (default: enabled with 2 hours)
- **Automatic initialization** - Use `before_action` to auto-initialize sessions
- **Model validations** - Validate form completion times with built-in validators
- **Update prevention** - Prevent modification of tracked timestamps after creation
- **Future timestamp validation** - Ensure timestamps aren't set in the future
- **Duration limits** - Set minimum and maximum form completion times
- **Easy integration** - Simple concerns for controllers and models

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'form_duration_tracker'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install form_duration_tracker
```


## Quick Start with Generator

**✨ New Features:**
- **Automatic Time Synchronization** - Generator calculates optimal session expiry times
- **Smart CRUD Inference** - Automatically infers auto-params actions from `on:` option
- **Auto-Params Injection** - Eliminates manual `.merge()` in controller actions

The fastest way to set up form duration tracking is using the built-in generator:

```bash
# Basic setup with smart inference
rails generate form_duration_tracker:install Post started_at --auto-initialize
rails db:migrate
```

This automatically:
- ✅ Creates migration with `started_at` column
- ✅ Adds concern to your Post model
- ✅ Adds concern to your PostsController
- ✅ Generates test files (RSpec or Minitest)
- ✅ Infers auto-params injection from `--auto-initialize`

**Your controller becomes one line:**
```ruby
track_form_duration :started_at, on: :new  # That's it!
```

**Your actions stay clean:**
```ruby
def create
  @post = Post.new(post_params)  # started_at auto-injected!
  # ...
end
```

### Generator with Options

```bash
# Full-featured setup
rails g form_duration_tracker:install Post started_at \
  --index \
  --prevent-future \
  --prevent-update \
  --validate-max-duration 2.hours \
  --validate-min-duration 5.seconds \
  --auto-initialize

rails db:migrate
```

**See [Generator Guide](GENERATOR_GUIDE.md) for complete documentation.**

## Manual Setup

If you prefer manual setup or need more control:

## Usage

### Controller Concern

Include the `FormDurationTracker::ControllerConcern` in your controller and configure tracking:

#### Manual Initialization

```ruby
class PostsController < ApplicationController
  include FormDurationTracker::ControllerConcern

  # Track the 'started_at' attribute with default options
  track_form_duration :started_at

  def new
    # Manually initialize the session timestamp
    initialize_started_at_session
    @post = Post.new
  end

  def create
    # Retrieve the timestamp from session
    started_at = started_at_from_session

    @post = Post.new(post_params.merge(started_at: started_at || Time.zone.now))

    if @post.save
      cleanup_started_at_session
      redirect_to posts_path
    else
      preserve_started_at_in_session(@post.started_at)
      render :new
    end
  end
end
```

#### Automatic Initialization with Smart Auto-Params (Recommended)

```ruby
class PostsController < ApplicationController
  include FormDurationTracker::ControllerConcern

  # Smart inference: on: :new → auto-injects params on :create
  track_form_duration :started_at, on: :new

  def new
    @post = Post.new
  end

  def create
    # started_at automatically injected into params!
    @post = Post.new(post_params)

    if @post.save
      redirect_to posts_path  # ✨ No cleanup needed - auto-cleanup enabled by default!
    else
      render :new
    end
  end
end
```

**✨ Auto-Cleanup Feature:**  
By default, `auto_cleanup: true` automatically cleans up session data when a new form is loaded (on next `initialize_*_session` call). This means:
- ✅ No manual `cleanup_*_session` calls needed
- ✅ Session is cleaned before each new form
- ✅ Prevents timestamp reuse across multiple records
- ✅ Safe for edit flows (doesn't cleanup on edit actions)

**⚠️ Note on `preserve_started_at_in_session`:**  
With auto-params and auto-cleanup enabled, `preserve_started_at_in_session` is **rarely needed**. Only use it if:
- Your validation logic modifies the `started_at` value
- You need to extend the expiry timer for long validation sessions
- You disabled auto-cleanup with `auto_cleanup: false`

**Inference Rules:**
- `on: :new` → auto-injects params on `:create`
- `on: :edit` → auto-injects params on `:update`
- `on: [:new, :edit]` → auto-injects on both `:create` and `:update`

#### Manual Initialization (Legacy - Full Control)

```ruby
class PostsController < ApplicationController
  include FormDurationTracker::ControllerConcern

  # Disable auto features if you need full manual control
  track_form_duration :started_at, on: :new, auto_params: false, auto_cleanup: false

  def new
    @post = Post.new
  end

  def create
    started_at = started_at_from_session

    @post = Post.new(post_params.merge(started_at: started_at || Time.zone.now))

    if @post.save
      cleanup_started_at_session  # Manual cleanup when auto_cleanup: false
      redirect_to posts_path
    else
      render :new
    end
  end
end
```

#### Custom Options

```ruby
class PostsController < ApplicationController
  include FormDurationTracker::ControllerConcern

  # With custom expiry time
  track_form_duration :started_at, expiry_time: 4.hours

  # Disable expiry (session never expires)
  track_form_duration :started_at, expirable: false

  # With custom session key
  track_form_duration :started_at, 
                      session_key: :post_form_start,
                      expiry_time: 3.hours

  # With automatic initialization and smart auto-params
  track_form_duration :started_at,
                      on: [:new, :edit],
                      expiry_time: 1.hour

  # Custom auto-params actions
  track_form_duration :started_at,
                      on: :new,
                      auto_params: [:create, :custom_action]

  # Custom params key (for nested resources)
  track_form_duration :started_at,
                      on: :new,
                      param_key: :blog_post
end
```

#### Generated Methods

When you call `track_form_duration :started_at`, the following methods are generated:

- `initialize_started_at_session` - Set timestamp in session when form loads (auto-cleans previous sessions by default)
- `started_at_from_session` - Retrieve timestamp from session (nil if expired)
- `cleanup_started_at_session` - Manually remove timestamp from session (rarely needed with `auto_cleanup: true`)
- `preserve_started_at_in_session(value)` - Update timestamp and reset expiry timer (rarely needed)
- `started_at_session_config` - Get configuration hash
- `inject_started_at_into_params` - Auto-inject timestamp into params (when `auto_params` enabled)

#### Controller Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `expirable` | Boolean | `true` | Enable session expiration |
| `expiry_time` | Duration | `2.hours` or auto-synced | Session expiration duration |
| `session_key` | String/Symbol | `"#{attribute}_timestamp"` | Custom session key |
| `on` | Symbol/Array | `nil` | Actions for automatic initialization |
| `auto_params` | Boolean/Array | Inferred from `on` | Auto-inject params (inferred: `on: :new` → `[:create]`) |
| `param_key` | Symbol | `controller_name.singularize` | Custom params key for nested resources |
| `auto_cleanup` | Boolean | `true` | Auto-cleanup session on next form load (skips edit/update actions) |

### Model Concern

Include the `FormDurationTracker::ModelConcern` in your model:

```ruby
class Post < ApplicationRecord
  include FormDurationTracker::ModelConcern

  # Basic tracking with presence validation on create
  track_form_duration :started_at

  # With all options enabled
  track_form_duration :started_at,
                      prevent_future: true,      # Can't be in the future
                      prevent_update: true,      # Can't be changed after creation
                      validate_max_duration: 4.hours,  # Max 4 hours to complete
                      validate_min_duration: 5.seconds # Min 5 seconds to complete
end
```

#### Model Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `prevent_future` | Boolean | `false` | Validates timestamp is not in the future |
| `prevent_update` | Boolean | `false` | Prevents changing timestamp after record creation |
| `validate_max_duration` | Duration | `nil` | Maximum time allowed to complete form |
| `validate_min_duration` | Duration | `nil` | Minimum time required to complete form (bot detection) |

#### Generated Validations

The concern automatically generates:

1. **Presence validation** - Always added on `:create`
2. **Future timestamp validation** - If `prevent_future: true`
3. **Update prevention** - If `prevent_update: true` (via `before_validation` callback)
4. **Max duration validation** - If `validate_max_duration` is set
5. **Min duration validation** - If `validate_min_duration` is set

## Complete Example

### Migration

```ruby
class AddStartedAtToPosts < ActiveRecord::Migration[4.2]
  def change
    add_column :posts, :started_at, :datetime
    add_index :posts, :started_at
  end
end
```

### Model

```ruby
class Post < ApplicationRecord
  include FormDurationTracker::ModelConcern

  track_form_duration :started_at,
                      prevent_future: true,
                      prevent_update: true,
                      validate_max_duration: 2.hours,
                      validate_min_duration: 3.seconds

  validates :title, :content, presence: true
  belongs_to :author, class_name: 'User'
end
```

### Controller

```ruby
class PostsController < ApplicationController
  include FormDurationTracker::ControllerConcern

  # Automatic session initialization
  track_form_duration :started_at, 
                      on: :new,
                      expiry_time: 2.hours

  def new
    @post = Post.new
  end

  def create
    started_at = started_at_from_session

    @post = Post.new(
      post_params.merge(
        started_at: started_at || Time.zone.now,
        author_id: current_user.id
      )
    )

    if @post.save
      cleanup_started_at_session
      redirect_to @post, notice: 'Post created successfully'
    else
      preserve_started_at_in_session(@post.started_at)
      flash.now[:alert] = 'Please correct the errors below'
      render :new
    end
  end

  private

  def post_params
    params.require(:post).permit(:title, :content)
  end
end
```

### View (Optional Hidden Field)

```erb
<%= form_for @post do |f| %>
  <%= f.hidden_field :started_at %>
  
  <%= f.label :title %>
  <%= f.text_field :title, class: 'form-control' %>

  <%= f.label :content %>
  <%= f.text_area :content, class: 'form-control' %>

  <%= f.submit 'Create Post', class: 'btn btn-primary' %>
<% end %>
```

## Advanced Usage

### Disable Session Expiry

For long forms where users might take days:

```ruby
class ApplicationsController < ApplicationController
  include FormDurationTracker::ControllerConcern

  # Session never expires
  track_form_duration :started_at, expirable: false
end
```

### Multiple Tracked Attributes

Track multiple form timestamps in the same controller/model:

```ruby
class SurveyController < ApplicationController
  include FormDurationTracker::ControllerConcern

  track_form_duration :form_started_at, on: :new, expiry_time: 1.hour
  track_form_duration :section_started_at, expiry_time: 30.minutes
end

class Survey < ApplicationRecord
  include FormDurationTracker::ModelConcern

  track_form_duration :form_started_at, prevent_update: true
  track_form_duration :section_started_at, validate_max_duration: 30.minutes
end
```

### Custom Session Keys

Use custom session keys to avoid conflicts:

```ruby
track_form_duration :started_at, 
                    session_key: :post_form_start,
                    expiry_time: 3.hours,
                    on: :new
```

### Bot Detection

Use minimum duration to detect bot submissions:

```ruby
class Post < ApplicationRecord
  include FormDurationTracker::ModelConcern

  track_form_duration :started_at,
                      validate_min_duration: 5.seconds
end
```

This will reject forms submitted faster than 5 seconds.

### Timeout Handling

Handle cases where users exceed the maximum allowed time:

```ruby
class Post < ApplicationRecord
  include FormDurationTracker::ModelConcern

  track_form_duration :started_at,
                      validate_max_duration: 2.hours
end
```

Users who take longer than 2 hours will receive a validation error.

## How It Works

### Session Flow

1. **Form Load** - When user visits `new` action:
   - If `on: :new` specified, session automatically initialized via `before_action`
   - Otherwise, manually call `initialize_started_at_session`
   - Stores `Time.zone.now` in session
   - If `expirable: true`, also stores expiry time (default: 2 hours from now)

2. **Form Submit** - When user submits form:
   - `started_at_from_session` retrieves timestamp
   - Returns `nil` if session expired (when `expirable: true`)
   - Timestamp is merged into model attributes
   - If validation fails, `preserve_started_at_in_session` keeps the same timestamp

3. **Success** - When record saves:
   - `cleanup_started_at_session` removes session data
   - Timestamp is permanently stored in database

4. **Update Prevention** - When record updated:
   - `before_validation` callback on `:update` restores original `started_at` if changed

### Model Validations

The model concern adds validations that run on `:create`:

- **Presence** - Ensures timestamp exists
- **Future check** - Ensures timestamp isn't in the future (if enabled)
- **Duration limits** - Validates min/max completion time (if enabled)

And a `before_validation` callback on `:update`:

- **Update prevention** - Restores original value if changed (if enabled)

## Session Expiry

When `expirable: true` (default):
- Sessions automatically expire after configured time (default: 2 hours)
- If a user returns after expiry, `started_at_from_session` returns `nil`
- Fallback to current time ensures forms can still be submitted: `started_at || Time.zone.now`

When `expirable: false`:
- Sessions never expire
- Useful for multi-day forms or applications
- No expiry timestamp stored in session

## Error Messages

Default error messages:

- Presence: `"can't be blank"`
- Future timestamp: `"can't be in the future"`
- Max duration: `"form took too long to complete (max: X minutes)"`
- Min duration: `"form was completed too quickly (min: X seconds)"`

Customize error messages using Rails I18n:

```yaml
# config/locales/en.yml
en:
  activerecord:
    errors:
      models:
        post:
          attributes:
            started_at:
              blank: "Form session expired. Please try again."
              in_future: "Invalid form timestamp."
```

## Testing

### Controller Tests

```ruby
RSpec.describe PostsController, type: :controller do
  describe 'POST #create' do
    it 'uses session timestamp' do
      session[:started_at_timestamp] = 10.minutes.ago.to_s
      
      post :create, params: { post: { title: 'Test', content: 'Content' } }
      
      expect(Post.last.started_at).to be_within(1.second).of(10.minutes.ago)
    end

    it 'cleans up session on success' do
      post :create, params: { post: valid_params }
      
      expect(session[:started_at_timestamp]).to be_nil
    end
  end

  describe 'before_action integration' do
    it 'auto-initializes session on new action' do
      get :new
      
      expect(session[:started_at_timestamp]).to be_present
    end
  end
end
```

### Model Tests

```ruby
RSpec.describe Post, type: :model do
  describe 'validations' do
    it 'requires started_at on create' do
      post = Post.new(title: 'Test', content: 'Content')
      expect(post).not_to be_valid
      expect(post.errors[:started_at]).to include("can't be blank")
    end

    it 'rejects future timestamps' do
      post = Post.new(started_at: 1.hour.from_now)
      expect(post).not_to be_valid
      expect(post.errors[:started_at]).to include("can't be in the future")
    end

    it 'prevents updating started_at' do
      post = create(:post, started_at: 1.hour.ago)
      post.update(started_at: Time.zone.now)
      
      expect(post.started_at).to be_within(1.second).of(1.hour.ago)
    end
  end
end
```

## Requirements

- Ruby >= 2.3
- Rails >= 4.2
- ActiveSupport
- Session storage enabled

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### Test Coverage

This gem uses [SimpleCov](https://github.com/simplecov-ruby/simplecov) to track test coverage. Current coverage: **89.34%**

To generate a coverage report:

```bash
bundle exec rspec
open coverage/index.html  # View detailed coverage report
```

Coverage reports are generated in the `coverage/` directory and are excluded from version control.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/indiecampers/form_duration_tracker.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Credits

Created by Hugo Abreu for IndieCampers.
