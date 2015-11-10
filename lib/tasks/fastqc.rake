# Rakefile to execute fastqc for given items

namespace :fastqc do
  # executable
  core = File.join(PROJ_ROOT, "exe", "quanto-core")
  
  # setup working dir
  workdir = ENV['workdir'] || PROJ_ROOT
  table_dir = File.join(workdir, "tables")
  list_available = File.join(table_dir, "experiments.available.tab")
  logdir = File.join(PROJ_ROOT, "log")
  logfile = File.join(logdir, "#{Time.now.strftime("%Y%m%d-%H%M")}.log")
  
  directory logdir
  
  file logfile => logdir do |t|
    touch t.name
  end
  
  def logwrite(logfile, m)
    open(logfile, "a"){|f| f.puts(m) }
  end
  
  task :exec => [list_available, logfile] do
    logwrite(logfile, "Start FastQC execution: #{Time.now}")
    list = open(list_available).read.split("\n")
    logwrite(logfile, "Number of target experiments: #{list.size}")
    list.each do |line|
      item = line.split("\t")
      exp_id = item[0]
      acc_id = item[1]
      layout = item[2]
      sh "#{QSUB} -N #{exp_id} -o #{logfile} #{core} #{acc_id} #{exp_id} #{layout}"
    end
  end
end