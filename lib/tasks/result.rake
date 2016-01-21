# rakefile to collect fastqc result and summarize

require 'parallel'
require 'bio-fastqc'
require 'json'

namespace :result do
  # setup working dir
  workdir    = ENV['workdir'] || PROJ_ROOT
  fastqc_dir = ENV['fastqc_dir'] || File.join(workdir, "fastqc")

  # collect paths to zipped fastqc result
  table_dir            = File.join(workdir, "tables")
  list_fastqc_finished = File.join(table_dir, "runs.done.tab")
  quanto_summary_json  = File.join(table_dir, "quanto.summary.json")

  task :summarize => [
    list_fastqc_finished,
    quanto_summary_json,
  ]

  file quanto_summary_json => [list_fastqc_finished] do |t|
    summary = Quanto::Records::Summary.summarize(list_fastqc_finished)
    Quanto::Records::IO.write(summary, t.name)
  end
end
