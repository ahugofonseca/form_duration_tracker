# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'form_duration_tracker/version'

Gem::Specification.new do |spec|
  spec.name          = 'form_duration_tracker'
  spec.version       = FormDurationTracker::VERSION
  spec.authors       = ['Hugo Abreu']
  spec.email         = ['a.hugofonseca@gmail.com']

  spec.summary       = 'Track form fill duration with session-based timestamps for Rails applications'
  spec.description   = 'A Rails gem that provides controller and model concerns to track how long users take to fill forms. Features include session-based timestamp tracking, customizable expiry times, and model validations.'
  spec.homepage      = 'https://github.com/indiecampers/form_duration_tracker'
  spec.license       = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = 'https://github.com/indiecampers/form_duration_tracker'
    spec.metadata['changelog_uri'] = 'https://github.com/indiecampers/form_duration_tracker/blob/master/CHANGELOG.md'
    spec.metadata['rubygems_mfa_required'] = 'true'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
          'public gem pushes.'
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'rails', '>= 4.2'

  spec.add_development_dependency 'bigdecimal'
  spec.add_development_dependency 'bundler', '>= 1.17'
  spec.add_development_dependency 'logger'
  spec.add_development_dependency 'mutex_m'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 1.50'
  spec.add_development_dependency 'rubocop-rspec', '~> 2.20'
  spec.add_development_dependency 'simplecov', '~> 0.22'
  spec.add_development_dependency 'timecop', '~> 0.9'
end
