# -*- coding: utf-8 -*-

require 'rake'
require 'parallel'

module Quanto
  class Tables
    class self
      def create(table)
        case table
        when :finished
        when :live
        when :layout
        when :available
        end
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

      def create_list_fastqc_finished
        p_dirs = target_archives.map do |db|
          10.times.map{|n| File.join(fastqc_dir,db,db+n.to_s)}}.flatten
        end
        p2_dirs = parallel_glob(p_dirs)
        p3_dirs = parallel_glob(p2_dirs)
        list_finished_versions = parallel_parsezip(p3_dirs)
        open(t.name,"w"){|f| f.puts(list_finished_versions) }
      end

      def target_archives
        # ["DRR","ERR","SRR"] # complete list
        ["DRR","ERR","SRR"]
      end

      def parallel_glob(dirs)
        kids = Parallel.map(dirs, :in_threads => NUM_OF_PARALLEL) do |pd|
          Dir.glob(pd+"/*")
        end
        kids.flatten
      end

      def parallel_parsezip(dirs)
        versions = Parallel.map(dirs, :in_threads => NUM_OF_PARALLEL) do |pd|
          Dir.glob(pd+"/*zip").map do |zip|
            version = Zip::File.open(zip) do |zipfile|
              zipfile.glob("*/fastqc_data.txt").first.get_input_stream.read.split("\n").first.split("\t").last
            end
            [zip, version].join("\t")
          end
        end
        versions.flatten
      end

      def create_list_layout
      end

      def create_list_layout
      end

      def create_list_available
      end
    end
  end
end
