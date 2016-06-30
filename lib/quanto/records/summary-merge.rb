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
          # merge read data
          @reads_fpath = output_fpath("quanto.reads.tsv")
          merge_reads
          # merge reads to run
          @runs_fpath = output_fpath("quanto.runs.tsv")
          merge_reads_to_run
          # merge run to experiment
          @experiments_fpath = output_fpath("quanto.exp.tsv")
          merge_runs_to_experiment
          # merge run to sample
          #merge_runs_to_sample
          # link annotation to each samples
          #annotate_samples
        end
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

      #
      # Merge tsv
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
      # Merge reads to run
      #

      def merge_reads_to_run
        File.open(@runs_fpath, 'w') do |file|
          file.puts(tsv_header.join("\t"))
          reads_by_run.each_pair do |runid, obj_list|
            if obj_list.size == 1
              file.puts(open(obj_list[0][:summary_path]).read.chomp)
            else
              file.puts(merge_read_data(obj_list))
            end
          end
        end
      end

      def reads_by_run
        hash = {}
        @objects.each do |obj|
          runid = obj[:fileid].split("_")[0]
          hash[runid] ||= []
          hash[runid] << obj
        end
        hash
      end

      def merge_read_data(object_list)
        fdata = extract_data(object_list, :forward)
        rdata = extract_data(object_list, :reverse)
        data = reads_merge_method_mapping.map.with_index do |method, i|
          self.send(method, i, fdata, rdata)
        end
        data.join("\t")
      end

      def extract_data(object_list, layout)
        regexp = case layout
        when :forward
          /_1/
        when :reverse
          /_2/
        end
        path = object_list.select{|obj| obj[:fileid] =~ regexp }[0][:summary_path]
        open(path).read.chomp.split("\t")
      end

      def reads_merge_method_mapping
        [
          :match_runid,      # Run id
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

      def match_runid(i, f, r)
        f[i].split("_")
      end

      def join_literals(i, f, r)
        [f[i], r[i]].uniq.join(",")
      end

      def sum_floats(i, f, r)
        f[i].to_f + r[i].to_f
      end

      def mean_floats(i, f, r)
        sum_floats(i, f, r) / 2
      end

      def sum_reads_percent(i, f, r)
        f_total = f[5].to_f
        r_total = r[5].to_f
        f_count = percent_to_read_count(f_total, f[i].to_f)
        r_count = percent_to_read_count(r_total, r[i].to_f)
        (f_count + r_count) / (f_total + r_total) * 100
      end

      def percent_to_read_count(total, percent)
        total * (percent / 100)
      end

      def layout_paired(i, f, r)
        "PAIRED"
      end

      #
      # Merge reads to experiment
      #
      def merge_runs_to_experiment
        File.open(@experiments_fpath, 'w') do |file|
          # do something
        end
      end
    end
  end
end
