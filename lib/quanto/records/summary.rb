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

        def summarize(list_fastqc_finished, outdir, format)
          # Set class variables of output directory path
          @@outdir = outdir
          # Create item list to summarize
          item_list = create_item_list(list_fastqc_finished, format)
          # Create summary for each item on the list
          create_summary(item_list, format)
          # Create list for summarized items
          create_list(item_list, format)
        end

        # Create item list to summarize
        # input file: list_fastqc_finished (runs.done.tab)
        # col1: full path to fastqc zip file, col2: fastqc version

        def create_item_list(list_fastqc_finished, ext)
          list = Parallel.map(open(list_fastqc_finished).readlines, :in_threads => @@nop) do |line|
            path = line.split("\t").first
            path if !summary_exist?(path, ext)
          end
          list.compact
        end

        def summary_exist?(path, ext)
          # return true if summary file already exists for all kind of summary formats
          id = path_to_fileid(path)
          File.exist?(summary_file_path(id, ext))
        end

        def path_to_fileid(path)
          # return "DRR000001_1_fastqc" from "/path/to/DRR000001_1_fastqc.zip"
          path.split("/").last.split(".")[0]
        end

        def summary_file_path(fileid, ext)
          # returns path to summary file
          # e.g. "/path/to/out_dir/DRR/DRR0/DRR000/DRR000001/DRR000001_fastqc.tsv"
          dir = summary_file_dir(fileid)
          File.join(dir, fileid + "." + ext)
        end

        def summary_file_dir(fileid)
          id = fileid.sub(/_.+$/,"")
          center = id.slice(0,3)
          prefix = id.slice(0,4)
          index  = id.sub(/...$/,"")
          File.join(@@outdir, center, prefix, index, id)
        end

        # Create sumamry for each item on the list

        def create_summary(item_list, ext)
          item_path_set = create_item_path_set(item_list, ext)
          bf = Bio::FastQC
          Parallel.map(item_path_set, :in_threads => @@nop) do |item|
            open(item[:summary_path], 'w') do |f|
              f.puts(
                bf::Converter.new(
                  bf::Parser.new(
                    bf::Data.read(item[:zip_path])
                  ).summary, # summary method of FastQC parser class
                  id: item[:fileid] # file id argument for FastQC converter
                ).send("to_#{ext}".intern) # call to_XXX method of Converter class
              )
            end
            nil
          end
        end

        def create_item_path_set(item_list, ext)
          # returns list of object including paths to summary file
          # [["/path/to/DRR000001_fastqc.zip", "DRR000001_fastqc", "/path/to/DRR000001_fastqc.tsv"], ..]
          Parallel.map(item_list, :in_threads => @@nop) do |path|
            fileid = path_to_fileid(path)
            dir    = summary_file_dir(fileid)
            FileUtils.mkdir_p(dir)
            {
              zip_path: path,
              fileid: fileid,
              summary_path: summary_file_path(fileid, ext)
            }
          end
        end

        # Create list for summarized items

        def create_list(item_list, ext)
          item_path_set = create_item_path_set(item_list, ext)
          list = Parallel.map(item_path_set, :in_threads => @@nop) do |item|
            item[:summary_path].sub(/^.+summary\//,"")
          end
          list_path = File.join(@@outdir, "summary_list_#{ext}")
          backup = list_path + "." + Time.now.strftime("%Y%m%d")
          FileUtils.mv(list_path, backup) if File.exist?(list_path)
          open(list_path, 'w'){|f| f.puts(list) }
        end
      end
    end
  end
end
