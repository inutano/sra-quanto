# Rakefile to create tables for execution manage

namespace :tables do
  # setup working dir
  workdir   = ENV['workdir'] || PROJ_ROOT
  table_dir = File.join(workdir, "tables")
  directory table_dir
  fastqc_dir     = ENV['fastqc_dir'] || File.join(workdir, "fastqc")
  sra_metadata   = ENV['sra_metadata_dir'] || File.join(table_dir, "sra_metadata")

  # path to list
  list_fastqc_finished = File.join(table_dir, "runs.done.tab")
  list_public_sra      = File.join(table_dir, "runs.public.tab")
  list_available       = File.join(table_dir, "experiments.available.tab")

  # base task
  task :available => [
    sra_metadata,
    list_finished,
    list_public,
    list_available
  ]

  file sra_metadata do |t|
    Quanto::Records::SRA.download_sra_metadata(table_dir)
  end

  file list_finished do |t|
    fastqc_records = Quanto::Records::FastQC.new(fastqc_dir)
    Quanto::Records::IO.write(fastqc_records.finished, t.name)
  end

  file list_public => sra_metadata do |t|
    sra_records = Quanto::Records::SRA.new(sra_metadata)
    Quanto::Records::IO.write(sra_records.available, t.name)
  end

  file list_available => [list_finished, list_public] do |t|
    records_finished = Quanto::Records::IO.read(list_finished)
    records_public   = Quanto::Records::IO.read(list_public)
    quanto_records   = Quanto::Records.new(records_finished, records_public)
    Quanto::Records::IO.write(quanto_records.available, t.name)
  end
end
