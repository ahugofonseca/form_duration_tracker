# FormDurationTracker Generator - Feature Summary

## What We Built

### ⏱️ Automatic Time Synchronization (NEW!)

The generator intelligently syncs time settings between model and controller:
- Auto-calculates expiry_time from validate_max_duration
- Adds 20% buffer (min 30 min, max 2 hours)
- Warns about configuration mismatches
- Shows clear output of sync operations
- Supports manual override


A comprehensive Rails generator that automates the complete setup of form duration tracking in Rails applications.

## Generator Command

```bash
rails generate form_duration_tracker:install MODEL_NAME [ATTRIBUTE_NAME] [options]
```

## What It Does

### 1. Creates Migration
- Adds datetime column
- Optional database index (`--index`)
- Optional NOT NULL constraint (`--not-null`)
- Optional CHECK constraint for PostgreSQL (`--check-not-future`)
- Fully reversible migrations

### 2. Modifies Model
- Injects `FormDurationTracker::ModelConcern`
- Adds `track_form_duration` with options:
  - `--prevent-future` - Reject future timestamps
  - `--prevent-update` - Lock after creation
  - `--validate-max-duration` - Maximum time limit
  - `--validate-min-duration` - Bot detection

### 3. Modifies Controller  
- Injects `FormDurationTracker::ControllerConcern`
- Adds `track_form_duration` with options:
  - `--expirable` / `--no-expirable` - Session expiration
  - `--expiry-time` - Custom expiry duration
  - `--auto-initialize` - Automatic `before_action` setup
  - `--controller-name` - Custom controller path
- Optionally injects methods into actions (if not auto-init)

### 4. Generates Tests
- Auto-detects RSpec or Minitest
- Can force with `--test-framework`
- Generates both model and controller tests
- Tests all configured options

### 5. Provides Helpful Output
- Shows README with next steps
- Lists all generated/modified files
- Shows configuration summary

## Complete Example

```bash
rails g form_duration_tracker:install Post started_at \
  --index \
  --not-null \
  --prevent-future \
  --prevent-update \
  --validate-max-duration 2.hours \
  --validate-min-duration 5.seconds \
  --auto-initialize \
  --expiry-time 2.hours \
  --test-framework rspec

rails db:migrate
```

## Files Generated/Modified

```
✅ db/migrate/XXXXXX_add_started_at_to_posts.rb (NEW)
✅ app/models/post.rb (MODIFIED)
✅ app/controllers/posts_controller.rb (MODIFIED)
✅ spec/models/post_spec.rb (NEW)
✅ spec/controllers/posts_controller_spec.rb (NEW)
```

## Migration Example

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

## Model Example

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

## Controller Example

```ruby
class PostsController < ApplicationController
  include FormDurationTracker::ControllerConcern

  track_form_duration :started_at,
                      expirable: true,
                      expiry_time: 2.hours,
                      on: :new

  def new
    # Session auto-initialized by before_action
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

## Test Example (RSpec)

```ruby
RSpec.describe Post, type: :model do
  describe 'form duration tracking' do
    subject { build(:post) }

    it 'requires started_at on create' do
      subject.started_at = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:started_at]).to include("can't be blank")
    end

    it 'rejects future timestamps' do
      subject.started_at = 1.hour.from_now
      expect(subject).not_to be_valid
    end

    it 'prevents updating started_at after creation' do
      post = create(:post, started_at: 1.hour.ago)
      original = post.started_at
      post.update(started_at: Time.zone.now)
      expect(post.started_at).to eq(original)
    end
  end
end
```

## All Options

### Migration Options
- `--index` - Add database index
- `--not-null` - Add NOT NULL constraint
- `--check-not-future` - Add CHECK constraint (PostgreSQL)

### Model Options
- `--prevent-future` - Prevent future timestamps
- `--prevent-update` - Prevent updates after creation
- `--validate-max-duration DURATION` - Max time limit
- `--validate-min-duration DURATION` - Min time (bot detection)

### Controller Options
- `--controller-name NAME` - Custom controller
- `--expirable` / `--no-expirable` - Session expiration
- `--expiry-time DURATION` - Expiry duration
- `--auto-initialize` - Auto-init with before_action

### Test Options
- `--test-framework FRAMEWORK` - Force rspec or minitest

### Skip Options
- `--skip-migration` - Skip migration
- `--skip-model` - Skip model
- `--skip-controller` - Skip controller
- `--skip-tests` - Skip tests

## Use Cases

### Quick Survey
```bash
rails g form_duration_tracker:install Survey started_at \
  --validate-max-duration 1.hour \
  --validate-min-duration 10.seconds \
  --auto-initialize
```

### Registration Form
```bash
rails g form_duration_tracker:install User registration_started_at \
  --prevent-future \
  --prevent-update \
  --validate-min-duration 15.seconds
```

### Audit Form
```bash
rails g form_duration_tracker:install Audit started_at \
  --index \
  --not-null \
  --prevent-future \
  --prevent-update \
  --validate-max-duration 2.hours
```

### Multi-Day Application
```bash
rails g form_duration_tracker:install Application form_started_at \
  --no-expirable \
  --prevent-update
```

## Benefits

1. **Zero Boilerplate** - Complete setup in one command
2. **Type Safe** - Generates correct Rails migration versions
3. **Test Coverage** - Automatic test generation
4. **Flexible** - All options are opt-in
5. **Reversible** - Can undo with `rails destroy`
6. **Smart Detection** - Auto-detects test framework
7. **Well Documented** - Inline comments and README

## Files Created

```
lib/generators/form_duration_tracker/install/
├── install_generator.rb           # Main generator logic
├── USAGE                           # Help documentation
└── templates/
    ├── migration.rb.erb            # Migration template
    ├── README                      # Post-generation instructions
    ├── spec/
    │   ├── model_spec.rb.erb       # RSpec model tests
    │   └── controller_spec.rb.erb  # RSpec controller tests
    └── test/
        ├── model_test.rb.erb       # Minitest model tests
        └── controller_test.rb.erb  # Minitest controller tests
```

## Documentation Created

- `GENERATOR_GUIDE.md` - Comprehensive generator documentation
- Updated `README.md` - Quick start section added
- Updated `CHANGELOG.md` - Generator features documented
- Updated examples to use Post model

## What Makes It Special

1. **Model Injection** - Safely injects code into existing models
2. **Controller Injection** - Modifies controller actions intelligently  
3. **Test Generation** - Creates realistic, passing tests
4. **Constraint Support** - Database-level validation (PostgreSQL)
5. **Auto-Initialize** - Optional before_action setup
6. **Expirable Sessions** - Configurable session expiry
7. **Custom Attributes** - Not limited to `started_at`
8. **Multiple Models** - Can be run multiple times
9. **Skip Options** - Granular control over generation
10. **Help System** - Built-in usage documentation

## Result

A production-ready generator that reduces form duration tracking setup from 30+ minutes of manual work to a single command!
