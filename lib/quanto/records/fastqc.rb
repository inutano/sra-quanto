require 'parallel'
require 'zip'

module Quanto
  class Records
    class FastQC
      def self.set_number_of_parallels(nop)
        @@num_of_parallels = nop
      end

      def initialize(fastqc_dir)
        @fastqc_dir = fastqc_dir
      end

      def finished
        finished_run = run_dir_finished
        finished_zipfiles = fastqc_zipfiles(finished_run)
        fastqc_versions(finished_zipfiles)
      end

      def outdated(version)
        finished.select{|path_ver| path_ver[1] != version }
      end

      def run_dir_finished
        deep_p_glob(@fastqc_dir, 3)
      end

      def deep_p_glob(base_dir, depth)
        dirs = [base_dir]
        depth.times.each do |t|
          dirs = p_glob(dirs)
        end
        dir
      end

      def p_glob(dirs)
        kids = Parallel.map(dirs, :in_threads => @@num_of_parallels) do |pd|
          Dir.glob(pd+"/*")
        end
        kids.flatten
      end

      def fastqc_zipfiles(run_dirs)
        Parallel.map(run_dirs, :in_threads => @@num_of_parallels) do |pd|
          Dir.glob(pd+"/*zip")
        end
      end

      def fastqc_versions(zipfiles)
        Parallel.map(zipfiles, :in_threads => @@num_of_parallels) do |zipfile|
          [zipfile, extract_version(zipfile)]
        end
      end

      def extract_version(zipfile)
        Zip::File.open(zipfile) do |zip|
          stream = zip.glob("*/fastqc_data.txt").first.get_input_stream
          stream.read.split("\n").first.split("\t").last
        end
      end
    end
  end
end
