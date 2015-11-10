# Rakefile to execute fastqc for given items

namespace :fastqc do
  # executable
  core = File.join(PROJ_ROOT, "exe", "quanto-core")
  
  # setup working dir
  workdir = ENV['workdir'] || PROJ_ROOT
  table_dir = File.join(workdir, "tables")
  list_available = File.join(table_dir, "experiments.available.tab")
  fastqc_dir = ENV['fastqc_dir'] || File.join(workdir, "fastqc")

  # logging
  date       = Time.now.strftime("%Y%m%d-%H%M")
  logdir     = File.join(PROJ_ROOT, "log", date)
  logfile    = File.join(logdir, "exec.log")
  logdir_job = File.join(logdir, "job")

  directory logdir
  directory logdir_job
  
  file logfile => logdir do |t|
    touch t.name
  end
  
  def logwrite(logfile, m)
    open(logfile, "a"){|f| f.puts(m) }
  end
  
  task :exec => [list_available, logfile, logdir_job] do
    logwrite(logfile, "Start FastQC execution: #{Time.now}")
    list = open(list_available).read.split("\n")
    logwrite(logfile, "Number of target experiments: #{list.size}")
    list.each do |line|
      item = line.split("\t")
      exp_id = item[0]
      acc_id = item[1]
      layout = item[2]
      logfile_job = File.join(logdir_job, exp_id + ".log")
      sh "#{QSUB} -N #{exp_id} -o #{logfile_job} #{core} #{acc_id} #{exp_id} #{layout} #{fastqc_dir}"
      sleep 1
    end
  end
end