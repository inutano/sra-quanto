# Rakefile to execute fastqc for given items

namespace :fastqc do
  # executable
  core = File.join(PROJ_ROOT, "exe", "quanto-core")
  
  # setup working dir
  workdir = ENV['workdir'] || PROJ_ROOT
  table_dir = File.join(workdir, "tables")
  list_available = File.join(table_dir, "experiments.available.tab")

  task :exec => list_available do
    list = open(list_available).read.split("\n")
    list.each do |line|
      item = line.split("\t")
      acc_id = item[1]
      exp_id = item[2]
      layout = item[3]
      `qsub #{core} #{acc_id} #{exp_id} #{layout}`
    end
  end
end