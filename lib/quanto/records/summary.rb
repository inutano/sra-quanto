require 'parallel'
require 'bio-fastqc'

module Quanto
  class Records
    class Summary
      class << self
        def summarize(list_fastqc_finished)
          summary = {}
          zip_path_list = open(list_fastqc_finished).readlines
          Parallel.each(zip_path_list, :in_threads => @@num_of_parallels) do |line|
            zip_path = line.split("\t").first
            summary[zip_path.split("/").last] = summarize_fastqc(zip_path)
          end
          summary
        end

        def summarize_fastqc(fastqc_zip_path)
          data = Bio::FastQC::Data.read(fastqc_zip_path)
          Bio::FastQC::Parser.new(data).summary
        end
      end
    end
  end
end
