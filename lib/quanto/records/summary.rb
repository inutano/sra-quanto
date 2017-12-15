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
        if @format == "turtle" # turtle conversion cannot be parallelized
          fastqc_data_objects(fastqc_zip_path_list_to_summarize).each do |obj|
            create_summary(bf, obj)
          end
        else
          Parallel.each(fastqc_data_objects(fastqc_zip_path_list_to_summarize), :in_threads => @@nop) do |obj|
            create_summary(bf, obj)
          end
        end
      end

      def create_summary(bf, obj)
        open(obj[:summary_path], 'w') do |f|
          f.puts(
            bf::Converter.new(
              bf::Parser.new(
                bf::Data.read(obj[:zip_path])
              ).summary, # summary method of FastQC parser class
              id: obj[:runid], # entry id argument for FastQC converter e.g. SRR000001_1
              runid: obj[:runid] # run id argument for FastQC converter e.g. SRR000001_1
            ).send("to_#{@format}".intern) # call to_XXX method of Converter class
          )
        end
      rescue
        open(obj[:summary_path], 'w'){|f| f.puts('ERROR') }
      end

      #
      # Create list of summarized data
      #

      def create_summary_files_list
        path = File.join(@outdir, "summary_list_#{@format}")
        if File.exist?(path)
          backup_dir = File.join(@outdir, "backup", Time.now.strftime("%Y%m%d"))
          FileUtils.mkdir_p(backup_dir)
          FileUtils.mv(path, backup_dir)
        end
        open(path, 'w'){|f| f.puts(summary_path_list) }
      end

      def summary_path_list
        Parallel.map(fastqc_data_objects(@list_fastqc_zip_path), :in_threads => @@nop) do |obj|
          obj[:summary_path].sub(/^.+summary\//,"")
        end
      end

      #
      # Create data object
      #

      def fastqc_data_objects(path_list)
        # returns list of object including paths to summary file
        # [["/path/to/DRR000001_fastqc.zip", "DRR000001_fastqc", "/path/to/DRR000001_fastqc.tsv"], ..]
        Parallel.map(path_list, :in_threads => @@nop) do |path|
          fastqc_path_to_data_object(path)
        end
      end

      def fastqc_path_to_data_object(path)
        FileUtils.mkdir_p(summary_file_dir(path))
        {
          zip_path: path,
          fileid: path_to_fileid(path),
          runid: path_to_runid(path),
          summary_path: summary_file_path(path)
        }
      end

      #
      # Create list to summarize
      #

      def fastqc_zip_path_list_to_summarize
        Parallel.map(@list_fastqc_zip_path, :in_threads => @@nop) {|zip_path|
          zip_path if !summary_exist?(zip_path)
        }.compact
      end

      def summary_exist?(fastqc_zip_path)
        # return true if summary file already exists for all kind of summary formats
        File.exist?(summary_file_path(path_to_fileid(fastqc_zip_path)))
      end

      def path_to_fileid(path)
        # returns "DRR000001_1_fastqc" from "/path/to/DRR000001_1_fastqc.zip"
        path.split("/").last.split(".")[0]
      end

      def path_to_runid(path)
        # returns "DRR000001_1" from "/path/to/DRR000001_1_fastqc.zip"
        path.split("/").last.split(".")[0].sub(/_fastqc/,"")
      end

      def summary_file_path(path)
        # returns path to summary file
        # e.g. "/path/to/out_dir/DRR/DRR0/DRR000/DRR000001/DRR000001_fastqc.tsv"
        fileid = path_to_fileid(path)
        File.join(summary_file_dir(fileid), fileid + "." + @format)
      end

      def summary_file_dir(path)
        # returns "/path/to/out_dir/DRR/DRR0/DRR000/DRR000001" from "/path/to/DRR000001_1_fastqc.zip"
        fileid = path_to_fileid(path)
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
