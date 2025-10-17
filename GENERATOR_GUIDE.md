# FormDurationTracker Generator Guide

Complete guide for using the FormDurationTracker generator to automatically set up form duration tracking in your Rails application.

## Overview

The `form_duration_tracker:install` generator automatically:

- ✅ Creates database migration with optional constraints
- ✅ Injects concern into your model with validations
- ✅ Injects concern into your controller with session handling
- ✅ Generates test files (RSpec or Minitest)
- ✅ Provides helpful README with next steps

## Installation

First, add the gem to your Gemfile and run bundle:

```bash
gem 'form_duration_tracker'
bundle install
```

## Basic Usage

```bash
rails generate form_duration_tracker:install Post started_at
```

This creates:
- Migration: `db/migrate/XXXXXX_add_started_at_to_posts.rb`
- Modifies: `app/models/post.rb`
- Modifies: `app/controllers/posts_controller.rb`
- Creates: Test files (RSpec or Minitest)

Then run:
```bash
rails db:migrate
```

## Command Format

```bash
rails generate form_duration_tracker:install MODEL_NAME [ATTRIBUTE_NAME] [options]
```

**Arguments:**
- `MODEL_NAME` (required) - Name of your model (e.g., Post, Article, Survey)
- `ATTRIBUTE_NAME` (optional) - Name of timestamp attribute (default: `started_at`)

## Options Reference

### Migration Options

| Option | Description | Example |
|--------|-------------|---------|
| `--index` | Add database index | `--index` |
| `--not-null` | Add NOT NULL constraint | `--not-null` |
| `--check-not-future` | Add CHECK constraint (PostgreSQL) | `--check-not-future` |

### Model Options

| Option | Type | Description | Example |
|--------|------|-------------|---------|
| `--prevent-future` | Boolean | Reject future timestamps | `--prevent-future` |
| `--prevent-update` | Boolean | Lock timestamp after creation | `--prevent-update` |
| `--validate-max-duration` | String | Maximum completion time | `--validate-max-duration 2.hours` |
| `--validate-min-duration` | String | Minimum completion time | `--validate-min-duration 5.seconds` |

### Controller Options

| Option | Type | Default | Description | Example |
|--------|------|---------|-------------|---------|
| `--controller-name` | String | `ModelPlural` | Custom controller name | `--controller-name Admin::PostsController` |
| `--expirable` | Boolean | `true` | Enable session expiration | `--expirable` / `--no-expirable` |
| `--expiry-time` | String | `2.hours` | Session expiry duration | `--expiry-time 4.hours` |
| `--auto-initialize` | Boolean | `false` | Auto-init with before_action | `--auto-initialize` |

### Test Options

| Option | Type | Description | Example |
|--------|------|-------------|---------|
| `--test-framework` | String | Auto-detect | Force test framework | `--test-framework rspec` |

### Skip Options

| Option | Description |
|--------|-------------|
| `--skip-migration` | Skip migration generation |
| `--skip-model` | Skip model modification |
| `--skip-controller` | Skip controller modification |
| `--skip-tests` | Skip test file generation |


## Automatic Time Synchronization

**New Feature!** The generator automatically synchronizes time settings between model and controller to prevent configuration errors.

### How It Works

When you specify `--validate-max-duration` for the model, the generator:

1. **Calculates optimal expiry time** - Adds 20% buffer (min 30 min, max 2 hours)
2. **Validates consistency** - Checks for mismatches
3. **Warns about issues** - Alerts you to potential problems
4. **Auto-syncs by default** - Sets controller expiry_time automatically

### Example: Auto-Sync

```bash
rails g form_duration_tracker:install Post started_at \
  --validate-max-duration 2.hours \
  --auto-initialize

# Output:
# ⏱️  Time Sync: expiry_time auto-set to 2.4.hours (2.hours + buffer)

# Result:
# Model: validate_max_duration: 2.hours
# Controller: expiry_time: 2.4.hours (automatically calculated)
```

### Manual Override

You can still override the expiry time:

```bash
rails g form_duration_tracker:install Post started_at \
  --validate-max-duration 2.hours \
  --expiry-time 3.hours

# Output:
# ✓ Time settings are consistent

# Result:
# Model: validate_max_duration: 2.hours
# Controller: expiry_time: 3.hours (manually specified)
```

### Warning for Mismatches

If expiry_time is less than max_duration:

```bash
rails g form_duration_tracker:install Post started_at \
  --validate-max-duration 2.hours \
  --expiry-time 1.hour

# Output:
# ⚠️  Time Mismatch Detected!
#   Controller session expires: 1.hour
#   Model accepts forms up to: 2.hours
#   Problem: Sessions expire BEFORE validation limit!
#   Recommendation: Use --expiry-time 2.4.hours
```

### Buffer Calculation

| Max Duration | Buffer (20%) | Total Expiry |
|--------------|--------------|---------------|
| 30 minutes   | 30 minutes*  | 1 hour        |
| 1 hour       | 30 minutes*  | 1.5 hours     |
| 2 hours      | 24 minutes   | 2.4 hours     |
| 4 hours      | 48 minutes   | 4.8 hours     |
| 8 hours      | 2 hours**    | 10 hours      |

*Minimum buffer: 30 minutes  
**Maximum buffer: 2 hours

## Examples

### Example 1: Basic Setup

```bash
rails g form_duration_tracker:install Post started_at
```

**Generated:**
- Migration adds `started_at` column
- Model gets basic presence validation
- Controller gets manual session initialization
- Test files for both model and controller

### Example 2: With Database Constraints

```bash
rails g form_duration_tracker:install Post started_at \
  --index \
  --not-null \
  --check-not-future
```

**Migration includes:**
```ruby
class AddStartedAtToPosts < ActiveRecord::Migration[5.0]
  def change
    add_column :posts, :started_at, :datetime
    add_index :posts, :started_at
    change_column_null :posts, :started_at, false
    
    reversible do |dir|
      dir.up do
        execute <<-SQL
          ALTER TABLE posts
          ADD CONSTRAINT posts_started_at_not_future
          CHECK (started_at <= CURRENT_TIMESTAMP)
        SQL
      end
      dir.down do
        execute "ALTER TABLE posts DROP CONSTRAINT IF EXISTS posts_started_at_not_future"
      end
    end
  end
end
```

### Example 3: Full Model Validations

```bash
rails g form_duration_tracker:install Post started_at \
  --prevent-future \
  --prevent-update \
  --validate-max-duration 2.hours \
  --validate-min-duration 5.seconds
```

**Model includes:**
```ruby
class Post < ApplicationRecord
  include FormDurationTracker::ModelConcern

  track_form_duration :started_at,
                      prevent_future: true,
                      prevent_update: true,
                      validate_max_duration: 2.hours,
                      validate_min_duration: 5.seconds
end
```

### Example 4: Auto-Initialize with before_action

```bash
rails g form_duration_tracker:install Post started_at \
  --auto-initialize \
  --expiry-time 1.hour
```

**Controller includes:**
```ruby
class PostsController < ApplicationController
  include FormDurationTracker::ControllerConcern

  track_form_duration :started_at,
                      expirable: true,
                      expiry_time: 1.hour,
                      on: :new

  def new
    # Session automatically initialized by before_action
    @post = Post.new
  end

  def create
    started_at = started_at_from_session
    @post = Post.new(post_params.merge(started_at: started_at || Time.zone.now))

    if @post.save
      cleanup_started_at_session
      redirect_to @post
    else
      preserve_started_at_in_session(@post.started_at)
      render :new
    end
  end
end
```

### Example 5: Long Form (No Expiry)

```bash
rails g form_duration_tracker:install Application form_started_at \
  --no-expirable \
  --auto-initialize \
  --prevent-update
```

**Controller includes:**
```ruby
track_form_duration :form_started_at,
                    expirable: false,
                    on: :new
```

Session never expires - perfect for multi-day applications.

### Example 6: Custom Controller Name

```bash
rails g form_duration_tracker:install Post started_at \
  --controller-name Admin::PostsController \
  --auto-initialize
```

Modifies `app/controllers/admin/posts_controller.rb` instead of `app/controllers/posts_controller.rb`.

### Example 7: Bot Detection Survey

```bash
rails g form_duration_tracker:install Survey started_at \
  --validate-min-duration 10.seconds \
  --validate-max-duration 30.minutes \
  --auto-initialize
```

Rejects surveys completed in less than 10 seconds (bots) or more than 30 minutes (timeouts).

### Example 8: Migration Only

```bash
rails g form_duration_tracker:install Post started_at \
  --index \
  --skip-model \
  --skip-controller \
  --skip-tests
```

Only creates the migration file.

### Example 9: Model Only

```bash
rails g form_duration_tracker:install Post started_at \
  --prevent-future \
  --prevent-update \
  --skip-migration \
  --skip-controller \
  --skip-tests
```

Only modifies the model file.

### Example 10: Force RSpec

```bash
rails g form_duration_tracker:install Post started_at \
  --test-framework rspec \
  --prevent-future
```

Forces RSpec even if Minitest is detected.

## Generated Files

### Migration

**Location:** `db/migrate/XXXXXX_add_started_at_to_posts.rb`

**Contains:**
- Column addition
- Optional index
- Optional NOT NULL constraint
- Optional CHECK constraint (reversible)

### Model

**Location:** `app/models/post.rb`

**Adds:**
```ruby
include FormDurationTracker::ModelConcern

track_form_duration :started_at,
                    prevent_future: true,      # If --prevent-future
                    prevent_update: true,      # If --prevent-update
                    validate_max_duration: 2.hours,  # If specified
                    validate_min_duration: 5.seconds # If specified
```

### Controller

**Location:** `app/controllers/posts_controller.rb`

**Adds:**
```ruby
include FormDurationTracker::ControllerConcern

track_form_duration :started_at,
                    expirable: true,        # If --expirable (default)
                    expiry_time: 2.hours,   # If specified
                    on: :new                # If --auto-initialize
```

**If NOT auto-initialize, also modifies:**
- `new` action: Adds `initialize_started_at_session`
- `create` action: Adds session retrieval and cleanup logic

### Tests (RSpec)

**Location:** 
- `spec/models/post_spec.rb`
- `spec/controllers/posts_controller_spec.rb`

**Tests:**
- Presence validation
- Future timestamp rejection (if enabled)
- Duration limits (if enabled)
- Update prevention (if enabled)
- Session initialization
- Session cleanup
- Session expiry (if enabled)
- Error handling

### Tests (Minitest)

**Location:**
- `test/models/post_test.rb`
- `test/controllers/posts_controller_test.rb`

**Tests:** Same coverage as RSpec

## Workflow

### Step 1: Generate

```bash
rails g form_duration_tracker:install Post started_at \
  --index \
  --prevent-future \
  --prevent-update \
  --auto-initialize
```

### Step 2: Run Migration

```bash
rails db:migrate
```

### Step 3: Review Generated Files

Check:
- `app/models/post.rb`
- `app/controllers/posts_controller.rb`
- `spec/` or `test/` directories

### Step 4: Customize (Optional)

Add any additional validations or logic to your model/controller.

### Step 5: Run Tests

```bash
# RSpec
bundle exec rspec spec/models/post_spec.rb
bundle exec rspec spec/controllers/posts_controller_spec.rb

# Minitest
rails test test/models/post_test.rb
rails test test/controllers/posts_controller_test.rb
```

### Step 6: Add Form Field (Optional)

Add hidden field to your form:

```erb
<%= form_for @post do |f| %>
  <%= f.hidden_field :started_at %>
  
  <%= f.text_field :title %>
  <%= f.text_area :content %>
  <%= f.submit %>
<% end %>
```

## Common Patterns

### Pattern 1: Quick Survey

```bash
rails g form_duration_tracker:install Survey started_at \
  --index \
  --prevent-future \
  --validate-max-duration 1.hour \
  --validate-min-duration 10.seconds \
  --auto-initialize \
  --expiry-time 1.hour
```

### Pattern 2: Registration Form

```bash
rails g form_duration_tracker:install User registration_started_at \
  --prevent-future \
  --prevent-update \
  --validate-min-duration 15.seconds \
  --auto-initialize
```

### Pattern 3: Audit Form

```bash
rails g form_duration_tracker:install Audit started_at \
  --index \
  --not-null \
  --prevent-future \
  --prevent-update \
  --validate-max-duration 2.hours \
  --auto-initialize
```

### Pattern 4: Multi-Day Application

```bash
rails g form_duration_tracker:install Application form_started_at \
  --no-expirable \
  --prevent-update \
  --auto-initialize
```

## Troubleshooting

### Generator Not Found

```bash
# Error: Could not find generator 'form_duration_tracker:install'
```

**Solution:**
1. Ensure gem is installed: `bundle install`
2. Restart Rails console/server
3. Check gem is in Gemfile

### Model File Not Found

```bash
# Error: Model file not found: app/models/post.rb
```

**Solution:**
Create the model first:
```bash
rails g model Post title:string content:text
```

Then run the generator.

### Controller File Not Found

```bash
# Error: Controller file not found: app/controllers/posts_controller.rb
```

**Solution:**
Either:
1. Create the controller first: `rails g controller Posts`
2. Use `--skip-controller` flag
3. Specify correct controller: `--controller-name Admin::PostsController`

### Test Framework Not Detected

```bash
# Warning: No test framework detected
```

**Solution:**
Specify test framework explicitly:
```bash
rails g form_duration_tracker:install Post started_at --test-framework rspec
```

## Advanced Usage

### Multiple Timestamps

Track different timestamps in the same model:

```bash
# First timestamp
rails g form_duration_tracker:install Post form_started_at \
  --auto-initialize

# Second timestamp (skip migration)
rails g form_duration_tracker:install Post section_started_at \
  --skip-migration \
  --controller-name Admin::PostsController
```

### Dry Run

See what would be generated without making changes:

```bash
rails g form_duration_tracker:install Post started_at --pretend
```

### Undo Generation

Rollback the generator:

```bash
rails destroy form_duration_tracker:install Post started_at
```

Note: You'll need to manually remove injected code from models/controllers.

## Tips & Best Practices

1. **Always use `--index`** for better query performance
2. **Use `--prevent-update`** for audit compliance
3. **Use `--auto-initialize`** to reduce boilerplate
4. **Use `--validate-min-duration`** for bot detection
5. **Use `--no-expirable`** for multi-day forms
6. **Match `expiry_time` with `validate_max_duration`**

## Need Help?

```bash
# Show generator help
rails g form_duration_tracker:install --help

# View all options
cat lib/generators/form_duration_tracker/install/USAGE
```

## Links

- [Main README](README.md)
- [Quick Reference](QUICK_REFERENCE.md)
- [Usage Guide](USAGE_GUIDE.md)
