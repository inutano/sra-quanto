# Rakefile to create tables for execution manage

require 'parallel'

namespace :tables do
  # setup working dir
  workdir = ENV['workdir'] || PROJ_ROOT
  table_dir = File.join(workdir, "tables")
  directory table_dir

  # path to files
  fastqc_dir = ENV['fastqc-dir'] || File.join(workdir, "fastqc")
  sra_metadata = ENV['sra-metadata'] || File.join(table_dir, "sra_metadata")
  list_finished  = File.join(table_dir, "experiments.done.tab")
  list_live      = File.join(table_dir, "experiments.live.tab")
  list_available = File.join(table_dir, "experiments.available.tab")
  
  task :create_list_available => [
    sra_metadata,
    list_finished,
    list_live,
    list_available
  ]
  
  file sra_metadata do
    if !File.exist?(sra_metadata)
      month = Time.now.strftime("%m")
      fname = "NCBI_SRA_Metadata_Full_2015#{month}01.tar.gz"
      sh "lftp -c \"open ftp.ncbi.nlm.nih.gov:/sra/reports/Metadata && pget -n 8 #{fname}\""
      sh "cd #{table_dir} && tar xfv #{fname} && mv #{fname.sub(".tar.gz","")} sra_metadata"
    end
  end

  file list_finished do
    p_dirs = ["DRR","ERR","SRR"].map{|d| 10.times.map{|n| File.join(fastqc_dir,d,d+n.to_s)}}.flatten
    p2_dirs = Parallel.map(p_dirs, :in_threads => 8){|pd| Dir.glob(pd+"/*") }.flatten
    p3_dirs = Parallel.map(p2_dirs, :in_threads => 8){|pd| Dir.glob(pd+"/*") }.flatten
    p4_dirs = Parallel.map(p3_dirs, :in_threads => 8){|pd| Dir.glob(pd+"/*") }.flatten
    open(list_finished,"w"){|f| f.puts(p4_dirs) }
  end
  
  file list_live do
  end
  
  file list_available do
  end
end