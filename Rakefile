# File: ./Rakefile

require 'rake'

# --- Test Tasks ---
def create_test_task(db_name)
  task "test:#{db_name}" do
    puts "Running tests for #{db_name.upcase}..."
    ENV['DB'] = db_name.to_s
    system('ruby test/run_tests.rb') || raise("Test suite failed for #{db_name}")
  end
end

%w[sqlite postgres mysql].each do |db|
  create_test_task(db)
end

task :test do
  %w[sqlite postgres mysql].each do |db|
    Rake::Task["test:#{db}"].invoke
  end
end


# The default Rake task now just runs the tests.
task default: "test:sqlite"