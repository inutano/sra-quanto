# Rakefile to create tables for execution manage

require 'parallel'
require 'zip'
require 'ciika'

namespace :tables do
  # setup working dir
  workdir = ENV['workdir'] || PROJ_ROOT
  table_dir = File.join(workdir, "tables")
  directory table_dir
  
  # path to files
  fastqc_dir = ENV['fastqc_dir'] || File.join(workdir, "fastqc")
  sra_metadata = ENV['sra_metadata_dir'] || File.join(table_dir, "sra_metadata")
  list_finished  = File.join(table_dir, "runs.done.tab")
  list_live      = File.join(table_dir, "runs.live.tab")
  list_layout    = File.join(table_dir, "experiments.layout.tab")
  list_available = File.join(table_dir, "experiments.available.tab")
  
  task :available => [
    sra_metadata,
    :fix_metadata_dir,
    list_finished,
    list_live,
    list_layout,
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
    versions = Parallel.map(dirs, :in_threads => NUM_OF_PARALLEL) do |pd|
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
  
  file list_live => sra_metadata do |t|
    fpath = "#{sra_metadata}/SRA_Accessions"
    # pattern = '$1 ~ /^.RR/ && $3 == "live" && $9 == "public"'
    pattern = '$1 ~ /^DRR04/ && $3 == "live" && $9 == "public"' # for test run
    list = `cat #{fpath} | awk -F '\t' '#{pattern} {print $1 "\t" $2 "\t" $11}'`.split("\n")
    open(t.name, "w"){|f| f.puts(list) }
  end
  
  file list_layout => [list_live, sra_metadata] do |t|
    list_acc = `cat #{list_live} | awk -F '\t' '{ print $2 }' | sort -u`.split("\n")
    list_xml = Parallel.map(list_acc, :in_threads => NUM_OF_PARALLEL) do |acc_id|
      exp_xml_path = File.join(sra_metadata, acc_id.sub(/...$/,""), acc_id, acc_id + ".experiment.xml")
      exp_xml_path if File.exist?(exp_xml_path)
    end
    acc_layout = Parallel.map(list_xml.compact, :in_threads => NUM_OF_PARALLEL) do |xml|
      Ciika::SRA::Experiment.new(xml).parse.map{|a| [a[:accession], a[:library_description][:library_layout]] }
    end
    out = acc_layout.flatten(1).map{|a| a.join("\t") }
    open(t.name, "w"){|f| f.puts(out) }
  end
  
  file list_available => [list_finished, list_live, list_layout] do |t|
    live = {}
    open(list_live).each do |ln|
      live[ln.split("\t").first] = ln.chomp
    end
    
    layout = {}
    open(list_layout).each do |ln|
      l = ln.split("\t")
      layout[l.first] = l.last
    end
    
    done = open(list_finished).readlines.select{|ln| ln.chomp =~ /#{FASTQC_VERSION}$/ }
    done_runid = Parallel.map(done, :in_threads => NUM_OF_PARALLEL) do |ln|
      ln.split("\t")[0].split("/").last.split("_")[0]
    end
    
    available_run = live.keys - done_runid
    available = Parallel.map(available_run, :in_threads => NUM_OF_PARALLEL) do |runid|
      set = live[runid].split("\t")
      acc_id = set[1]
      exp_id = set[2]
      [exp_id, acc_id, layout[exp_id]].join("\t")
    end
    open(list_available,"w"){|f| f.puts(available.uniq) }
  end
end