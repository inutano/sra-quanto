require 'rake'
require 'parallel'

module Quanto
  class Records
    class SRA
      class << self
        include RakeFileUtils

        def set_number_of_parallels(nop)
          @@num_of_parallels = nop
        end

        def set_sra_metadata_tarball_fname
          @@sra_metadata_tarball_fname = get_sra_metadata_tarball_fname
        end

        # Get metadata tarball filename from NCBI ftp
        def get_sra_metadata_tarball_fname
          `lftp -c \"open #{sra_ftp_base_url} && cls --sort=date -1 *Full* | head -1\"`.chomp
        end

        def sra_ftp_base_url
          "ftp.ncbi.nlm.nih.gov/sra/reports/Metadata"
        end

        # Download metadata reference tables
        def download_sra_metadata(dest_dir)
          set_sra_metadata_tarball_fname
          tarball_downloaded = File.join(dest_dir, @@sra_metadata_tarball_fname)
          unpacked_metadata  = tarball_downloaded.sub(/.tar.gz/,"")
          metadata_dest_path = File.join(dest_dir, "sra_metadata")

          if !File.exist?(metadata_dest_path) # not yet done
            if !File.exist?(unpacked_metadata) # not yet downloaded nor unpacked
              if !File.exist?(tarball_downloaded) # download unless not yet done
                download_metadata_via_ftp(dest_dir)
              end
              # extract
              extract_metadata(dest_dir, tarball_downloaded)
            end
            # fix and move
            fix_sra_metadata_directory(unpacked_metadata)
            sh "mv #{unpacked_metadata} #{metadata_dest_path} && rm -f #{tarball_downloaded}"
          end
        end

        def download_metadata_via_ftp(dest_dir)
          sh "lftp -c \"open #{sra_ftp_base_url} && pget -n 8 -O #{dest_dir} #{@@sra_metadata_tarball_fname}\""
        end

        def extract_metadata(dest_dir, tarball_downloaded)
          sh "cd #{dest_dir} && tar zxf #{tarball_downloaded}"
        end

        def fix_sra_metadata_directory(metadata_parent_dir)
          cd metadata_parent_dir
          pdir = get_accession_directories(metadata_parent_dir)
          pdir.group_by{|id| id.sub(/...$/,"") }.each_pair do |pid, ids|
            moveto = File.join(metadata_parent_dir, pid)
            mkdir moveto
            mv ids, moveto
          end
        end

        def get_accession_directories(metadata_parent_dir)
          Dir.entries(metadata_parent_dir).select{|f| f =~ /^.RA\d{6,7}$/ }
        end
      end

      def initialize(sra_metadata_dir)
        @sra_metadata_dir = sra_metadata_dir
      end

      # Get a list of public/accesiible SRA entries with read layout
      def available(list_experiment_metadata)
        h = layout_hash(list_experiment_metadata)
        Parallel.map(public_idsets, :in_threads => @@num_of_parallels) do |idset|
          layout = h[idset[2]]
          idset << (layout ? layout : "UNDEFINED")
        end
      end

      def layout_hash(list_experiment_metadata)
        hash = {}
        open(list_experiment_metadata).readlines.each do |metadata|
          a = metadata.chomp.split("\t")
          hash[a[0]] = a[5]
        end
        hash
      end

      def public_idsets
        # run id, submission id, experiment id, published date
        list_public('$1 "\t" $2 "\t" $11 "\t" $5')
      end

      def list_public(fields)
        cat = "cat #{sra_accessions_path}"
        awk = "awk -F '\t' '#{awk_public_run_pattern} { print #{fields} }'"
        catawk = `#{cat} | #{awk}`.split("\n")
        Parallel.map(catawk, :in_threads => @@num_of_parallels){|l| l.split("\t") }
      end

      def sra_accessions_path
        "#{@sra_metadata_dir}/SRA_Accessions"
      end

      def awk_public_run_pattern
        '$1 ~ /^.RR/ && $3 == "live" && $9 == "public"'
      end

      #
      # Extract experimental metadata from SRA XML and create tsv file
      #

      def experiment_metadata(fname)
        extract_experiment_metadata
        `cat #{index_filepath} | xargs cat > #{fname}`
      end

      def index_filepath
        File.join(@sra_metadata_dir, "metadata.experiment.txt")
      end

      def extract_experiment_metadata
        list = public_experiment_xml_list
        list.each{|xml| save_metadata(xml) }
        index = list.map{|xml_path| xml_path.sub(/.xml$/,".tsv")}
        open(index_filepath,'w') do |file|
          file.puts(index)
        end
      end

      def public_experiment_xml_list
        list = Parallel.map(public_accid, :in_threads => @@num_of_parallels) do |acc_id|
          exp_xml_path(acc_id)
        end
        list.compact
      end

      def public_accid
        list_public('$2').flatten.uniq # submission id
      end

      def exp_xml_path(acc_id)
        xml = File.join(@sra_metadata_dir, acc_id.sub(/...$/,""), acc_id, acc_id + ".experiment.xml")
        xml if File.exist?(xml)
      end

      def save_metadata(xml)
        target = xml.sub(/.xml$/,".tsv")
        open(target, 'w'){|f| f.puts(extract_metadata(xml)) }
      end

      def extract_metadata(xml)
        hash = {}
        XML::Parser.new(Nokogiri::XML::Reader(open(xml))) do
          for_element 'EXPERIMENT' do
            id = attribute("accession")
            hash[id] = []
            inside_element do
              for_element 'SINGLE' do hash[id] << name end
              for_element 'PAIRED' do hash[id] << name end
              for_element 'LIBRARY_STRATEGY' do hash[id] << inner_xml end
              for_element 'LIBRARY_SOURCE' do hash[id] << inner_xml end
              for_element 'LIBRARY_SELECTION' do hash[id] << inner_xml end
              for_element 'INSTRUMENT_MODEL' do hash[id] << inner_xml end
            end
          end
        end
        hash.map{|id, values| [id, values].flatten.join("\t") }
      end
    end
  end
end
