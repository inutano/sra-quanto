# Rakefile to execute fastqc for given items

namespace :quanto do
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
  logdir_uge   = File.join(logdir, "uge")
  logdir_table = File.join(logdir, "tables")

  directory logdir
  directory logdir_job
  directory logdir_ftp
  directory logdir_uge

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

  desc "option: workdir, fastqc_dir"
  task :exec => [list_available, logfile, logdir_job, logdir_ftp, logdir_uge, logdir_table] do
    list_records = Quanto::Records::IO.read(list_available)
    logwrite(logfile, "#{Time.now}: Number of total target experiments: #{list_records.size}")

    grouped_records = list_records.each_slice(50000).to_a
    grouped_records.each_with_index do |records, i|
      while !`#{QSUB.gsub(/qsub$/,"qstat")} | grep Quanto`.empty? do
        sleep 300
      end
      logwrite(logfile, "#{Time.now}: Start FastQC execution #{i}/#{grouped_records.size}")

      # Create process list for array job
      process_list = File.join(logdir, "process_list_#{i}.txt")
      open(process_list, "w") do |f|
        records.each do |records|
          exp_id = records[0]
          acc_id = records[1]
          layout = records[2]
          logdir_exp = File.join(logdir_job, exp_id.sub(/...$/,""))
          mkdir_p logdir_exp
          logfile_job = File.join(logdir_exp, exp_id + ".log")
          f.puts("#{acc_id} #{exp_id} #{layout} #{logfile_job}")
        end
      end

      # Submit array job
      qsub_args = [
        "-N Quanto.#{Time.now.strftime("%Y%m%d-%H%M")}",
        "-j y",
        "-o #{logdir_uge}",
        "-t 1-#{list.size}",
      ]

      fastqc_args = [
        "--fastqc-dir #{fastqc_dir}",
        "--ftp-connection-pool #{logdir_ftp}",
        "--fastq-checksum #{checksum_table}",
        "--job-list #{process_list}",
      ]

      mes = `#{QSUB} #{qsub_args.join("\s")} #{core} #{fastqc_args.join("\s")}`
      logwrite(logfile, "#{Time.now}: #{mes}")
    end
  end
end
