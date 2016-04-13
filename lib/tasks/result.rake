# rakefile to collect fastqc result and summarize

require 'parallel'
require 'bio-fastqc'
require 'json'

namespace :result do
  # setup working dir
  workdir              = ENV['workdir'] || PROJ_ROOT
  table_dir            = File.join(workdir, "tables")
  list_fastqc_finished = File.join(table_dir, "runs.done.tab")
  summary_outdir       = ENV['summary_outdir'] || File.join(table_dir, "summary")

  # create directory if it does not exist
  directory summary_outdir

  # set number of parallels
  Quanto::Records::Summary.set_number_of_parallels(NUM_OF_PARALLEL)

  # set format of summarization
  format = ENV['format'] || "json"

  task :summarize => [summary_outdir] do |t|
    Quanto::Records::Summary.summarize(list_fastqc_finished, summary_outdir, format)
  end
end
