# FormDurationTracker - Quick Reference

One-page reference for the FormDurationTracker gem.

## Installation

```ruby
gem 'form_duration_tracker'
```

## Basic Setup

### 1. Migration
```bash
rails g migration AddStartedAtToPosts started_at:datetime
rails db:migrate
```

### 2. Model
```ruby
class Post < ApplicationRecord
  include FormDurationTracker::ModelConcern
  track_form_duration :started_at
end
```

### 3. Controller (Smart Auto-Params - Recommended)
```ruby
class PostsController < ApplicationController
  include FormDurationTracker::ControllerConcern
  track_form_duration :started_at, on: :new  # One line!

  def new
    @post = Post.new
  end

  def create
    @post = Post.new(post_params)  # started_at auto-injected!

    if @post.save
      redirect_to posts_path  # ✨ No cleanup needed - auto-cleanup enabled!
    else
      render :new  # No preserve needed - auto-injects again!
    end
  end
end
```

### 3. Controller (Manual - Legacy)
```ruby
class PostsController < ApplicationController
  include FormDurationTracker::ControllerConcern
  track_form_duration :started_at, on: :new, auto_params: false, auto_cleanup: false

  def new
    @post = Post.new
  end

  def create
    started_at = started_at_from_session
    @post = Post.new(params.merge(started_at: started_at || Time.zone.now))

    if @post.save
      cleanup_started_at_session  # Manual when auto_cleanup: false
      redirect_to posts_path
    else
      render :new
    end
  end
end
```

## Controller Options

```ruby
# Default (expirable: true, expiry_time: 2.hours)
track_form_duration :started_at

# Smart auto-params (inferred from on:)
track_form_duration :started_at, on: :new          # auto_params: [:create]
track_form_duration :started_at, on: :edit         # auto_params: [:update]
track_form_duration :started_at, on: [:new, :edit] # auto_params: [:create, :update]

# Custom auto-params actions
track_form_duration :started_at, on: :new, auto_params: [:create, :custom]

# Disable auto-params
track_form_duration :started_at, on: :new, auto_params: false

# Custom params key (nested resources)
track_form_duration :started_at, on: :new, param_key: :blog_post

# Custom expiry time
track_form_duration :started_at, expiry_time: 4.hours

# Disable expiry
track_form_duration :started_at, expirable: false

# Custom session key
track_form_duration :started_at, session_key: :my_custom_key
```

## Model Options

```ruby
# Basic
track_form_duration :started_at

# Prevent future timestamps
track_form_duration :started_at, prevent_future: true

# Prevent updates
track_form_duration :started_at, prevent_update: true

# Max duration (timeout)
track_form_duration :started_at, validate_max_duration: 2.hours

# Min duration (bot detection)
track_form_duration :started_at, validate_min_duration: 5.seconds

# All options
track_form_duration :started_at,
                    prevent_future: true,
                    prevent_update: true,
                    validate_max_duration: 2.hours,
                    validate_min_duration: 5.seconds
```

## Generated Methods

### Controller
```ruby
initialize_started_at_session          # Call in 'new' or use on: option (auto-cleans by default)
started_at_from_session               # Call in 'create' (no 'get_' prefix!)
cleanup_started_at_session            # Manual cleanup (rarely needed with auto_cleanup: true)
preserve_started_at_in_session(value) # Rarely needed
started_at_session_config             # Get config hash
inject_started_at_into_params         # Auto-inject into params (when auto_params enabled)
```

**✨ Auto-Features (enabled by default):**
- `auto_cleanup: true` - Session cleaned on next form load (skips edit/update)
- `auto_params: [inferred]` - Timestamp auto-injected into params
- No manual `cleanup_*` or `preserve_*` calls needed!

### Model
All validations run on `:create` except update prevention which runs on `:update`.

## Options Reference

### Controller Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `expirable` | Boolean | `true` | Enable session expiration |
| `expiry_time` | Duration | `2.hours` | Session expiry duration |
| `session_key` | Symbol/String | `"#{attr}_timestamp"` | Custom session key |
| `on` | Symbol/Array | `nil` | Auto-init with before_action |
| `auto_params` | Boolean/Array | Inferred | Auto-inject params (`:new` → `[:create]`) |
| `param_key` | Symbol | `controller.singularize` | Custom params key |
| `auto_cleanup` | Boolean | `true` | Auto-cleanup on next form load |

### Model Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `prevent_future` | Boolean | `false` | Reject future timestamps |
| `prevent_update` | Boolean | `false` | Lock after creation |
| `validate_max_duration` | Duration | `nil` | Maximum completion time |
| `validate_min_duration` | Duration | `nil` | Minimum completion time |

## Common Patterns

### Survey/Questionnaire (with Smart Auto-Params)
```ruby
# Model
track_form_duration :started_at,
                    prevent_future: true,
                    validate_max_duration: 1.hour

# Controller - ONE LINE!
track_form_duration :started_at, on: :new  # auto_params: [:create] inferred!
```

### Registration (Bot Prevention)
```ruby
# Model
track_form_duration :started_at,
                    prevent_future: true,
                    validate_min_duration: 10.seconds

# Controller - ONE LINE!
track_form_duration :started_at, on: :new
```

### Long Form (No Expiry)
```ruby
# Controller
track_form_duration :started_at, expirable: false, on: :new
```

### Edit Form (Update Action)
```ruby
# Controller - auto-injects on :update
track_form_duration :started_at, on: :edit  # auto_params: [:update]
```

## Error Messages

| Validation | Message |
|-----------|---------|
| Presence | "can't be blank" |
| Future | "can't be in the future" |
| Max duration | "form took too long to complete (max: X minutes)" |
| Min duration | "form was completed too quickly (min: X seconds)" |

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "can't be blank" error | Ensure auto-params is enabled OR manually merge `started_at` |
| Session keeps resetting | Check session store configuration |
| Timestamp changes on error | Usually not an issue with auto-params; session persists |
| Multiple forms conflicting | Use custom `session_key` |
| before_action not working | Ensure `on:` option is set |

## Best Practices

✅ **DO**
- Use smart auto-params with `on:` option (simplest approach!)
- Use `on:` option for automatic initialization
- Let `auto_cleanup: true` handle session cleanup automatically
- Use reasonable min duration (5-10 seconds)
- Set appropriate expiry times

❌ **DON'T**
- Don't manually merge params if auto-params is enabled
- Don't manually call `cleanup_*` if auto_cleanup is enabled (default)
- Don't call `preserve_*_in_session` unless truly needed (rare)
- Don't use aggressive min duration (< 3 seconds)
- Don't forget to initialize session (use `on:` option!)
- Don't use `expirable: true` for multi-day forms

## Testing

```ruby
# Controller test
it 'uses session timestamp' do
  session[:started_at_timestamp] = 10.minutes.ago.to_s
  post :create, params: valid_params
  expect(Post.last.started_at).to be_within(1.second).of(10.minutes.ago)
end

# Model test
it 'requires started_at' do
  post = Post.new
  expect(post).not_to be_valid
  expect(post.errors[:started_at]).to include("can't be blank")
end

# before_action test
it 'auto-initializes session' do
  get :new
  expect(session[:started_at_timestamp]).to be_present
end
```

## Key Differences from v0.0.x

- ✨ **NEW**: Smart CRUD inference with `auto_params` (automatically inferred from `on:`)
- ✨ **NEW**: Auto-params injection (eliminates manual `.merge()`)
- ✨ **NEW**: `expirable` option (default: `true`)
- ✨ **NEW**: `on` option for automatic `before_action` initialization
- ✨ **CHANGED**: Method renamed from `get_started_at_from_session` to `started_at_from_session`
- ✨ **IMPROVED**: Examples use `Post` model instead of `DamageAudit`

## Links

- [Full Documentation](README.md)
- [Usage Guide](USAGE_GUIDE.md)
- [Simple Example](examples/simple_example.rb)
- [Complete Example](examples/damage_audit_example.rb)

## Time Synchronization

The generator automatically syncs time settings:

```ruby
# Basic - auto-sync enabled
rails g form_duration_tracker:install Post started_at \
  --validate-max-duration 2.hours

# Result:
# Model: validate_max_duration: 2.hours
# Controller: expiry_time: 2.4.hours (auto-synced with 20% buffer)
# Output: "⏱️  Time Sync: expiry_time auto-set to 2.4.hours"
```

### Manual Override

```ruby
# Specify custom expiry_time
rails g form_duration_tracker:install Post started_at \
  --validate-max-duration 2.hours \
  --expiry-time 3.hours

# Result:
# Model: validate_max_duration: 2.hours
# Controller: expiry_time: 3.hours (manual)
# Output: "✓ Time settings are consistent"
```

### Buffer Calculation

| Max Duration | Buffer | Total Expiry |
|--------------|--------|--------------|
| 30 min       | 30 min | 1 hour       |
| 1 hour       | 30 min | 1.5 hours    |
| 2 hours      | 24 min | 2.4 hours    |
| 4 hours      | 48 min | 4.8 hours    |
| 8 hours      | 2 hours| 10 hours     |

Buffer = 20% of max duration (min: 30 min, max: 2 hours)

