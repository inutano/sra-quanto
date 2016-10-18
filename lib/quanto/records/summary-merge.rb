require 'parallel'
require 'fileutils'
require 'json'

module Quanto
  class Records
    class Summary

      #
      # Merge tsv
      #

      def merge(format, outdir, metadata_dir, experiment_metadata, biosample_metadata, ow)
        @format = format
        @outdir = outdir
        @exp_metadata = experiment_metadata
        @bs_metadata  = biosample_metadata
        @overwrite = ow
        if @format == "tsv"
          # data object to merge, method defined in sumamry.rb
          @objects = create_fastqc_data_objects(@list_fastqc_zip_path)
          # sra metadata location
          @metadata_dir = metadata_dir
          # data to each type
          assemble
          # link annotation to each samples
          annotate_samples
        end
      end

      def assemble
        puts "==> #{Time.now}   Assembling Reads..."
        merge_reads
        puts "==> #{Time.now}   Assembling Run..."
        create_run_summary
        puts "==> #{Time.now}   Assembling Experiments..."
        create_exp_summary
        puts "==> #{Time.now}   Assembling Samples..."
        create_sample_summary
      end

      #
      # Merge single read summary file to one tsv
      #

      def merge_reads
        @reads_fpath = output_fpath("quanto.reads.tsv")
        if !output_exist?(@reads_fpath)
          File.open(@reads_fpath, 'w') do |file|
            file.puts(tsv_header[0..-1].join("\t"))
            @objects.each do |obj|
              file.puts(open(obj[:summary_path]).read.chomp)
            end
          end
        end
      end

      #
      # Merge data
      #

      def create_run_summary
        @runs_fpath = output_fpath("quanto.runs.tsv")
        if !output_exist?(@runs_fpath)
          merge_dataset(
            @runs_fpath,
            :read_to_run,
            tsv_header.drop(1).insert(0, "run_id"),
            reads_by_runid
          )
        end
      end

      def create_exp_summary
        @experiments_fpath = output_fpath("quanto.exp.tsv")
        if !output_exist?(@experiments_fpath)
          merge_dataset(
            @experiments_fpath,
            :run_to_exp,
            tsv_header.drop(1).insert(0, "experiment_id", "run_id"),
            runs_by_expid
          )
        end
      end

      def create_sample_summary
        @samples_fpath = output_fpath("quanto.sample.tsv")
        if !output_exist?(@samples_fpath)
          merge_dataset(
            @samples_fpath,
            :exp_to_sample,
            tsv_header.drop(1).insert(0, "biosample_id", "experiment_id", "run_id"),
            exps_by_sampleid
          )
        end
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
        when :exp_to_sample
          merge_exp_to_sample(id, data)
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
          ([expid] + data).join("\t")
        end
      end

      def runs_by_expid
        run_data = data_by_id(@runs_fpath)
        exp_run = `cat #{run_members_path} | awk -F '\t' '$8 == "live" { print $3 "\t" $1 }'`.split("\n")
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
      # Merge experiments to sample
      #

      def merge_exp_to_sample(sampleid, exps)
        exps.map{|exp| ([sampleid] + exp).join("\t") }.join("\n")
      end

      # return hash { "SAMD00016353" => ["DRX000001"], ... }
      # key: BioSample ID (can be SRS ID), value: array of SRA experiment ID
      def exps_by_sampleid
        exp_data = data_by_id(@experiments_fpath)
        sample_exp = `cat #{run_members_path} | awk -F '\t' '$8 == "live" { print $9 "\t" $3 "\t" $4 }' | sort -u`.split("\n")
        hash = {}
        sample_exp.each do |s_e|
          se = s_e.split("\t")
          samid = select_sampleid(se[0], se[2])
          exp = exp_data[se[1]]
          if exp
            hash[samid] ||= []
            hash[samid] << exp
          end
        end
        hash
      end

      def select_sampleid(biosample_id, srs_id)
        if biosample_id == "-"
          srs_id
        elsif biosampleid =~ /^[0-9]+$/
          numbers_to_biosampleid(biosample_id, srs_id)
        else
          biosample_id
        end
      end

      def numbers_to_biosampleid(num, srs_id)
        pfx = case srs_id[0]
        when "S"
          "SAMN"
        when "E"
          "SAME"
        when "D"
          "SAMD"
        end
        pfx + num.to_s
      end

      #
      # annotate tsv with metadata
      #

      def metadata_header
        [
          "secondary_sample_id",
          "taxonomy_id",
          "taxonomy_scientific_name",
          "genome_size",
          "coverage",
          "library_strategy",
          "library_source",
          "library_selection",
          "instrument_model",
        ]
      end

      def annotate_samples
        # hash to connect metadata
        exp_hash  = create_metadata_hash(@exp_metadata, 0) # { expid => [metadata] }
        bs_hash   = create_metadata_hash(@bs_metadata, 0)  # { biosampleid => [metadata] }
        srs_hash  = create_metadata_hash(@bs_metadata, 1)  # { sampleid => [metadata] }
        date_hash = received_date_by_experiment            # { expid => date_received }

        sample_data = open(@samples_fpath).readlines
        header = [sample_data.shift.chomp].push(metadata_header).join("\t")

        annotated = Parallel.map(sample_data, :in_threads => @@nop) do |line|
          data = line.chomp.split("\t")
          sample_md = bs_hash[data[0]] || srs_hash[data[0]]
          sample_info = if sample_md
            coverage = if sample_md[3] != "NA"
              data[7].to_f / sample_md[3].to_f * 1_000_000
            else
              "NA"
            end
            [
              sample_md,
              coverage,
            ]
          end
          [
            data,
            sample_info,
            exp_hash[data[1]],
            date_hash[data[1]],
          ].flatten.join("\t")
        end
        open(output_fpath("quanto.annotated.tsv"), 'w'){|f| f.puts([header, annotated.compact]) }
      end

      def sample_by_experiment
        `cat #{run_members_path} | awk -F '\t' '$8 == "live" { print $3 "\t" $4 "\t" $9 }' | sort -u`.split("\n").map{|line| l = line.split("\t"); [l[0], [l[1], l[2]]] }.to_h
      end

      def received_date_by_experiment
        `cat #{accessions_path} | awk -F '\t' '$1 ~ /^.RX/ && $3 == "live" && $9 == "public" { print $1 "\t" $6 }'`.split("\n").map{|line| l = line.split("\t"); [l[0], l[1]]}.to_h
      end

      def create_metadata_hash(path, id_col)
        hash = {}
        open(path).readlines.each do |line|
          data = line.chomp.split("\t")
          id = data.delete_at(id_col)
          hash[id] = data
        end
        hash
      end

      #
      # Protected methods for data merge
      #

      protected

      def run_members_path
        File.join(@metadata_dir, "SRA_Run_Members")
      end

      def accessions_path
        File.join(@metadata_dir, "SRA_Accessions")
      end

      def output_fpath(fname)
        File.join(@outdir, fname)
      end

      def output_exist?(fpath) # true to skip creation
        if File.exist?(fpath)
          if @overwrite
            backup_dir = File.join(@outdir, "backup", Time.now.strftime("%Y%m%d"))
            FileUtils.mkdir_p(backup_dir)
            FileUtils.mv(fpath, backup_dir)
            false
          else
            true
          end
        end
      end

      def data_by_id(data_fpath)
        data = open(data_fpath).readlines.drop(1)
        hash = {}
        data.each do |d|
          id = d.split("\t")[0]
          hash[id] = d.chomp.split("\t")
        end
        hash
      end

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
