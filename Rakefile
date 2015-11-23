# Rakefile for sra quanto by inutano@gmail.com

require 'lib/quanto'

# Configuration
NUM_OF_PARALLEL = 8
FASTQC_VERSION = "0.11.3"

# Configuration of date limitation of records
# RECORDS_PUBLISHED = :before
# BASE_DATE = "2015-09-07"

# path to executables
QSUB = "/home/geadmin/UGER/bin/lx-amd64/qsub -l dbcls"

# Constants
PROJ_ROOT = File.expand_path(__dir__)

Dir["#{PROJ_ROOT}/lib/tasks/**/*.rake"].each do |path|
  load path
end

namespace :quanto do
  desc "Create lists of available items, fastqc_dir, sra_metadata_dir, workdir can be specified"
  task :available do
    Rake::Task["tables:available"].invoke
  end

  desc "Run fastqc for available items"
  task :execute do
    Rake::Task["fastqc:exec"].invoke
  end
end
