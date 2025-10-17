# FormDurationTracker - Project Summary

## Overview

FormDurationTracker is a production-ready Ruby gem that provides robust form duration tracking for Rails applications. It uses session-based timestamps to measure how long users take to complete forms, with built-in validations, expiry handling, and bot detection.

## Project Structure

```
form_duration_tracker/
├── lib/
│   ├── form_duration_tracker.rb              # Main entry point
│   └── form_duration_tracker/
│       ├── version.rb                         # Gem version (0.1.0)
│       ├── controller_concern.rb              # Controller concern for session management
│       └── model_concern.rb                   # Model concern for validations
├── spec/
│   ├── spec_helper.rb                         # RSpec configuration
│   ├── controller_concern_spec.rb             # Controller tests
│   ├── model_concern_spec.rb                  # Model tests
│   └── form_duration_tracker_spec.rb          # General tests
├── examples/
│   ├── simple_example.rb                      # Basic usage example
│   └── damage_audit_example.rb                # Complete real-world example
├── README.md                                   # Main documentation
├── USAGE_GUIDE.md                             # Comprehensive usage guide
├── CHANGELOG.md                               # Version history
├── form_duration_tracker.gemspec              # Gem specification
└── LICENSE.txt                                # MIT License

## Key Features

### Controller Concern (Session Management)
- **Session-based tracking** - Stores form start time in session
- **Automatic expiry** - Configurable timeout (default: 2 hours)
- **Graceful degradation** - Falls back to current time if session expires
- **Clean session management** - Auto-cleanup after form submission
- **Custom session keys** - Avoid conflicts between forms
- **Multiple tracking** - Track multiple timestamps simultaneously

### Model Concern (Validations)
- **Presence validation** - Ensures timestamp exists on create
- **Future prevention** - Rejects timestamps in the future
- **Update prevention** - Locks timestamp after creation
- **Max duration** - Validates form didn't take too long
- **Min duration** - Bot detection (rejects too-fast submissions)
- **Flexible configuration** - Enable only needed validations

## Generated Methods

### Controller Methods
```ruby
track_form_duration :started_at

# Generates:
initialize_started_at_session          # Set timestamp when form loads
started_at_from_session           # Retrieve timestamp (nil if expired)
cleanup_started_at_session            # Remove session data
preserve_started_at_in_session(value) # Update timestamp on error
started_at_session_config             # Get configuration
```

### Model Validations
```ruby
track_form_duration :started_at,
                    prevent_future: true,
                    prevent_update: true,
                    validate_max_duration: 2.hours,
                    validate_min_duration: 5.seconds

# Generates:
- Presence validation on :create
- validate_started_at_not_in_future (if prevent_future: true)
- prevent_started_at_change callback (if prevent_update: true)
- validate_started_at_max_duration (if validate_max_duration set)
- validate_started_at_min_duration (if validate_min_duration set)
```

## Usage Flow

1. **Form Load (GET /new)**
   ```ruby
   initialize_started_at_session
   # Stores Time.zone.now in session with expiry
   ```

2. **Form Submit (POST /create)**
   ```ruby
   started_at = started_at_from_session
   # Returns timestamp or nil if expired
   
   @record = Model.new(params.merge(started_at: started_at || Time.zone.now))
   ```

3. **Success Path**
   ```ruby
   if @record.save
     cleanup_started_at_session  # Clean up session
     redirect_to records_path
   ```

4. **Error Path**
   ```ruby
   else
     preserve_started_at_in_session(@record.started_at)  # Keep timestamp
     render :new
   ```

## Configuration Examples

### Minimal Setup (Just Tracking)
```ruby
# Model
track_form_duration :started_at

# Controller
track_form_duration :started_at
```

### Standard Setup (With Future Prevention)
```ruby
# Model
track_form_duration :started_at,
                    prevent_future: true,
                    prevent_update: true

# Controller
track_form_duration :started_at, expiry_time: 2.hours
```

### Full Featured (Bot Detection + Timeout)
```ruby
# Model
track_form_duration :started_at,
                    prevent_future: true,
                    prevent_update: true,
                    validate_max_duration: 2.hours,
                    validate_min_duration: 5.seconds

# Controller
track_form_duration :started_at, expiry_time: 2.hours
```

## Real-World Use Cases

1. **Survey/Questionnaire** - Track completion time, timeout after 1 hour
2. **Registration Forms** - Bot detection with min duration
3. **Multi-Step Forms** - Track from first step to final submission
4. **Audit Forms** - Compliance tracking with strict validations
5. **Comment/Feedback** - Simple tracking without strict rules

## Technical Details

### Dependencies
- Ruby >= 2.3
- Rails >= 4.2
- ActiveSupport
- Session storage enabled

### Session Keys
- Default: `{attribute_name}_timestamp`
- Expiry: `{attribute_name}_timestamp_expires_at`
- Customizable via `session_key` option

### Validation Timing
- **Presence, Future, Max/Min Duration**: Run on `:create`
- **Update Prevention**: Runs on `:update` via `before_validation` callback

### Error Messages
- Presence: "can't be blank"
- Future: "can't be in the future"
- Max duration: "form took too long to complete (max: X minutes)"
- Min duration: "form was completed too quickly (min: X seconds)"

## Testing

Comprehensive RSpec test suite included:

- **Controller Concern Specs**: Session initialization, retrieval, expiry, cleanup
- **Model Concern Specs**: All validations, update prevention
- **Integration Examples**: Real-world controller and model tests

Run tests:
```bash
bundle exec rspec
```

## Documentation

- **README.md** - Main documentation with quick start
- **USAGE_GUIDE.md** - Comprehensive guide with examples
- **examples/simple_example.rb** - Minimal implementation
- **examples/damage_audit_example.rb** - Complete real-world example

## Installation

Add to Gemfile:
```ruby
gem 'form_duration_tracker'
```

Or install directly:
```bash
gem install form_duration_tracker
```

## Benefits

1. **User Experience**
   - Track where users spend time
   - Identify difficult form sections
   - Optimize form length

2. **Security**
   - Bot detection via min duration
   - Prevent timestamp manipulation
   - Session expiry protection

3. **Analytics**
   - Average completion time
   - Abandonment rate analysis
   - User behavior insights

4. **Compliance**
   - Audit trail for forms
   - Immutable timestamps
   - Validation history

## Future Enhancements

Potential features for future versions:

- [ ] Section-level tracking (multi-step forms)
- [ ] Analytics dashboard integration
- [ ] Background job for cleanup
- [ ] ActiveRecord scopes for analysis
- [ ] I18n support for error messages
- [ ] Redis/Memcache session store support
- [ ] Form abandonment webhooks
- [ ] Real-time metrics API

## License

MIT License - See LICENSE.txt

## Credits

Created by Hugo Abreu for IndieCampers
GitHub: https://github.com/indiecampers/form_duration_tracker

## Support

- Report issues: GitHub Issues
- Contribute: Pull Requests welcome
- Questions: GitHub Discussions
