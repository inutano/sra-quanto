require 'rake'
require 'parallel'

module Quanto
  class Records
    class BioSample
      class << self
        include RakeFileUtils

        def set_number_of_parallels(nop)
          @@num_of_parallels = nop
        end

        def bs_xml_fname
          File.join(@@bs_dir, "biosample_set.xml")
        end

        def bs_xml_gz
          bs_xml_fname + ".gz"
        end

        def biosample_ftp_url
          "ftp.ncbi.nlm.nih.gov/biosample"
        end

        def get_biosample_metadata
          sh "lftp #{bs_ftp_url} && pget -n 8 #{bs_xml_gz} -O #{@@bs_dir}"
        end

        def unarchive_biosample_metadata
          sh "cd #{@@bs_dir} && gunzip #{bs_xml_gz}"
        end

        def download_biosample_metadata(bs_dir)
          @@bs_dir = bs_dir
          if !File.exist?(File.join(@@bs_dir, bs_xml_fname))
            if !File.exist?(File.join(@@bs_dir, bs_xml_gz))
              get_biosample_metadata
            end
            unarchive_biosample_metadata
          end
        end
      end

      def initialize(bs_dir, sra_dir)
        @bs_dir = bs_dir
        @sra_dir = sra_dir
      end

      def metadata_xml_path
        File.join(@bs_dir, "biosample_set.xml")
      end

      def biosample_metadata(fpath)
        data = extract_metadata(metadata_xml_path)
        open(fpath, 'w'){|f| f.puts(data) }
      end

      def list_live_biosample
        run_members = File.join(@sra_dir, "SRA_Run_Members")
        `cat #{run_members} | awk -F '\t' '$8 == "live" { print $9 }' | sort -u`.split("\n")
      end

      def extract_metadata(xml)
        hash = {}
        live = list_live_biosample
        XML::Parser.new(Nokogiri::XML::Reader(open(xml))) do
          for_element 'BioSample' do
            id = attribute("accession")
            if list.include?(id)
              hash[id] = []
              inside_element do
                for_element 'Organism' do
                  hash[id] << attribute("taxonomy_id")
                  hash[id] << attribute("taxonomy_name")
                end
              end
            end
          end
        end
        hash.map{|id, values| [id, values].flatten.join("\t") }
      end
    end
  end
end
