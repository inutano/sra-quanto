# Rakefile to execute fastqc for given items

namespace :fastqc do
  # executable
  core = File.join(PROJ_ROOT, "exe", "quanto-core")

  # setup working dir
  workdir        = ENV['workdir'] || PROJ_ROOT
  table_dir      = File.join(workdir, "tables")
  list_available = File.join(table_dir, "experiments.available.tab")
  fastqc_dir     = ENV['fastqc_dir'] || File.join(workdir, "fastqc")

  # logging
  date         = Time.now.strftime("%Y%m%d-%H%M")
  logdir       = File.join(PROJ_ROOT, "log", date)
  logfile      = File.join(logdir, "exec.log")
  logdir_job   = File.join(logdir, "job")
  logdir_ftp   = File.join(logdir, "ftp")
  logdir_table = File.join(logdir, "tables")

  directory logdir
  directory logdir_job
  directory logdir_ftp

  file logfile => logdir do |t|
    touch t.name
  end

  file logdir_table => logdir do |t|
    mkdir_p t.name
    cp_r Dir.glob("#{table_dir}/*tab"), t.name
  end

  def logwrite(logfile, m)
    open(logfile, "a"){|f| f.puts(m) }
  end

  task :exec => [list_available, logfile, logdir_job, logdir_ftp, logdir_table] do
    logwrite(logfile, "Start FastQC execution: #{Time.now}")
    list = Quanto::Records::IO.read(list_avaialble)
    logwrite(logfile, "Number of target experiments: #{list.size}")
    list.each do |record|
      exp_id = record[0]
      acc_id = record[1]
      layout = record[3]
      logfile_job = File.join(logdir_job, exp_id + ".log")
      sh "#{QSUB} -N #{exp_id} -o #{logfile_job} #{core} #{acc_id} #{exp_id} #{layout} #{fastqc_dir} #{logdir_ftp}"
      sleep 2
    end
  end
end
