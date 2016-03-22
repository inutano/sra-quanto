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
          @@num_of_parallels = nop
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

        def create_summary(path_list, outdir)
          puts "Set number of parallel: #{@@num_of_parallels} threads."
          p_mes = "Creating FastQC summary files"
          Parallel.each(path_list, :in_threads => @@num_of_parallels, :progress => p_mes) do |path|
            # extract file id
            fileid = path2fileid(path)

            # generate summary of fastqc data
            summary = summarize_fastqc(path)

            # save summary files
            ["json", "jsonld", "ttl", "tsv"].each do |format|
              output_path = summary_file(outdir, fileid, format)
              if !File.exist?(output_path)
                Bio::FastQC::IO.new(summary, id: fileid).write(output_path, format)
              end
            end
          end
        end

        def path2fileid(path)
          path.split("/").last
        end

        def summary_file(outdir, fileid, ext)
          # create directory
          id = fileid.sub(/_.+$/,"")
          center = id.slice(0,3)
          prefix = id.slice(0,4)
          index  = id.sub(/...$/,"")
          dir    = File.join(outdir, center, prefix, index, id)
          FileUtils.mkdir_p(dir)

          # returns path like /path/to/out_dir/DRR/DRR0/DRR000/DRR000001/DRR000001_fastqc.json
          summary_file_name = fileid.sub(".zip",".#{ext}")
          File.join(dir, summary_file_name)
        end

        def summarize_fastqc(fastqc_zip_path)
          data = Bio::FastQC::Data.read(fastqc_zip_path)
          Bio::FastQC::Parser.new(data).summary
        end

        def create_list(path_list, outdir)
          relpath = outdir.sub(/^.+summary\//,"")
          list = path_list.map do |path|
            fileid = path2fileid(path)
            summary_file(relpath, fileid, "json")
          end
          fname_out = File.join(outdir, "summary_list")
          backup = fname_out + "." + Time.now.strftime("%Y%m%d")
          FileUtils.mv(fname_out, backup) if File.exist?(fname_out)
          open(fname_out, "w"){|file| file.puts(list) }
        end
      end
    end
  end
end
