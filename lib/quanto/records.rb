# -*- coding: utf-8 -*-

require 'rake'
require 'parallel'
require 'zip'
require 'ciika'

module Quanto
  class Records
    class << self
      def num_of_parallels
        NUM_OF_PARALLELS || 4
      end

      def target_archives
        # ["DRR","ERR","SRR"] # complete list
        ["DRR"]
      end
    end

    def create_list_available(list_live, list_layout, list_finished)
      live = get_live_list_hash(list_live)
      layout = get_layout_list_hash(list_layout)
      done = filter_by_version(open(list_finished).read, FASTQC_VERSION)

      done_runid = Parallel.map(done, :in_threads => Quanto::Records.num_of_parallels) do |ln|
        ln.split("\t")[0].split("/").last.split("_")[0]
      end

      available_run = live.keys - done_runid
      available = Parallel.map(available_run, :in_threads => Quanto::Records.num_of_parallels) do |runid|
        set = live[runid].split("\t")
        acc_id = set[1]
        exp_id = set[2]
        [exp_id, acc_id, layout[exp_id]].join("\t")
      end
      open(list_available,"w"){|f| f.puts(available.uniq) }
    end
  end
end
