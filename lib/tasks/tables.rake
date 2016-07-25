# Rakefile to create tables for execution manage

namespace :tables do
  # rake fileutils verbose option: false
  verbose(false)

  # setup working dir
  workdir      = ENV['workdir'] || PROJ_ROOT
  table_dir    = File.join(workdir, "tables")
  fastqc_dir   = ENV['fastqc_dir'] || File.join(workdir, "fastqc")

  sra_metadata_dir = ENV['sra_metadata_dir'] || File.join(table_dir, "sra_metadata")
  biosample_metadata_dir = ENV['biosample_metadata_dir'] || File.join(table_dir, "biosample")
  dra_dir = ENV['dra_dir'] || File.join(table_dir, "dra")

  # create directories if missing
  directory workdir
  directory table_dir
  directory fastqc_dir

  directory sra_metadata_dir
  directory biosample_metadata_dir
  directory dra_dir

  # path to list
  list_fastqc_finished     = File.join(table_dir, "runs.done.tab")
  list_public_sra          = File.join(table_dir, "runs.public.tab")
  list_available           = File.join(table_dir, "experiments.available.tab")
  list_experiment_metadata = File.join(table_dir, "experiment_metadata.tab")
  list_biosample_metadata  = File.join(table_dir, "biosample_metadata.tab")
  list_fastq_checksum      = File.join(dra_dir, "fastqlist")
  list_sra_checksum        = File.join(dra_dir, "sralist")

  # set number of parallels
  Quanto::Records.set_number_of_parallels(NUM_OF_PARALLEL)
  Quanto::Records::IO.set_number_of_parallels(NUM_OF_PARALLEL)
  Quanto::Records::SRA.set_number_of_parallels(NUM_OF_PARALLEL)
  Quanto::Records::FastQC.set_number_of_parallels(NUM_OF_PARALLEL)
  Quanto::Records::BioSample.set_number_of_parallels(NUM_OF_PARALLEL)

  # base task
  task :available => [
    :get_sra_metadata,
    :get_sra_checksum_table,
    :get_biosample_metadata,
    list_fastqc_finished,
    list_experiment_metadata,
    list_biosample_metadata,
    list_public_sra,
    list_available,
  ]

  task :get_sra_metadata => table_dir do |t|
    puts "==> #{Time.now} Fetching SRA metadata..."
    Quanto::Records::SRA.download_sra_metadata(table_dir)
    puts "==> #{Time.now} Done."
  end

  task :get_sra_checksum_table => [
    list_fastq_checksum,
    list_sra_checksum,
  ]

  file list_fastq_checksum => dra_dir do |t|
    puts "==> #{Time.now} Fetching Fastq checksum table..."
    sh "lftp -c \"open ftp.ddbj.nig.ac.jp/dra/meta/list && pget -n 8 -O #{t.name} fastqlist\""
    puts "==> #{Time.now} Done."
  end

  file list_sra_checksum => dra_dir do |t|
    puts "==> #{Time.now} Fetching SRA checksum table..."
    sh "lftp -c \"open ftp.ddbj.nig.ac.jp/dra/meta/list && pget -n 8 -O #{t.name} sralist\""
    puts "==> #{Time.now} Done."
  end

  task :get_biosample_metadata => biosample_metadata_dir do |t|
    puts "==> #{Time.now} Fetching BioSample metadata..."
    Quanto::Records::BioSample.download_metadata_xml(biosample_metadata_dir)
    puts "==> #{Time.now} Done."
  end

  file list_fastqc_finished => fastqc_dir do |t|
    puts "==> #{Time.now} Searching FastQC records..."
    fastqc_records = Quanto::Records::FastQC.new(fastqc_dir)
    Quanto::Records::IO.write(fastqc_records.finished, t.name)
    puts "==> #{Time.now} Done."
  end

  file list_experiment_metadata => sra_metadata_dir do |t|
    puts "==> #{Time.now} Creating list of experimental metadata..."
    sra = Quanto::Records::SRA.new(sra_metadata_dir)
    sra.experiment_metadata(t.name)
    puts "==> #{Time.now} Done."
  end

  file list_biosample_metadata => [sra_metadata_dir, biosample_metadata_dir] do |t|
    puts "==> #{Time.now} Creating list of biosample metadata..."
    bs = Quanto::Records::BioSample.new(biosample_metadata_dir, sra_metadata_dir)
    bs.create_list_metadata(t.name)
    puts "==> #{Time.now} Done."
  end

  file list_public_sra => [sra_metadata_dir, list_experiment_metadata] do |t|
    puts "==> #{Time.now} Searching live SRA records..."
    sra = Quanto::Records::SRA.new(sra_metadata_dir)
    Quanto::Records::IO.write(sra.available(list_experiment_metadata), t.name)
    puts "==> #{Time.now} Done."
  end

  file list_available => [list_fastqc_finished, list_public_sra] do |t|
    puts "==> #{Time.now} Creating list of items to process..."
    records_finished = Quanto::Records::IO.read(list_fastqc_finished)
    records_public   = Quanto::Records::IO.read(list_public_sra)
    quanto_records   = Quanto::Records.new(records_finished, records_public)
    quanto_records.date_mode = RECORDS_PUBLISHED if RECORDS_PUBLISHED
    quanto_records.date_base = BASE_DATE if BASE_DATE
    Quanto::Records::IO.write(quanto_records.available, t.name)
    puts "==> #{Time.now} Done."
  end
end
