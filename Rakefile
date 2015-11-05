# Rakefile for sra quanto by inutano@gmail.com

PROJ_ROOT = File.expand_path(__dir__)
NUM_OF_PARALLEL = 8
FASTQC_VERSION = "0.11.3"

Dir["#{PROJ_ROOT}/lib/tasks/**/*.rake"].each do |path|
  load path
end


namespace :quanto do
  desc "Create items not yet done, dirs can be specified for fastqc_dir, sra_metadata_dir, workdir"
  task :init do
    Rake::Task["tables:available"].invoke
  end
  
  desc "Run fastqc for all items not yet calculated"
  task :exec do
    Rake::Task["fastqc:exec"].invoke
  end
end