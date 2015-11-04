# Rakefile for sra quanto by inutano@gmail.com

PROJ_ROOT = File.expand_path(__dir__)
NUM_OF_PARALLEL = 8

Dir["#{PROJ_ROOT}/lib/tasks/**/*.rake"].each do |path|
  load path
end

namespace :quanto do
  desc "Run fastqc for all items not yet calculated"
  task :ignition do
    Rake::Task["quanto:create_list_available"].invoke
    Rake::Task["quanto:exec_fastqc"].invoke
  end
  
  task :crete_list_available do
    Rake::Task["tables:available"].invoke
  end
  
  task :exec_fastqc do
    Rake::Task["fastqc:exec"].invoke
  end
end