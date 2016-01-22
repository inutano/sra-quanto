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
          zip_path_list = open(list_fastqc_finished).readlines
          Parallel.each(zip_path_list, :in_threads => @@num_of_parallels) do |line|
            zip_path = line.split("\t").first
            fileid   = zip_path.split("/").last
            file_out = summary_file(outdir, fileid)
            open(file_out, "w") do |file|
              file.puts(JSON.dump({fileid => summarize_fastqc(zip_path)}))
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
      end
    end
  end
end
