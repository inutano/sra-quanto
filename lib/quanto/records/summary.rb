require 'parallel'
require 'bio-fastqc'
require 'fileutils'
require 'json'

module Quanto
  class Records
    class Summary
      class << self
        def set_number_of_parallels(nop)
          # class variable: number of parallels
          @@nop = nop
        end

        def summarize(list_fastqc_finished, outdir)
          path_list_full = zip_path_list(list_fastqc_finished)
          path_list = list_not_yet_summarized(path_list_full, outdir)
          process_list = summary_process_list(path_list, outdir)
          create_summary(process_list, outdir)
          create_list(path_list, outdir)
        end

        def zip_path_list(list_fastqc_finished)
          open(list_fastqc_finished).readlines.map do |line|
            line.split("\t").first
          end
        end

        def list_not_yet_summarized(path_list, outdir)
          list = Parallel.map(path_list, :in_threads => @@nop) do |path|
            path if !summary_exist?(path, outdir)
          end
          list.compact
        end

        def output_formats
          [
            "json",
            # "ttl", # currently not working with parallel gem
            "tsv",
          ]
        end

        def summary_exist?(path, outdir)
          fileid  = path2fileid(path)
          files = output_formats.map{|ext| File.exist?(summary_file_path(outdir, fileid, ext)) }
          files.uniq == [true]
        end

        def summary_process_list(path_list, outdir)
          Parallel.map(path_list, :in_threads => @@nop) do |path|
            fileid = path2fileid(path)
            dir    = summary_file_dir(outdir, fileid)
            FileUtils.mkdir_p(dir)
            [ path, fileid ] + output_formats.map{|ext| summary_file_path(outdir, fileid, ext) }
          end
        end

        def create_summary(process_list, outdir)
          Parallel.map(process_list, :in_threads => @@nop) do |items|
            c = Bio::FastQC::Converter.new(Bio::FastQC::Parser.new(Bio::FastQC::Data.read(items[0])).summary, id: items[1])
            open(items[2], 'w'){|f| f.puts(c.to_json) }
            open(items[3], 'w'){|f| f.puts(c.to_tsv) }
            nil
          end
        end

        def path2fileid(path)
          path.split("/").last.split(".")[0]
        end

        def summary_file_dir(outdir, fileid)
          # create directory
          id = fileid.sub(/_.+$/,"")
          center = id.slice(0,3)
          prefix = id.slice(0,4)
          index  = id.sub(/...$/,"")
          File.join(outdir, center, prefix, index, id)
        end

        def summary_file_path(outdir, fileid, ext)
          # returns path like /path/to/out_dir/DRR/DRR0/DRR000/DRR000001/DRR000001_fastqc.json
          dir = summary_file_dir(outdir, fileid)
          summary_file_name = fileid.sub(".zip",".#{ext}")
          File.join(dir, summary_file_name)
        end

        def summarize_fastqc(fastqc_zip_path)
          Bio::FastQC::Parser.new(Bio::FastQC::Data.read(fastqc_zip_path)).summary
        end

        def create_list(path_list, outdir)
          list = Parallel.map(path_list, :in_threads => @@nop) do |path|
            fileid = path2fileid(path)
            summary_file_path(outdir, fileid, "json").sub(/^.+summary\//,"")
          end
          list_file_path = File.join(outdir, "summary_list")
          backup = list_file_path + "." + Time.now.strftime("%Y%m%d")
          FileUtils.mv(list_file_path, backup) if File.exist?(list_file_path)
          open(list_file_path, "w"){|file| file.puts(list) }
        end
      end
    end
  end
end
