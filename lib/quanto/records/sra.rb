# -*- coding: utf-8 -*-

require 'parallel'
require 'ciika'

module Quanto
  class Records
    class SRA
      class << self
        # Download metadata reference tables
        def download_sra_metadata(dest_dir)
          dest_file = File.join(dest_dir, sra_metadata_tarball_fname)
          sh "lftp -c \"open #{sra_ftp_base_url} && pget -n 8 -o #{dest_dir} #{tarball}\""
          sh "tar zxf #{dest_file}"
          fix_sra_metadata_directory(dest_file.sub(/.tar.gz/,""))
          rm_f dest_file
        end

        def sra_ftp_base_url
          "ftp.ncbi.nlm.nih.gov/sra/reports/Metadata"
        end

        def sra_metadata_tarball_fname
          ym = Time.now.strftime("%Y%m")
          "NCBI_SRA_Metadata_Full_#{ym}01.tar.gz"
        end

        def fix_sra_metadata_directory(metadata_parent_dir)
          cd metadata_parent_dir
          pdir = get_accession_directories(metadata_parent_dir)
          pdir.group_by{|id| id.sub(/...$/,"") }.each_pair do |pid, ids|
            moveto = File.join(sra_metadata, pid)
            mkdir moveto
            mv ids, moveto
          end
        end
      end

      def initialize(sra_metadata_dir)
        @sra_metadata_dir = sra_metadata_dir
        @nop = Quanto::Records.num_of_parallels
      end

      # Get a list of public/accesiible SRA entries with read layout
      def available
        layout_hash = read_layout
        Parallel.map(public_idsets, :in_threads => @nop) do |idset|
          exp_id = idset[2]
          layout = layout_hash[exp_id]
          read_layout = layout ? layout : "UNDEFINED"
          idset << layout
        end
      end

      def sra_accessions_path
        "#{@sra_metadata_dir}/SRA_Accessions"
      end

      def awk_public_run_pattern
        '$1 ~ /^.RR/ && $3 == "live" && $9 == "public"'
      end

      def public_idsets
        list_public('$1 "\t" $2 "\t" $11') # run id, submission id, experiment id
      end

      def public_accid
        list_public('$2') # submission id
      end

      def list_public(fields)
        cat = "cat #{sra_accessions_path}"
        awk = "awk -F '\t' '#{awk_public_run_pattern} {print #{fields} }'"
        out = `#{cat} | #{awk}`.split("\n")
        Parallel.map(public_accid, :in_threads => @nop){|l| l.split("\t") }
      end

      # create hash for read layout reference
      def read_layout
        hash = {}
        list_exp_with_read_layout.each do |id_layout|
          id = id_layout[0]
          layout = id_layout[1]
          hash[id] = layout
        end
        hash
      end

      def public_exp_with_read_layout
        Parallel.map(public_xml, :in_threads => @nop) do |xml|
          extract_layout(xml)
        end
      end

      def public_xml
        list_public_xml = Parallel.map(public_accid, :in_threads => @nop) do |acc_id|
          exp_xml_path(acc_id)
        end
        list_public_xml.compact
      end

      def exp_xml_path(acc_id)
        xml = File.join(@sra_metadata_dir, acc_id.sub(/...$/,""), acc_id, acc_id + ".experiment.xml")
        xml if File.exist?(xml)
      end

      def extract_layout(xml)
        Ciika::SRA::Experiment.new(xml).parse.map do |a|
          [a[:accession], a[:library_description][:library_layout]]
        end
      end
    end
  end
end
