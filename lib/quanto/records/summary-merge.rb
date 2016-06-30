require 'parallel'
require 'fileutils'
require 'json'

module Quanto
  class Records
    class Summary

      #
      # Merge tsv
      #

      def merge(format, outdir, metadata_dir)
        @format = format
        @outdir = outdir
        if @format == "tsv"
          # data object to merge, method defined in sumamry.rb
          @objects = create_fastqc_data_objects(@list_fastqc_zip_path)
          # sra metadata location
          @metadata_dir = metadata_dir

          # merged data file path
          @reads_fpath = output_fpath("quanto.reads.tsv")
          @runs_fpath = output_fpath("quanto.runs.tsv")
          @experiments_fpath = output_fpath("quanto.exp.tsv")

          # merge
          merge_reads
          create_merge_files

          # link annotation to each samples
          #annotate_samples
        end
      end

      #
      # Merge single read summary file to one tsv
      #

      def merge_reads
        File.open(@reads_fpath, 'w') do |file|
          file.puts(tsv_header[0..-1].join("\t"))
          @objects.each do |obj|
            file.puts(open(obj[:summary_path]).read.chomp)
          end
        end
      end

      #
      # Merge data
      #

      def create_merge_files
        # require one by one merge process
        merge_dataset(
          @runs_fpath,
          :read_to_run,
          tsv_header,
          reads_by_runid
        )
        merge_dataset(
          @experiments_fpath,
          :run_to_exp,
          tsv_header.insert(1, "Run ID"),
          runs_by_expid
        )
      end

      def merge_dataset(outpath, type, header, id_data_pairs)
        File.open(outpath, 'w') do |file|
          file.puts(header.join("\t"))
          id_data_pairs.each_pair do |id, data|
            file.puts(merge_data_by_type(type, id, data))
          end
        end
      end

      def merge_data_by_type(type, id, data)
        case type
        when :read_to_run
          merge_read_to_run(id, data)
        when :run_to_exp
          merge_run_to_exp(id, data)
        end
      end

      #
      # Merge reads to run
      #

      def merge_read_to_run(runid, reads)
        if reads.size == 1
          (reads[0].drop(1).insert(0, runid) << "SINGLE").join("\t")
        else
          pairs = remove_nonpair(reads)
          if pairs.size == 2
            merge_data(remove_nonpair(reads)).join("\t")
          else
            "IMPERFECT PAIR DETECTED"
          end
        end
      end

      def remove_nonpair(reads)
        reads.select{|read| read[0] =~ /_._/ }
      end

      def reads_by_runid
        hash = {}
        reads = open(@reads_fpath).readlines.drop(1)
        reads.each do |read|
          runid = read.split("_")[0]
          hash[runid] ||= []
          hash[runid] << read.chomp.split("\t")
        end
        hash
      end

      #
      # Merge reads to experiment
      #

      def merge_run_to_exp(expid, runs)
        if runs.size == 1
          ([expid] + runs[0]).join("\t")
        else
          data = merge_data(runs)
          ([expid] << data).join("\t")
        end
      end

      def runs_by_runid
        runs = open(@runs_fpath).readlines.drop(1)
        hash = {}
        runs.each do |run|
          runid = run.split("\t")[0]
          hash[runid] = run.chomp.split("\t")
        end
        hash
      end

      def runs_by_expid
        run_data = runs_by_runid
        run_members = File.join(@metadata_dir, "SRA_Run_Members")
        exp_run = `cat #{run_members} | awk -F '\t' '$8 == "live" { print $3 "\t" $1 }'`.split("\n")
        hash = {}
        exp_run.each do |e_r|
          er = e_r.split("\t")
          run = run_data[er[1]]
          if run
            hash[er[0]] ||= []
            hash[er[0]] << run
          end
        end
        hash
      end

      #
      # Protected methods for data merge
      #

      protected

      def merge_data(data_list)
        data_scheme.map.with_index do |method, i|
          self.send(method, i, data_list)
        end
      end

      def data_scheme
        [
          :join_ids,         # Run id
          :join_literals,    # fastqc version
          :join_literals,    # filename
          :join_literals,    # file type
          :join_literals,    # encoding
          :sum_floats,       # total sequences
          :sum_floats,       # filtered sequences
          :mean_floats,      # sequence length
          :mean_floats,      # min seq length
          :mean_floats,      # max seq length
          :mean_floats,      # mean sequence length
          :mean_floats,      # median sequence length
          :sum_reads_percent, # percent gc
          :sum_reads_percent, # total duplication percentage
          :mean_floats,      # overall mean quality
          :mean_floats,      # overall median quality
          :mean_floats,      # overall n content
          :layout_paired,    # layout
        ]
      end

      def join_ids(i, data)
        data.map{|d| d[i].split("_")[0] }.uniq.join(",")
      end

      def join_literals(i, data)
        data.map{|d| d[i] }.uniq.join(",")
      end

      def sum_floats(i, data)
        data.map{|d| d[i].to_f }.reduce(:+)
      end

      def mean_floats(i, data)
        sum_floats(i, data) / 2
      end

      def sum_reads_percent(i, data)
        total_reads = data.map{|d| d[5].to_f }.reduce(:+)
        total_count = data.map{|d| percent_to_read_count(i, d) }.reduce(:+)
        (total_count / total_reads) * 100
      end

      def percent_to_read_count(i, data)
        data[5].to_f * (data[i].to_f / 100)
      end

      def layout_paired(i, data)
        "PAIRED"
      end

      def tsv_header
        [
          "ID",
          "fastqc_version",
          "filename",
          "file_type",
          "encoding",
          "total_sequences",
          "filtered_sequences",
          "sequence_length",
          "min_sequence_length",
          "max_sequence_length",
          "mean_sequence_length",
          "median_sequence_length",
          "percent_gc",
          "total_duplicate_percentage",
          "overall_mean_quality_score",
          "overall_median_quality_score",
          "overall_n_content",
          "read_layout",
        ]
      end
    end
  end
end
