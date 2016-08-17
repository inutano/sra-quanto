# Rakefile to execute fastqc for given items

namespace :fastqc do
  # executable
  core = File.join(PROJ_ROOT, "exe", "quanto-core")

  # setup working dir
  workdir        = ENV['workdir'] || PROJ_ROOT
  table_dir      = File.join(workdir, "tables")
  list_available = ENV['list_available'] || File.join(table_dir, "experiments.available.tab")
  fastqc_dir     = ENV['fastqc_dir'] || File.join(workdir, "fastqc")
  checksum_table = ENV['checksum_table'] || File.join(table_dir, "dra", "fastqlist")

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
    list = Quanto::Records::IO.read(list_available)
    logwrite(logfile, "Number of target experiments: #{list.size}")

    process_list = File.join(logdir, "process_list.txt")
    open(process_list, "w") do |f|
      list.each do |record|
        exp_id = record[0]
        acc_id = record[1]
        layout = record[2]
        logdir_exp = File.join(logdir_job, exp_id.sub(/...$/,""))
        mkdir_p logdir_exp
        logfile_job = File.join(logdir_exp, exp_id + ".log")
        f.puts("#{acc_id} #{exp_id} #{layout} #{logfile_job}")
      end

      # Submit array job
      sh "#{QSUB} -N Quanto.#{Time.now.strftime("%Y%m%d-%H%M")} -t 1-#{list.size} #{core} --fastqc-dir #{fastqc_dir} --ftp-connection-pool #{logdir_ftp} --fastq-checksum #{checksum_table} --job-list #{process_list}"
    end
  end
end
