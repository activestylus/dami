# File: ./Rakefile
require "rake"

desc "Run the full test suite (SQLite)"
task :test do
  sh "ruby test/run_all.rb"
end

desc "Build the gem (writes dami-<version>.gem in the project root)"
task :build do
  sh "gem build dami.gemspec"
end

task default: :test
