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

    def published_before(base_date)
      available(mode: :before, base_date: base_date)
    end

    def published_after(base_date)
      available(mode: :after, base_date: base_date)
    end

    def available(mode: :before, base_date: Time.now)
      finished_set = runids_finished
      available_record = Parallel.map(@sra_available, :in_threads => @nop) do |record|
        validate_record(record, finished_set, mode, base_date)
      end
      available_record.compact.uniq
    end

    def validate_record(record, finished_set, date_mode, base_date)
      validated = is_finished?(record, finished_set) && valid_date?(date_mode, base_date, record)
      experiment_record(record) if validated
    end

    def is_finished?(record, finished_set)
      !finished_set.include?(record[0])
    end

    def valid_date?(mode, base_date, record)
      date = DateTime.parse(record[3])
      case mode
      when :before
        base_date > date
      when :after
        base_date < date
      end
    end

    def experiment_record(record)
      [record[2], record[1], record[3], record[4]]
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
