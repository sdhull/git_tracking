# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "git_tracking/version"

Gem::Specification.new do |s|
  s.name        = "git_tracking"
  s.version     = GitTracking::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Steve Hull", "Derrick Camerino"]
  s.email       = ["p.witty@gmail.com", "robustdj@gmail.com"]
  s.homepage    = "http://rubygems.org/gems/git_tracking"
  s.summary     = %q{Better integration between git and PivotalTracker}
  s.description = %q{Usage: after installing the gem, in your project directory, run: git_tracking}

  s.rubyforge_project = "git_tracking"

  s.add_dependency('highline')
  s.add_dependency('pivotal-tracker')

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
