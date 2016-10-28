# rakefile to collect fastqc result and summarize

require 'parallel'
require 'bio-fastqc'
require 'json'

namespace :quanto do
  # setup working dir
  workdir              = ENV['workdir'] || PROJ_ROOT
  table_dir            = File.join(workdir, "tables")
  list_fastqc_finished = File.join(table_dir, "runs.done.tab")
  sra_metadata_dir     = ENV['sra_metadata_dir'] || File.join(table_dir, "sra_metadata")
  summary_outdir       = ENV['summary_outdir'] || File.join(table_dir, "summary")

  experiment_metadata  = File.join(table_dir, "experiment_metadata.tab")
  biosample_metadata   = File.join(table_dir, "biosample_metadata.tab")

  # summary merge option: false to use existing summary files
  overwrite = ENV['overwrite'] == "false" ? false : true

  # create directory if it does not exist
  directory summary_outdir

  # set number of parallels
  Quanto::Records::Summary.set_number_of_parallels(NUM_OF_PARALLEL)

  # set format of summarization
  format = ENV['format'] || "json"

  desc "option: workdir, sra_metadata_dir, summary_outdir, overwrite, format"
  task :summarize => [summary_outdir] do |t|
    puts "==> #{Time.now} Create summary files..."
    sum = Quanto::Records::Summary.new(list_fastqc_finished)
    sum.summarize(format, summary_outdir)
    puts "==> #{Time.now} Done."

    puts "==> #{Time.now} Merge summary files..."
    sum.merge(
      format,
      summary_outdir,
      sra_metadata_dir,
      experiment_metadata,
      biosample_metadata,
      overwrite
    )
    puts "==> #{Time.now} Done."
  end
end
