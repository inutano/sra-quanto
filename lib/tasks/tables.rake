# Rakefile to create tables for execution manage

namespace :tables do
  # rake fileutils verbose option: false
  verbose(false)
  
  # setup working dir
  workdir      = ENV['workdir'] || PROJ_ROOT
  table_dir    = File.join(workdir, "tables")
  fastqc_dir   = ENV['fastqc_dir'] || File.join(workdir, "fastqc")
  sra_metadata = ENV['sra_metadata_dir'] || File.join(table_dir, "sra_metadata")

  # create directories if missing
  directory workdir
  directory table_dir
  directory fastqc_dir

  # path to list
  list_fastqc_finished = File.join(table_dir, "runs.done.tab")
  list_public_sra      = File.join(table_dir, "runs.public.tab")
  list_available       = File.join(table_dir, "experiments.available.tab")

  # set number of parallels
  Quanto::Records.set_number_of_parallels(NUM_OF_PARALLEL)
  Quanto::Records::IO.set_number_of_parallels(NUM_OF_PARALLEL)
  Quanto::Records::SRA.set_number_of_parallels(NUM_OF_PARALLEL)
  Quanto::Records::FastQC.set_number_of_parallels(NUM_OF_PARALLEL)

  # base task
  task :available => [
    :get_sra_metadata,
    list_fastqc_finished,
    list_public_sra,
    list_available
  ]

  task :get_sra_metadata => table_dir do |t|
    puts "==> #{Time.now} Fetching SRA metadata..."
    Quanto::Records::SRA.download_sra_metadata(table_dir)
    puts "==> #{Time.now} Done."
  end

  file list_fastqc_finished => fastqc_dir do |t|
    puts "==> #{Time.now} Searching FastQC records..."
    fastqc_records = Quanto::Records::FastQC.new(fastqc_dir)
    Quanto::Records::IO.write(fastqc_records.finished, t.name)
    puts "==> #{Time.now} Done."
  end

  file list_public_sra => sra_metadata do |t|
    puts "==> #{Time.now} Searching live SRA records..."
    sra_records = Quanto::Records::SRA.new(sra_metadata)
    Quanto::Records::IO.write(sra_records.available, t.name)
    puts "==> #{Time.now} Done."
  end

  file list_available => [list_fastqc_finished, list_public_sra] do |t|
    puts "==> #{Time.now} Creating list of items to process..."
    records_finished = Quanto::Records::IO.read(list_fastqc_finished)
    records_public   = Quanto::Records::IO.read(list_public_sra)
    quanto_records   = Quanto::Records.new(records_finished, records_public)
    Quanto::Records::IO.write(quanto_records.available, t.name)
    puts "==> #{Time.now} Done."
  end
end
