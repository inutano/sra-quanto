# Rakefile for sra quanto by inutano@gmail.com

# add current directory and lib directory to load path
$LOAD_PATH << __dir__
$LOAD_PATH << File.join(__dir__, "lib")

require 'lib/quanto'

# Configuration
NUM_OF_PARALLEL = 8
FASTQC_VERSION = "0.11.3"

# Configuration of date limitation of records
RECORDS_PUBLISHED = ENV['records_published'] || :before
BASE_DATE = ENV['base_date'] # e.g. "2015-09-07"

# path to executables and option for qsub command
QSUB = if ENV['qsub']
  ENV['qsub']
else
  "source /home/geadmin/UGED/uged/common/settings.sh && /home/geadmin/UGED/bin/lx-amd64/qsub"
end

# Constants
PROJ_ROOT = File.expand_path(__dir__)

Dir["#{PROJ_ROOT}/lib/tasks/**/*.rake"].each do |path|
  load path
end
