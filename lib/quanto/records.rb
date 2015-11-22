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

    def initialize(sra_available, fastqc_finished)
      @sra_available = sra_available
      @fastqc_finished = fastqc_finished
      @nop = Quanto::Records.num_of_parallels
    end

    def available
      finished = runids_finished
      available_record = Parallel.map(@sra_available, :in_threads => @nop) do |record|
        run_id = record[0]
        experiment_record = [record[2], record[1], record[3]]
        experiment_record if !finished.include?(run_id)
      end
      available_record.uniq.compact
    end

    def runids_finished
      runids = Parallel.map(@fastqc_finished, :in_threads => @nop) do |record|
        fastqc_path = record.split("\t")[0]
        fastqc_path.split("/").last.split("_")[0]
      end
      runids.uniq
    end
  end
end
