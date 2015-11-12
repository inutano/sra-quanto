# -*- coding: utf-8 -*-

require 'rake'
require 'parallel'
require 'zip'
require 'ciika'

module Quanto
  class Tables
    class self
      def num_of_parallel
        NUM_OF_PARALLEL || 4
      end

      def target_archives
        # ["DRR","ERR","SRR"] # complete list
        ["DRR"]
      end

      def download_sra_metadata(dest_dir)
        sra_ftp_base = "ftp.ncbi.nlm.nih.gov/sra/reports/Metadata"
        # filename
        ym = Time.now.strftime("%Y%m")
        tarball = "NCBI_SRA_Metadata_Full_#{ym}01.tar.gz"
        dest_file = File.join(dest_dir, tarball)
        # download via ftp
        sh "lftp -c \"open #{sra_ftp_base} && pget -n 8 -o #{dest_dir} #{tarball}\""
        sh "tar zxf #{dest_file}"
        fix_sra_metadata_directory(dest_file.sub(/.tar.gz/,""))
        rm_f dest_file
      end

      def fix_sra_metadata_directory(metadata_parent_dir)
        cd metadata_parent_dir
        acc_dirs = Dir.entries(metadata_parent_dir).select{|f| f =~ /^.RA\d{6,7}$/ }
        acc_dirs.group_by{|id| id.sub(/...$/,"") }.each_pair do |pid, ids|
          moveto = File.join(sra_metadata, pid)
          mkdir moveto
          mv ids, moveto
        end
      end

      def create_list_fastqc_finished(fastqc_dir, dest_file)
        p_dirs = target_archives.map do |db|
          10.times.map{|n| File.join(fastqc_dir,db,db+n.to_s)}}.flatten
        end
        p2_dirs = parallel_glob(p_dirs)
        p3_dirs = parallel_glob(p2_dirs)
        list_finished_versions = parallel_parsezip(p3_dirs)
        open(dest_file,"w"){|f| f.puts(list_finished_versions) }
      end

      def parallel_glob(dirs)
        kids = Parallel.map(dirs, :in_threads => num_of_parallel) do |pd|
          Dir.glob(pd+"/*")
        end
        kids.flatten
      end

      def parallel_parsezip(dirs)
        versions = Parallel.map(dirs, :in_threads => num_of_parallel) do |pd|
          Dir.glob(pd+"/*zip").map do |zip|
            version = Zip::File.open(zip) do |zipfile|
              zipfile.glob("*/fastqc_data.txt").first.get_input_stream.read.split("\n").first.split("\t").last
            end
            [zip, version].join("\t")
          end
        end
        versions.flatten
      end

      def create_list_live(sra_metadata_dir, dest_file)
        fpath = "#{sra_metadata_dir}/SRA_Accessions"
        pattern = '$1 ~ /^.RR/ && $3 == "live" && $9 == "public"'
        list = `cat #{fpath} | awk -F '\t' '#{pattern} {print $1 "\t" $2 "\t" $11}'`.split("\n")
        open(dest_file, "w"){|f| f.puts(list) }
      end

      def create_list_layout(list_live, sra_metadata_dir, dest_file)
        list_acc = `cat #{list_live} | awk -F '\t' '{ print $2 }' | sort -u`.split("\n")
        list_xml = Parallel.map(list_acc, :in_threads => num_of_parallel) do |acc_id|
          exp_xml_path = File.join(sra_metadata_dir, acc_id.sub(/...$/,""), acc_id, acc_id + ".experiment.xml")
          exp_xml_path if File.exist?(exp_xml_path)
        end
        acc_layout = Parallel.map(list_xml.compact, :in_threads => num_of_parallel) do |xml|
          Ciika::SRA::Experiment.new(xml).parse.map do |a|
            [a[:accession], a[:library_description][:library_layout]].join("\t")
          end
        end
        out = acc_layout.flatten
        open(dest_file, "w"){|f| f.puts(out) }
      end

      def get_live_list_hash(list_live)
        h = {}
        open(list_live).each do |ln|
          h[ln.split("\t").first] = ln.chomp
        end
        h
      end

      def get_layout_list_hash(list_layout)
        h = {}
        open(list_layout).each do |ln|
          l = ln.split("\t")
          h[l.first] = l.last
        end
        h
      end

      def create_list_available(list_live, list_layout, list_finished)
        live = get_live_list_hash(list_live)
        layout = get_layout_list_hash(list_layout)

        done = open(list_finished).readlines
        if ENV['versionup']
          done = done.select{|ln| ln.chomp =~ /#{FASTQC_VERSION}$/ }
        end

        done_runid = Parallel.map(done, :in_threads => NUM_OF_PARALLEL) do |ln|
          ln.split("\t")[0].split("/").last.split("_")[0]
        end

        available_run = live.keys - done_runid
        available = Parallel.map(available_run, :in_threads => NUM_OF_PARALLEL) do |runid|
          set = live[runid].split("\t")
          acc_id = set[1]
          exp_id = set[2]
          [exp_id, acc_id, layout[exp_id]].join("\t")
        end
        open(list_available,"w"){|f| f.puts(available.uniq) }
      end
    end
  end
end
