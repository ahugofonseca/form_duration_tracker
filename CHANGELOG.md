# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-10-10

### Added
- Initial release of FormDurationTracker
- Controller concern for session-based timestamp tracking
- Model concern for validation and update prevention
- `expirable` option to enable/disable session expiration (default: `true` with 2 hours)
- `on` option for automatic session initialization via `before_action`
- **✨ Smart CRUD Inference with Auto-Params** (NEW!):
  - Automatically infers `auto_params` actions from `on:` option
  - `on: :new` → auto-injects params on `:create`
  - `on: :edit` → auto-injects params on `:update`
  - `on: [:new, :edit]` → auto-injects on both actions
  - Eliminates manual `.merge()` in controller actions
  - Optional and fully overridable
  - One-line controller configuration!
- **✨ Auto-Cleanup Feature** (NEW!):
  - `auto_cleanup: true` (default) automatically cleans session on next form load
  - Eliminates manual `cleanup_*_session` calls in controllers
  - Smart detection: skips cleanup on edit/update actions
  - Prevents timestamp reuse across multiple records
  - Zero-boilerplate controller actions!
- **Automatic Time Synchronization** between model and controller:
  - Smart expiry_time calculation based on validate_max_duration
  - 20% buffer added automatically (min 30 min, max 2 hours)
  - Validation warnings for time mismatches
  - Auto-sync output showing calculated values
  - Manual override support
- **Rails Generator** for automatic setup:
  - `rails g form_duration_tracker:install` command
  - Automatic migration generation with optional constraints
  - Automatic model injection with configurable validations
  - Automatic controller injection with session handling
  - Test file generation (RSpec and Minitest support)
  - Auto-detects test framework
  - Comprehensive options for customization
  - Smart time synchronization with helpful output
- Database constraint options:
  - `--index` for database index
  - `--not-null` for NOT NULL constraint
  - `--check-not-future` for CHECK constraint (PostgreSQL)
- Customizable session expiry times
- Prevent future timestamps validation
- Prevent update after creation
- Min/max duration validations for form completion
- Comprehensive documentation and examples
- RSpec test suite with controller and model specs
- Examples using `Post` model for clarity

### Changed
- Method naming: Removed `get_` prefix from all methods
  - `get_started_at_from_session` → `started_at_from_session`
  - Updated all documentation to reflect new naming
- Examples now use `Post` model instead of `DamageAudit` for better universality
- Generator automatically syncs time settings to prevent configuration errors
- **Clarified `preserve_*_in_session` usage**: With auto-params enabled, this method is rarely needed. The session timestamp persists between validation attempts and is automatically re-injected. Only use `preserve_*` if your validation logic modifies the timestamp or you need to extend the expiry timer.
- **Eliminated need for manual `cleanup_*_session` calls**: With `auto_cleanup: true` (default), session is automatically cleaned on next form load. Manual cleanup still available by setting `auto_cleanup: false`.
- **Smart edit action handling**: Auto-cleanup skips edit/update actions to prevent overwriting existing timestamps.

### Features

#### Time Synchronization (NEW!)
- Automatic calculation of optimal expiry_time
- 20% buffer added to validate_max_duration
- Warnings for time mismatches
- Visual feedback on sync operations
- Manual override supported

#### Generator Options
- `--index` - Add database index
- `--not-null` - Add NOT NULL constraint
- `--check-not-future` - Add CHECK constraint for future timestamps
- `--prevent-future` - Add model validation to prevent future timestamps
- `--prevent-update` - Lock timestamp after creation
- `--validate-max-duration` - Set maximum form completion time (auto-syncs expiry_time!)
- `--validate-min-duration` - Set minimum form completion time (bot detection)
- `--auto-initialize` - Auto-initialize session with before_action (enables auto-params by default)
- `--auto-params` - Enable/disable auto-params injection (inferred by default)
- `--auto-params-on` - Specify custom actions for auto-params
- `--param-key` - Custom params key for nested resources
- `--controller-name` - Specify custom controller name
- `--test-framework` - Force RSpec or Minitest
- `--skip-migration` - Skip migration generation
- `--skip-model` - Skip model modification
- `--skip-controller` - Skip controller modification
- `--skip-tests` - Skip test generation

#### Controller Options
- `expirable` (Boolean, default: `true`) - Enable/disable session expiration
- `expiry_time` (Duration, default: `2.hours` or auto-synced) - Session expiration duration
- `session_key` (String/Symbol, optional) - Custom session key
- `on` (Symbol/Array, optional) - Actions for automatic initialization
- `auto_params` (Boolean/Array, default: inferred from `on`) - Auto-inject timestamp into params
- `param_key` (Symbol, default: `controller_name.singularize`) - Custom params key for nested resources
- `auto_cleanup` (Boolean, default: `true`) - Auto-cleanup session on next form load (skips edit/update)

#### Model Options
- `prevent_future` (Boolean, default: `false`) - Reject future timestamps
- `prevent_update` (Boolean, default: `false`) - Lock timestamp after creation
- `validate_max_duration` (Duration, optional) - Maximum form completion time
- `validate_min_duration` (Duration, optional) - Minimum form completion time (bot detection)

### Documentation
- Comprehensive GENERATOR_GUIDE.md with time sync examples
- Updated all examples to remove `get_` prefix
- Added time synchronization section
- Updated QUICK_REFERENCE.md
- Updated USAGE_GUIDE.md
- Added GENERATOR_SUMMARY.md
