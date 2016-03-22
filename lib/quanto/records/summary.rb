require 'parallel'
require 'ruby-progressbar'
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
          path_list = zip_path_list(list_fastqc_finished)
          create_summary(path_list, outdir)
          create_list(path_list, outdir)
        end

        def zip_path_list(list_fastqc_finished)
          open(list_fastqc_finished).readlines.map do |line|
            line.split("\t").first
          end
        end

        def list_not_yet_summarized(path_list, outdir)
          p_mes = "Initializing item list"
          list = Parallel.map(path_list, :in_threads => @@nop, :progress => p_mes) do |path|
            path if !summary_exist?(path, outdir)
          end
          list.compact
        end

        def summary_exist?(path, outdir)
          fileid  = path2fileid(path)
          json    = summary_file_path(outdir, fileid, "json")
          tsv     = summary_file_path(outdir, fileid, "tsv")
          ttl     = summary_file_path(outdir, fileid, "ttl")
          File.exist?(json) && File.exist?(tsv) && File.exist?(ttl)
        end

        def create_summary(path_list, outdir)
          p_mes = "Creating summary files"
          list = list_not_yet_summarized(path_list, outdir)
          Parallel.map(list, :in_threads => @@nop, :progress => p_mes) do |path|
            fileid  = path2fileid(path)
            if !summary_exist?(outdir, fileid)
              dir     = summary_file_dir(outdir, fileid)
              FileUtils.mkdir_p(dir)
              summary = summarize_fastqc(path)
              write_summary_file(summary, fileid, dir, "json")
              write_summary_file(summary, fileid, dir, "tsv")
              write_summary_file(summary, fileid, dir, "ttl")
              nil
            end
          end
        end

        def path2fileid(path)
          path.split("/").last
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
          data = Bio::FastQC::Data.read(fastqc_zip_path)
          Bio::FastQC::Parser.new(data).summary
        end

        def write_summary_file(summary, fileid, dir, format)
          Bio::FastQC::IO.new(summary, id: fileid).write(File.join(dir, fileid+"."+format), format)
        end

        def create_list(path_list, outdir)
          p_mes = "Creating file list"
          list = Parallel.map(path_list, :in_threads => @@nop, :progress => p_mes) do |path|
            fileid = path2fileid(path)
            summary_file_path(outdir, fileid, "json").sub(/^.+summary\//,"")
          end
          list_file_path = File.join(outdir, "summary_list")
          backup = fname_out + "." + Time.now.strftime("%Y%m%d")
          FileUtils.mv(fname_out, backup) if File.exist?(fname_out)
          open(fname_out, "w"){|file| file.puts(list) }
        end
      end
    end
  end
end
