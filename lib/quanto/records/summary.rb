require 'parallel'
require 'bio-fastqc'
require 'fileutils'
require 'json'

module Quanto
  class Records
    class Summary
      class << self
        def set_number_of_parallels(nop)
          @@num_of_parallels = nop
        end

        def summarize(list_fastqc_finished, outdir)
          path_list = zip_path_list(list_fastqc_finished)
          create_json(path_list, outdir)
          create_list(path_list, outdir)
        end

        def zip_path_list(list_fastqc_finished)
          open(list_fastqc_finished).readlines.map do |line|
            line.split("\t").first
          end
        end

        def create_json(path_list, outdir)
          Parallel.each(path_list, :in_threads => @@num_of_parallels) do |path|
            # extract file id
            fileid   = path.split("/").last

            # next if already exist
            file_out = summary_file(outdir, fileid)
            next if File.exist?(file_out)

            # save summary
            open(file_out, "w") do |file|
              file.puts(JSON.dump({fileid => summarize_fastqc(path)}))
            end
          end
        end

        def summary_file(outdir, fileid)
          # returns path like /path/to/out_dir/DRR/DRR0/DRR000/DRR000001/DRR000001_fastqc.json
          id = fileid.sub(/_.+$/,"")
          center = id.slice(0,3)
          prefix = id.slice(0,4)
          index  = id.sub(/...$/,"")
          json   = fileid.sub(".zip",".json")
          dir = File.join(outdir, center, prefix, index, id, json)
          FileUtils.mkdir_p(dir)
          dir
        end

        def summarize_fastqc(fastqc_zip_path)
          data = Bio::FastQC::Data.read(fastqc_zip_path)
          Bio::FastQC::Parser.new(data).summary
        end

        def create_list(path_list, outdir)
          fname_out = File.join(outdir, "summary_list")
          list = path_list.map{|path| path.sub(/.zip$/,".json") }
          open(fname_out, "w"){|file| file.puts(list) }
        end
      end
    end
  end
end
