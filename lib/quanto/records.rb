require 'parallel'
require 'time'
require 'set'

module Quanto
  class Records
    def self.set_number_of_parallels(nop)
      @@num_of_parallels = nop
    end

    def initialize(fastqc_finished, sra_available)
      @fastqc_finished = fastqc_finished
      @sra_available   = sra_available
      @nop = @@num_of_parallels
    end
    attr_accessor :date_mode, :date_base

    def date_mode
      @date_mode || :before
    end

    def date_base
      @date_base ? DateTime.parse(@date_base) : Time.now.to_datetime
    end

    def runids_finished
      runids = Parallel.map(@fastqc_finished, :in_threads => @nop) do |record|
        record[0].split("/").last.split("_")[0] if record[1] != "CORRUPT"
      end
      runids.uniq
    end

    # returns array of [experiment id, submission id, read layout]
    def available
      finished_set = runids_finished.to_set
      available_record = Parallel.map(@sra_available, :in_threads => @nop) do |record|
        # record is an array of [run id, submission id, experiment id, received date, read layout]
        validate_record(record, finished_set)
      end
      available_record.compact.uniq
    end

    def validate_record(record, finished_set)
      validated = !is_finished?(record, finished_set) && valid_date?(record)
      experiment_record(record) if validated
    end

    def is_finished?(record, finished_set)
      finished_set.include?(record[0])
    end

    def valid_date?(record)
      date = DateTime.parse(record[3])
      case date_mode
      when :before
        date_base > date
      when :after
        date_base < date
      end
    rescue
      return false
    end

    def experiment_record(record)
      [record[2], record[1], record[4]]
    end
  end
end
