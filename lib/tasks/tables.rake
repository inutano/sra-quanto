# Rakefile to create tables for execution manage

require 'parallel'
require 'zip'

namespace :tables do
  # setup working dir
  workdir = ENV['workdir'] || PROJ_ROOT
  table_dir = File.join(workdir, "tables")
  directory table_dir
  
  # path to files
  fastqc_dir = ENV['fastqc_dir'] || File.join(workdir, "fastqc")
  sra_metadata = ENV['sra_metadata_dir'] || File.join(table_dir, "sra_metadata")
  list_finished  = File.join(table_dir, "experiments.done.tab")
  list_live      = File.join(table_dir, "experiments.live.tab")
  list_available = File.join(table_dir, "experiments.available.tab")
  
  task :available => [
    sra_metadata,
    :fix_metadata_dir,
    list_finished,
    list_live,
    list_available
  ]
  
  file sra_metadata do |t|
    month = Time.now.strftime("%m")
    fname = "NCBI_SRA_Metadata_Full_2015#{month}01.tar.gz"
    cd table_dir
    sh "lftp -c \"open ftp.ncbi.nlm.nih.gov/sra/reports/Metadata && pget -n 8 #{fname}\""
    sh "tar zxf #{fname}"
    mv fname.sub(".tar.gz",""), t.name
    rm_f fname
  end
  
  task :fix_metadata_dir => sra_metadata do |t|
    cd sra_metadata
    acc_dirs = Dir.entries(sra_metadata).select{|f| f =~ /^.RA\d{6,7}$/ }
    acc_dirs.group_by{|id| id.sub(/...$/,"") }.each_pair do |pid, ids|
      moveto = File.join(sra_metadata, pid)
      mkdir moveto
      mv ids, moveto
    end
  end
  
  def parallel_glob(dirs)
    kids = Parallel.map(dirs, :in_threads => NUM_OF_PARALLEL) do |pd|
      Dir.glob(pd+"/*")
    end
    kids.flatten
  end
  
  def parallel_parsezip(dirs)
    versions = Parallel.map(dirs, :in_thread => NUM_OF_PARALLEL) do |pd|
      Dir.glob(pd+"/*zip").map do |zip|
        version = Zip::File.open(zip) do |zipfile|
          zipfile.glob("*/fastqc_data.txt").first.get_input_stream.read.split("\n").first.split("\t").last
        end
        [zip, version].join("\t")
      end
    end
    versions.flatten
  end

  file list_finished do |t|
    # p_dirs = ["DRR","ERR","SRR"].map{|d| 10.times.map{|n| File.join(fastqc_dir,d,d+n.to_s)}}.flatten
    p_dirs = ["DRR"].map{|d| 10.times.map{|n| File.join(fastqc_dir,d,d+n.to_s)}}.flatten # for test run
    p2_dirs = parallel_glob(p_dirs)
    p3_dirs = parallel_glob(p2_dirs)
    list_finished_versions = parallel_parsezip(p3_dirs)
    open(t.name,"w"){|f| f.puts(list_finished_versions) }
  end
  
  file list_live do |t|
    touch t.name
  end
  
  file list_available do |t|
    touch t.name
  end
end