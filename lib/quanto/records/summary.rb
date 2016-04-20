require 'parallel'
require 'bio-fastqc'
require 'fileutils'
require 'json'

module Quanto
  class Records
    class Summary
      def self.set_number_of_parallels(nop)
        # class variable: number of parallels
        @@nop = nop
      end

      def initialize(fastqc_data_table)
        @list_fastqc_zip_path = extract_list_fastqc_zip_path(fastqc_data_table)
      end

      def extract_list_fastqc_zip_path(fastqc_data_table)
        open(fastqc_data_table).readlines.map{|l| l.split("\t")[0] }
      end

      def summarize(format, outdir)
        @format = format
        @outdir = outdir
        create_summary_files
        create_summary_files_list
      end

      #
      # Create summary files
      #

      def create_summary_files
        bf = Bio::FastQC
        path_list = create_fastqc_zip_path_list_to_summarize
        objects = create_fastqc_data_objects(path_list)
        Parallel.map(objects, :in_threads => @@nop) do |obj|
          create_summary(bf, obj)
          nil
        end
      end

      def create_summary(bf, obj)
        open(obj[:summary_path], 'w') do |f|
          f.puts(
            bf::Converter.new(
              bf::Parser.new(
                bf::Data.read(obj[:zip_path])
              ).summary, # summary method of FastQC parser class
              id: obj[:fileid] # file id argument for FastQC converter
            ).send("to_#{@format}".intern) # call to_XXX method of Converter class
          )
        end
      rescue
        open(obj[:summary_path], 'w'){|f| f.puts('ERROR') }
      end

      #
      # Create list of summarized data
      #

      def backup(path)
        path + "." + Time.now.strftime("%Y%m%d")
      end

      def create_summary_files_list
        objects = create_fastqc_data_objects(@list_fastqc_zip_path)
        list = Parallel.map(objects, :in_threads => @@nop) do |obj|
          obj[:summary_path].sub(/^.+summary\//,"")
        end
        path = File.join(@outdir, "summary_list_#{@format}")
        FileUtils.mv(path, backup(path)) if File.exist?(path)
        open(path, 'w'){|f| f.puts(list) }
      end

      #
      # Create data object
      #

      def create_fastqc_data_objects(path_list)
        # returns list of object including paths to summary file
        # [["/path/to/DRR000001_fastqc.zip", "DRR000001_fastqc", "/path/to/DRR000001_fastqc.tsv"], ..]
        Parallel.map(path_list, :in_threads => @@nop) do |path|
          fastqc_path_to_data_object(path)
        end
      end

      def fastqc_path_to_data_object(path)
        fileid = path_to_fileid(path)
        dir    = summary_file_dir(fileid)
        FileUtils.mkdir_p(dir)
        {
          zip_path: path,
          fileid: fileid,
          summary_path: summary_file_path(fileid)
        }
      end

      #
      # Create list to summarize
      #

      def create_fastqc_zip_path_list_to_summarize
        list = Parallel.map(@list_fastqc_zip_path, :in_threads => @@nop) do |zip_path|
          zip_path if !summary_exist?(zip_path)
        end
        list.compact
      end

      def summary_exist?(fastqc_zip_path)
        # return true if summary file already exists for all kind of summary formats
        File.exist?(summary_file_path(path_to_fileid(fastqc_zip_path)))
      end

      def path_to_fileid(path)
        # returns "DRR000001_1_fastqc" from "/path/to/DRR000001_1_fastqc.zip"
        path.split("/").last.split(".")[0]
      end

      def summary_file_path(fileid)
        # returns path to summary file
        # e.g. "/path/to/out_dir/DRR/DRR0/DRR000/DRR000001/DRR000001_fastqc.tsv"
        File.join(summary_file_dir(fileid), fileid + "." + @format)
      end

      def summary_file_dir(fileid)
        # returns "/path/to/out_dir/DRR/DRR0/DRR000/DRR000001" from "DRR000001_1_fastqc"
        id = fileid.sub(/_.+$/,"")
        File.join(
          @outdir,
          id.slice(0,3),
          id.sub(/.....$/,""),
          id.sub(/...$/,""),
          id
        )
      end
    end
  end
end
