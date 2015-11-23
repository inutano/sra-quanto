# -*- coding: utf-8 -*-

require 'parallel'
require 'time'

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
      @date_mode = RECORDS_PUBLISHED || :before
      @date_base = BASE_DATE ? DateTime.parse(BASE_DATE) : Time.now
    end

    def runids_finished
      runids = Parallel.map(@fastqc_finished, :in_threads => @nop) do |record|
        fastqc_path = record.split("\t")[0]
        fastqc_path.split("/").last.split("_")[0]
      end
      runids.uniq
    end

    def available
      finished_set = runids_finished
      available_record = Parallel.map(@sra_available, :in_threads => @nop) do |record|
        validate_record(record, finished_set, @date_mode, @date_base)
      end
      available_record.compact.uniq
    end

    def validate_record(record, finished_set, @date_mode, @date_base)
      validated = is_finished?(record, finished_set) && valid_date?(@date_mode, @date_base, record)
      experiment_record(record) if validated
    end

    def is_finished?(record, finished_set)
      !finished_set.include?(record[0])
    end

    def valid_date?(mode, @date_base, record)
      date = DateTime.parse(record[3])
      case mode
      when :before
        @date_base > date
      when :after
        @date_base < date
      end
    end

    def experiment_record(record)
      [record[2], record[1], record[3], record[4]]
    end
  end
end
